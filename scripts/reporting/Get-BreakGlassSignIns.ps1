<#
.SYNOPSIS
    Lists recent sign-ins for the break-glass (emergency access) account.

.DESCRIPTION
    A break-glass account should almost never be used. Any sign-in, successful or
    failed, deserves a look. This script reads the Entra ID sign-in logs through
    Microsoft Graph and reports every sign-in by the account over the last N days.

    It is read-only. The only thing it can write is an optional CSV file, and that
    write honours -WhatIf.

    Limits to know about:
      * Only interactive sign-ins are returned by the v1.0 sign-in log endpoint.
        Break-glass accounts sign in interactively, so this covers the use case.
      * Entra keeps sign-in logs for 30 days with a P1/P2 license (7 days on Free),
        so -Days is capped at 30.
      * Run it on a schedule or by hand. For near-real-time alerting, see
        docs/break-glass-monitoring.md.

.PARAMETER UserPrincipalName
    The break-glass account, for example breakglass@contoso.onmicrosoft.com.

.PARAMETER Days
    How many days back to look. 1 to 30, default 30.

.PARAMETER OutputPath
    Optional path for a CSV export of the sign-ins found.

.PARAMETER FailIfFound
    Exit with code 2 if any sign-in is found. Useful when the script runs in a
    scheduled job that should raise a failure.

.EXAMPLE
    ./Get-BreakGlassSignIns.ps1 -UserPrincipalName breakglass@contoso.onmicrosoft.com

.EXAMPLE
    ./Get-BreakGlassSignIns.ps1 -UserPrincipalName breakglass@contoso.onmicrosoft.com -Days 7 -OutputPath ./breakglass.csv -WhatIf

.NOTES
    Requires PowerShell 7+ and the Microsoft.Graph.Authentication module.
    Graph scopes requested: AuditLog.Read.All and Directory.Read.All (read only).
    The signed-in admin also needs a role that can read sign-in logs, such as
    Reports Reader, Security Reader or Global Reader.
#>

#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [ValidateRange(1, 30)]
    [int]$Days = 30,

    [string]$OutputPath,

    [switch]$FailIfFound
)

$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'AuditLog.Read.All', 'Directory.Read.All' -NoWelcome

$since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")

# Escape single quotes so the account name cannot break out of the OData filter.
$safeUpn = $UserPrincipalName.Replace("'", "''")
$filter = "userPrincipalName eq '$safeUpn' and createdDateTime ge $since"
$uri = 'https://graph.microsoft.com/v1.0/auditLogs/signIns?$filter=' +
    [uri]::EscapeDataString($filter) + '&$top=100'

$events = [System.Collections.Generic.List[object]]::new()
while ($uri) {
    $page = Invoke-MgGraphRequest -Method GET -Uri $uri
    foreach ($item in $page.value) { $events.Add($item) }
    $uri = $page.'@odata.nextLink'
}

$report = $events | ForEach-Object {
    [pscustomobject]@{
        TimeUtc           = $_.createdDateTime
        Account           = $_.userPrincipalName
        Result            = if ($_.status.errorCode -eq 0) { 'Success' } else { 'Failure' }
        ErrorCode         = $_.status.errorCode
        FailureReason     = $_.status.failureReason
        IPAddress         = $_.ipAddress
        City              = $_.location.city
        Country           = $_.location.countryOrRegion
        Application       = $_.appDisplayName
        ClientApp         = $_.clientAppUsed
        ConditionalAccess = $_.conditionalAccessStatus
    }
} | Sort-Object TimeUtc -Descending

if (-not $report) {
    Write-Output "No sign-ins found for $UserPrincipalName in the last $Days day(s). This is the expected result."
    Disconnect-MgGraph | Out-Null
    return
}

$successes = @($report | Where-Object Result -eq 'Success').Count
Write-Warning "$(@($report).Count) sign-in(s) found for $UserPrincipalName in the last $Days day(s): $successes successful. Check each one against a known, approved use."

$report | Format-Table TimeUtc, Result, IPAddress, Country, Application, ErrorCode -AutoSize

if ($OutputPath) {
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Write sign-in report to CSV')) {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Output "Report written to $OutputPath"
    }
}

Disconnect-MgGraph | Out-Null

if ($FailIfFound) { exit 2 }
