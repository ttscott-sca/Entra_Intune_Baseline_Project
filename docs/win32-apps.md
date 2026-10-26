# Win32 App Deployment (7-Zip example)

Apps are defined by metadata (`iac/intune/apps/<name>/app.json`) and published by one script, so adding an app means adding a folder.

## Steps
1. Download the 7-Zip x64 installer and save it as `iac/intune/apps/7zip/7z-x64.exe`.
2. Download `IntuneWinAppUtil.exe` (Microsoft Win32 Content Prep Tool).
3. On a Windows machine:
   ```powershell
   Install-Module IntuneWin32App -Scope CurrentUser
   ./iac/intune/Publish-Win32App.ps1 `
       -AppFolder ./iac/intune/apps/7zip `
       -TenantId <tenant-id> `
       -GroupId <group-object-id> `
       -IntuneWinAppUtilPath C:\Tools\IntuneWinAppUtil.exe `
       -WhatIf
   ```
   Remove `-WhatIf` to deploy.
4. Check the Intune admin center: Apps > Windows > 7-Zip > Device install status.

## Notes
- Detection is a file-exists rule on `7z.exe`, which survives version updates (unlike an MSI product code).
- Install runs in system context with restarts suppressed.
- Never commit installers or `.intunewin` files (git-ignored).

## Screenshots to capture
- [ ] App listed in Intune with detection rule
- [ ] Device install status showing "Installed"
