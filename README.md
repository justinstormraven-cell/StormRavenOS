# StormRavenOS

This repository now includes a hardened PowerShell workflow in `scripts/ImageBuild.ps1` with the following security controls:

- `Compile-AndSign` no longer relies on a hard-coded password and instead requires secrets from an environment variable (`STORMRAVEN_CODESIGN_PASSWORD`) or a supplied secret provider callback.
- `Service-WindowsImage` avoids direct registry insertion under `SystemCertificates\\ROOT\\Certificates`.
- Optional root trust provisioning is only available through a governed flow requiring explicit operator confirmation, thumbprint allowlisting, and audit logging.
