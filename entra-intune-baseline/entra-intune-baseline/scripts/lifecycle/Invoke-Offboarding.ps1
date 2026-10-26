<#
.SYNOPSIS
    Offboards a user: disables account, revokes sessions, retires managed devices.
.NOTES
    Requires: Microsoft.Graph module
    Scopes:   User.ReadWrite.All, DeviceManagementManagedDevices.PrivilegedOperations.All,
              DeviceManagementManagedDevices.Read.All
    Use -WhatIf to preview.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$UserPrincipalName
)

Connect-MgGraph -Scopes "User.ReadWrite.All",
    "DeviceManagementManagedDevices.PrivilegedOperations.All",
    "DeviceManagementManagedDevices.Read.All" -NoWelcome

$user = Get-MgUser -UserId $UserPrincipalName

if ($PSCmdlet.ShouldProcess($UserPrincipalName, "Disable account")) {
    Update-MgUser -UserId $user.Id -AccountEnabled:$false
}

if ($PSCmdlet.ShouldProcess($UserPrincipalName, "Revoke sign-in sessions")) {
    Revoke-MgUserSignInSession -UserId $user.Id | Out-Null
}

$devices = Get-MgDeviceManagementManagedDevice -Filter "userId eq '$($user.Id)'" -All
foreach ($device in $devices) {
    if ($PSCmdlet.ShouldProcess($device.DeviceName, "Retire device")) {
        Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $device.Id
    }
}

Write-Output "Offboarding complete for $UserPrincipalName."
