<#
.SYNOPSIS
    Packages an app as .intunewin, uploads it to Intune, and assigns it as required.
    Metadata is read from <AppFolder>/app.json. Skips upload if the app already exists.
.NOTES
    Run on Windows (IntuneWinAppUtil.exe is Windows-only).
    Requires: IntuneWin32App module (Install-Module IntuneWin32App)
    Also needs Microsoft's Win32 Content Prep Tool (IntuneWinAppUtil.exe) from the
    microsoft/Microsoft-Win32-Content-Prep-Tool GitHub repo.
    Use -WhatIf to preview.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$AppFolder,

    [Parameter(Mandatory)]
    [string]$TenantId,

    # Object ID of the Entra group that receives the app as Required
    [Parameter(Mandatory)]
    [string]$GroupId,

    [Parameter(Mandatory)]
    [string]$IntuneWinAppUtilPath,

    [string]$OutputFolder = (Join-Path $env:TEMP "intunewin-output")
)

$ErrorActionPreference = "Stop"
$meta = Get-Content -Path (Join-Path $AppFolder "app.json") -Raw | ConvertFrom-Json

Connect-MSIntuneGraph -TenantID $TenantId

$existing = Get-IntuneWin32App -DisplayName $meta.displayName | Select-Object -First 1
if ($existing) {
    Write-Output "App '$($meta.displayName)' already exists in Intune. Skipping upload."
    return
}

if (-not $PSCmdlet.ShouldProcess($meta.displayName, "Package, upload, and assign Win32 app")) { return }

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

# 1. Package
$package = New-IntuneWin32AppPackage -SourceFolder $AppFolder `
    -SetupFile $meta.setupFile `
    -OutputFolder $OutputFolder `
    -IntuneWinAppUtilPath $IntuneWinAppUtilPath

# 2. Detection + requirement rules
$detectionRule = New-IntuneWin32AppDetectionRuleFile -Existence `
    -Path $meta.detection.path `
    -FileOrFolder $meta.detection.file `
    -DetectionType "exists" `
    -Check32BitOn64System $false

$requirementRule = New-IntuneWin32AppRequirementRule -Architecture "x64" `
    -MinimumSupportedWindowsRelease "W10_21H2"

# 3. Upload
$app = Add-IntuneWin32App -FilePath $package.Path `
    -DisplayName $meta.displayName `
    -Description $meta.description `
    -Publisher $meta.publisher `
    -InstallExperience "system" `
    -RestartBehavior "suppress" `
    -DetectionRule $detectionRule `
    -RequirementRule $requirementRule `
    -InstallCommandLine $meta.installCommandLine `
    -UninstallCommandLine $meta.uninstallCommandLine

# 4. Assign as required
Add-IntuneWin32AppAssignmentGroup -Include -ID $app.id -GroupID $GroupId `
    -Intent "required" -Notification "showAll" | Out-Null

Write-Output "Deployed '$($meta.displayName)' (id: $($app.id)) as required for group $GroupId."
