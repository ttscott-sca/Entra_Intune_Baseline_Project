<#
.SYNOPSIS
    Lists recent sign-ins for the break-glass (emergency access) account.

.DESCRIPTION
    A break-glass account should almost never be used. Any sign-in, successful or
    failed, deserves a look. This script reads the Entra ID sign-in logs through
    Microsoft Graph and reports every sign-in by the account over the last N days.

    It is read-only. The only thing it can write is an optional CSV file, and that
    write honours -WhatIf.

    Two ways to sign in:
      * Default: Microsoft Graph PowerShell (Connect-MgGraph).
      * -UseAzCli: reuse an existing Azure CLI sign-in (az login). Use this if your
        tenant's security settings block the Microsoft Graph PowerShell app, which
        happened in my lab tenant (error 530035, security defaults).

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

.PARAMETER TenantId
    Optional tenant ID or domain (for example contoso.onmicrosoft.com) to sign in
    to with Microsoft Graph PowerShell. Use it when you have more than one lab
    tenant. Ignored with -UseAzCli, where the tenant comes from your az login.

.PARAMETER UseDeviceCode
    Sign in to Microsoft Graph PowerShell with a device code instead of a browser
    pop-up. Ignored with -UseAzCli.

.PARAMETER UseAzCli
    Use the signed-in Azure CLI session instead of Microsoft Graph PowerShell.
    Run this first:  az login --tenant <tenant> --allow-no-subscriptions

.EXAMPLE
    ./Get-BreakGlassSignIns.ps1 -UserPrincipalName breakglass@contoso.onmicrosoft.com

.EXAMPLE
    az login --tenant contoso.onmicrosoft.com --allow-no-subscriptions --use-device-code
    ./Get-BreakGlassSignIns.ps1 -UserPrincipalName breakglass@contoso.onmicrosoft.com -UseAzCli

.EXAMPLE
    ./Get-BreakGlassSignIns.ps1 -UserPrincipalName breakglass@contoso.onmicrosoft.com -Days 7 -OutputPath ./breakglass.csv -WhatIf

.NOTES
    Requires PowerShell 7+.
    Default sign-in also needs the Microsoft.Graph.Authentication module and asks
    for the read-only Graph scopes AuditLog.Read.All and Directory.Read.All.
    -UseAzCli needs the Azure CLI instead.
    The signed-in admin also needs a role that can read sign-in logs, such as
    Reports Reader, Security Reader or Global Reader.
#>

#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [ValidateRange(1, 30)]
    [int]$Days = 30,

    [string]$OutputPath,

    [switch]$FailIfFound,

    [string]$TenantId,

    [switch]$UseDeviceCode,

    [switch]$UseAzCli
)

$ErrorActionPreference = 'Stop'

$script:AzToken = $null

if ($UseAzCli) {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw 'The Azure CLI (az) was not found. Install it, then run: az login --tenant <tenant> --allow-no-subscriptions'
    }
    $script:AzToken = az account get-access-token --resource-type ms-graph --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $script:AzToken) {
        throw 'Could not get a Microsoft Graph token from the Azure CLI. Run: az login --tenant <tenant> --allow-no-subscriptions'
    }
    $azTenant = az account show --query tenantId -o tsv
    $azUser = az account show --query user.name -o tsv
    Write-Output "Using Azure CLI sign-in: tenant $azTenant, account $azUser"
}
else {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw 'The Microsoft.Graph.Authentication module is missing. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
    }

    $connectParams = @{
        Scopes    = 'AuditLog.Read.All', 'Directory.Read.All'
        NoWelcome = $true
    }
    if ($TenantId) { $connectParams.TenantId = $TenantId }
    if ($UseDeviceCode) { $connectParams.UseDeviceCode = $true }

    Connect-MgGraph @connectParams

    # Show which tenant and account the script is using, so a wrong tenant is obvious.
    $context = Get-MgContext
    Write-Output "Connected to tenant $($context.TenantId) as $($context.Account)"
}

function Invoke-GraphGet {
    param([Parameter(Mandatory)][string]$Uri)

    if ($script:AzToken) {
        Invoke-RestMethod -Method Get -Uri $Uri -Headers @{ Authorization = "Bearer $($script:AzToken)" }
    }
    else {
        Invoke-MgGraphRequest -Method GET -Uri $Uri
    }
}

$since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")

# Escape single quotes so the account name cannot break out of the OData filter.
$safeUpn = $UserPrincipalName.Replace("'", "''")
$filter = "userPrincipalName eq '$safeUpn' and createdDateTime ge $since"
$uri = 'https://graph.microsoft.com/v1.0/auditLogs/signIns?$filter=' +
    [uri]::EscapeDataString($filter) + '&$top=100'

$events = [System.Collections.Generic.List[object]]::new()
while ($uri) {
    $page = Invoke-GraphGet -Uri $uri
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

if (-not $UseAzCli) { Disconnect-MgGraph | Out-Null }

if (-not $report) {
    Write-Output "No sign-ins found for $UserPrincipalName in the last $Days day(s). This is the expected result."
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

if ($FailIfFound) { exit 2 }
