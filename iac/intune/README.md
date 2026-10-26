# Intune as Code

Use **Microsoft365DSC** (or the Graph API) to define Intune policies declaratively.

Planned configuration:
- Windows compliance policy (BitLocker, Secure Boot, Defender, min OS)
- Endpoint security baseline
- Autopilot deployment profile (done, see `Deploy-AutopilotProfile.ps1` and `docs/autopilot.md`)
- Win32 app deployment (done for 7-Zip, see `Publish-Win32App.ps1` and `docs/win32-apps.md`)

Example workflow:
```powershell
Install-Module Microsoft365DSC -Scope CurrentUser
Export-M365DSCConfiguration -Components @('IntuneDeviceCompliancePolicyWindows10') -Path ./exports
```
Sanitize all exports (remove tenant IDs/secrets) before committing.

## Windows compliance baseline
`policies/windows-compliance.json` defines the policy (BitLocker, Secure Boot, code integrity, Defender, password, min OS 11 22H2).

Deploy to a test group:
```powershell
./Deploy-CompliancePolicy.ps1 -GroupId <entra-group-object-id> -WhatIf   # preview
./Deploy-CompliancePolicy.ps1 -GroupId <entra-group-object-id>
```
Then enable `CA003` (compliant device) in report-only mode and check the sign-in logs before enforcing.
