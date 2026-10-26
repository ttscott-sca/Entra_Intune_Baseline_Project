<#
.SYNOPSIS
    Reports Intune devices that are non-compliant.
.NOTES
    Requires: Microsoft.Graph module
    Scopes:   DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [string]$OutputPath = "./noncompliant-devices.csv"
)

Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -NoWelcome

$devices = Get-MgDeviceManagementManagedDevice -Filter "complianceState eq 'noncompliant'" -All

$report = $devices | Select-Object DeviceName, UserPrincipalName, OperatingSystem,
    OsVersion, ComplianceState, LastSyncDateTime

$report | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Output "Found $($report.Count) non-compliant device(s). Report: $OutputPath"
