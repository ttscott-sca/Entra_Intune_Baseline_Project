# Autopilot Walkthrough

1. **Create the group**: `terraform apply` creates `Autopilot-Devices` (dynamic, matches Autopilot-registered devices).
2. **Deploy the profile**:
   ```powershell
   ./iac/intune/Deploy-AutopilotProfile.ps1 -GroupId <Autopilot-Devices object id> -WhatIf
   ./iac/intune/Deploy-AutopilotProfile.ps1 -GroupId <Autopilot-Devices object id>
   ```
3. **Register the test VM**: on the VM, at OOBE press `Shift+F10`, then:
   ```powershell
   Install-Script -Name Get-WindowsAutopilotInfo -Force
   Get-WindowsAutopilotInfo -Online
   ```
   Sign in with an account permitted to register devices. (Offline alternative: export a CSV and import it in the Intune admin center.)
4. **Reset and enroll**: wait for the device to appear in the group, reset the VM, and sign in as a test user.
5. **Verify**: device is Entra joined, named `CORP-<serial>`, and shows up in Intune.

## Screenshots to capture
- [ ] Device in Autopilot devices list
- [ ] OOBE with the skipped screens
- [ ] Device in Intune with compliance state
