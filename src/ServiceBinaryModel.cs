using System;
using System.Collections.Generic;
using System.Linq;

namespace StormRavenOS.Services;

/// <summary>
/// Represents deterministic metadata used to register an own-process Windows service.
/// </summary>
public sealed record ServiceBinaryModel
{
    public required string ServiceName { get; init; }
    public required string BinaryPath { get; init; }
    public IReadOnlyList<string> Arguments { get; init; } = Array.Empty<string>();
    public int Type { get; init; } = 0x10; // SERVICE_WIN32_OWN_PROCESS
    public int Start { get; init; } = 2; // Automatic
    public int ErrorControl { get; init; } = 1; // Normal
    public string? ObjectName { get; init; } = "LocalSystem";
    public string? DisplayName { get; init; }
    public string? Description { get; init; }

    public string EffectiveDisplayName => string.IsNullOrWhiteSpace(DisplayName) ? ServiceName : DisplayName!;

    public string BuildImagePath()
    {
        if (string.IsNullOrWhiteSpace(BinaryPath))
        {
            throw new InvalidOperationException("BinaryPath is required.");
        }

        var quotedPath = BinaryPath.Trim();
        if (!quotedPath.StartsWith('"') || !quotedPath.EndsWith('"'))
        {
            quotedPath = $"\"{quotedPath}\"";
        }

        if (Arguments.Count == 0)
        {
            return quotedPath;
        }

        var escaped = Arguments
            .Where(arg => !string.IsNullOrWhiteSpace(arg))
            .Select(EscapeArgument)
            .ToArray();

        return escaped.Length == 0
            ? quotedPath
            : $"{quotedPath} {string.Join(' ', escaped)}";
    }

    public IDictionary<string, object> ToRegistryMap()
    {
        Validate();

        var map = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase)
        {
            ["Type"] = Type,
            ["Start"] = Start,
            ["ErrorControl"] = ErrorControl,
            ["ImagePath"] = BuildImagePath(),
            ["DisplayName"] = EffectiveDisplayName
        };

        if (!string.IsNullOrWhiteSpace(ObjectName))
        {
            map["ObjectName"] = ObjectName!;
        }

        if (!string.IsNullOrWhiteSpace(Description))
        {
            map["Description"] = Description!;
        }

        return map;
    }

    public void Validate()
    {
        if (string.IsNullOrWhiteSpace(ServiceName))
        {
            throw new InvalidOperationException("ServiceName is required.");
        }

        if (Type != 0x10)
        {
            throw new InvalidOperationException($"Service Type must be SERVICE_WIN32_OWN_PROCESS (0x10). Actual: 0x{Type:X}");
        }

        if (Start is < 0 or > 4)
        {
            throw new InvalidOperationException($"Start must be between 0 and 4. Actual: {Start}");
        }

        if (ErrorControl is < 0 or > 3)
        {
            throw new InvalidOperationException($"ErrorControl must be between 0 and 3. Actual: {ErrorControl}");
        }

        _ = BuildImagePath();
    }

    private static string EscapeArgument(string raw)
    {
        if (raw.IndexOfAny(new[] { ' ', '\t', '"' }) >= 0)
        {
            return $"\"{raw.Replace("\"", "\\\"")}\"";
        }

        return raw;
    }
}
