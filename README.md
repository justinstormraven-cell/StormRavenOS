# StormRaven OS

## Offline service registration

This repository now includes deterministic offline Windows service registration helpers for WIM customization:

- `scripts/Service-WindowsImage.psm1` validates and writes an own-process (`Type = 0x10`) service model.
- `src/ServiceBinaryModel.cs` defines the generated service binary metadata model used to build SCM-compatible `ImagePath` values.

### Key behaviors

- Enforces required service values (`Type`, `Start`, `ErrorControl`, `ImagePath`, `DisplayName`).
- Writes optional values (`ObjectName`, `Description`) when provided.
- Always emits quoted `ImagePath` binary paths and safely escaped arguments.
- Performs post-injection verification and fails fast with explicit errors if any required value is missing or mismatched before WIM commit.
