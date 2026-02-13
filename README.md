# StormRavenOS

This repository now includes a hardened PowerShell workflow in `scripts/ImageBuild.ps1` with the following security controls:

- `Compile-AndSign` no longer relies on a hard-coded password and instead requires secrets from an environment variable (`STORMRAVEN_CODESIGN_PASSWORD`) or a supplied secret provider callback.
- `Service-WindowsImage` avoids direct registry insertion under `SystemCertificates\\ROOT\\Certificates`.
- Optional root trust provisioning is only available through a governed flow requiring explicit operator confirmation, thumbprint allowlisting, and audit logging.
## Offline service registration

This repository now includes deterministic offline Windows service registration helpers for WIM customization:

- `scripts/Service-WindowsImage.psm1` validates and writes an own-process (`Type = 0x10`) service model.
- `src/ServiceBinaryModel.cs` defines the generated service binary metadata model used to build SCM-compatible `ImagePath` values.

### Key behaviors

- Enforces required service values (`Type`, `Start`, `ErrorControl`, `ImagePath`, `DisplayName`).
- Writes optional values (`ObjectName`, `Description`) when provided.
- Always emits quoted `ImagePath` binary paths and safely escaped arguments.
- Performs post-injection verification and fails fast with explicit errors if any required value is missing or mismatched before WIM commit.
