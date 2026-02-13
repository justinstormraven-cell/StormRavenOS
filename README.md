
StormRavenOS scaffold

This scaffold creates the initial project layout for StormRaven OS v1.

Includes:
1. Native C# Kernel (Windows Service)
2. Hybrid Master Doctoral Kernel (Python) in `StormRaven.Python/`
   - Cross-platform Logic (Windows/Linux)
   - Modules: Luci, Solomon, Thor, Freya, Heimdall, Bifrost, Saga, Shadow Log, Void Viz, Ragnarok, Deadman, Odin.
3. WinUI Shell Scaffold
4. Restoration Script: `StormRaven.Installer/restore_odin.sh`

Next steps:‎
1. Open the folder in Visual Studio.
2. Add a solution file and include the two projects.
3. To test the prototype kernel, run `python StormRaven.Python/odin.py`.
4. For Linux/WSL restoration, execute `bash StormRaven.Installer/restore_odin.sh`.
# StormRavenOS

## Offline service registration

This repository now includes deterministic offline Windows service registration helpers for WIM customization:

- `scripts/Service-WindowsImage.psm1` validates and writes an own-process (`Type = 0x10`) service model.
- `src/ServiceBinaryModel.cs` defines the generated service binary metadata model used to build SCM-compatible `ImagePath` values.

### Key behaviors

- Enforces required service values (`Type`, `Start`, `ErrorControl`, `ImagePath`, `DisplayName`).
- Writes optional values (`ObjectName`, `Description`) when provided.
- Always emits quoted `ImagePath` binary paths and safely escaped arguments.
- Performs post-injection verification and fails fast with explicit errors if any required value is missing or mismatched before WIM commit.
