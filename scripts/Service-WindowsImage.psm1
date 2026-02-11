Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-ServiceImagePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BinaryPath,

        [string[]]$Arguments = @()
    )

    if ([string]::IsNullOrWhiteSpace($BinaryPath)) {
        throw "BinaryPath cannot be null or empty."
    }

    $trimmedPath = $BinaryPath.Trim()
    if (-not ($trimmedPath.StartsWith('"') -and $trimmedPath.EndsWith('"'))) {
        $trimmedPath = '"{0}"' -f $trimmedPath
    }

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        return $trimmedPath
    }

    $escapedArgs = foreach ($arg in $Arguments) {
        if ($null -eq $arg) { continue }
        if ($arg -match '[\s"]') {
            '"{0}"' -f ($arg -replace '"', '\\"')
        }
        else {
            $arg
        }
    }

    $argumentString = ($escapedArgs -join ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($argumentString)) {
        return $trimmedPath
    }

    return ('{0} {1}' -f $trimmedPath, $argumentString)
}

function New-ServiceBinaryModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [string]$BinaryPath,

        [string[]]$BinaryArguments = @(),

        [ValidateRange(0, 255)]
        [int]$Start = 2,

        [ValidateRange(0, 255)]
        [int]$ErrorControl = 1,

        [string]$DisplayName,

        [string]$Description,

        [string]$ObjectName = 'LocalSystem'
    )

    if ([string]::IsNullOrWhiteSpace($ServiceName)) {
        throw "ServiceName cannot be null or empty."
    }

    $imagePath = Format-ServiceImagePath -BinaryPath $BinaryPath -Arguments $BinaryArguments

    return [ordered]@{
        ServiceName   = $ServiceName
        Type          = 0x10 # SERVICE_WIN32_OWN_PROCESS
        Start         = $Start
        ErrorControl  = $ErrorControl
        ImagePath     = $imagePath
        ObjectName    = $ObjectName
        DisplayName   = if ([string]::IsNullOrWhiteSpace($DisplayName)) { $ServiceName } else { $DisplayName }
        Description   = $Description
    }
}

function Test-OfflineServiceRegistration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceHiveRoot,

        [Parameter(Mandatory)]
        [hashtable]$ExpectedModel
    )

    $servicePath = Join-Path $ServiceHiveRoot $ExpectedModel.ServiceName
    if (-not (Test-Path -LiteralPath $servicePath)) {
        throw "Service key is missing: $servicePath"
    }

    $serviceValues = Get-ItemProperty -LiteralPath $servicePath

    $required = @('Type', 'Start', 'ErrorControl', 'ImagePath', 'DisplayName')
    foreach ($name in $required) {
        if (-not ($serviceValues.PSObject.Properties.Name -contains $name)) {
            throw "Required service value '$name' missing from '$servicePath'."
        }
    }

    if ([int]$serviceValues.Type -ne [int]$ExpectedModel.Type) {
        throw "Service Type mismatch. Expected $($ExpectedModel.Type), actual $($serviceValues.Type)."
    }

    if ([int]$serviceValues.Start -ne [int]$ExpectedModel.Start) {
        throw "Service Start mismatch. Expected $($ExpectedModel.Start), actual $($serviceValues.Start)."
    }

    if ([int]$serviceValues.ErrorControl -ne [int]$ExpectedModel.ErrorControl) {
        throw "Service ErrorControl mismatch. Expected $($ExpectedModel.ErrorControl), actual $($serviceValues.ErrorControl)."
    }

    if ([string]$serviceValues.ImagePath -ne [string]$ExpectedModel.ImagePath) {
        throw "Service ImagePath mismatch. Expected '$($ExpectedModel.ImagePath)', actual '$($serviceValues.ImagePath)'."
    }

    if ([string]$serviceValues.DisplayName -ne [string]$ExpectedModel.DisplayName) {
        throw "Service DisplayName mismatch. Expected '$($ExpectedModel.DisplayName)', actual '$($serviceValues.DisplayName)'."
    }

    if ($ExpectedModel.Contains('ObjectName') -and -not [string]::IsNullOrWhiteSpace($ExpectedModel.ObjectName)) {
        if (-not ($serviceValues.PSObject.Properties.Name -contains 'ObjectName')) {
            throw "Expected ObjectName but value is missing from '$servicePath'."
        }

        if ([string]$serviceValues.ObjectName -ne [string]$ExpectedModel.ObjectName) {
            throw "Service ObjectName mismatch. Expected '$($ExpectedModel.ObjectName)', actual '$($serviceValues.ObjectName)'."
        }
    }

    return $true
}

function Register-OfflineServiceDeterministic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MountedSystemHiveRoot,

        [Parameter(Mandatory)]
        [hashtable]$ServiceModel
    )

    # Deterministic offline registration equivalent to CreateService defaults for own-process services.
    $servicesRoot = Join-Path $MountedSystemHiveRoot 'ControlSet001\Services'
    if (-not (Test-Path -LiteralPath $servicesRoot)) {
        throw "Offline SYSTEM hive services root not found: $servicesRoot"
    }

    $servicePath = Join-Path $servicesRoot $ServiceModel.ServiceName
    if (-not (Test-Path -LiteralPath $servicePath)) {
        New-Item -Path $servicePath -Force | Out-Null
    }

    New-ItemProperty -LiteralPath $servicePath -Name 'Type' -PropertyType DWord -Value $ServiceModel.Type -Force | Out-Null
    New-ItemProperty -LiteralPath $servicePath -Name 'Start' -PropertyType DWord -Value $ServiceModel.Start -Force | Out-Null
    New-ItemProperty -LiteralPath $servicePath -Name 'ErrorControl' -PropertyType DWord -Value $ServiceModel.ErrorControl -Force | Out-Null
    New-ItemProperty -LiteralPath $servicePath -Name 'ImagePath' -PropertyType ExpandString -Value $ServiceModel.ImagePath -Force | Out-Null
    New-ItemProperty -LiteralPath $servicePath -Name 'DisplayName' -PropertyType String -Value $ServiceModel.DisplayName -Force | Out-Null

    if (-not [string]::IsNullOrWhiteSpace($ServiceModel.ObjectName)) {
        New-ItemProperty -LiteralPath $servicePath -Name 'ObjectName' -PropertyType String -Value $ServiceModel.ObjectName -Force | Out-Null
    }

    if ($ServiceModel.Contains('Description') -and -not [string]::IsNullOrWhiteSpace($ServiceModel.Description)) {
        New-ItemProperty -LiteralPath $servicePath -Name 'Description' -PropertyType String -Value $ServiceModel.Description -Force | Out-Null
    }

    # Equivalent install metadata for SCM enumeration consistency.
    $enumPath = Join-Path $servicePath 'Enum'
    if (-not (Test-Path -LiteralPath $enumPath)) {
        New-Item -Path $enumPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $enumPath -Name 'Count' -PropertyType DWord -Value 0 -Force | Out-Null
    New-ItemProperty -LiteralPath $enumPath -Name 'NextInstance' -PropertyType DWord -Value 0 -Force | Out-Null

    if (-not (Test-OfflineServiceRegistration -ServiceHiveRoot $servicesRoot -ExpectedModel $ServiceModel)) {
        throw "Service verification returned false for '$($ServiceModel.ServiceName)'."
    }
}

Export-ModuleMember -Function @(
    'Format-ServiceImagePath',
    'New-ServiceBinaryModel',
    'Register-OfflineServiceDeterministic',
    'Test-OfflineServiceRegistration'
)
