<#
.SYNOPSIS
    Deploys the Windows Autopilot deployment profile from JSON and assigns it to a group.
    Idempotent: updates the profile if one with the same display name exists.
.NOTES
    Requires: Microsoft.Graph.Authentication module
    Scopes:   DeviceManagementServiceConfig.ReadWrite.All
    Uses the Graph beta endpoint. Use -WhatIf to preview.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProfilePath = "$PSScriptRoot/policies/autopilot-profile.json",

    # Object ID of the Autopilot devices group (see Terraform: Autopilot-Devices)
    [Parameter(Mandatory)]
    [string]$GroupId
)

Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All" -NoWelcome

$baseUri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"
$body    = Get-Content -Path $ProfilePath -Raw | ConvertFrom-Json -AsHashtable
$name    = $body.displayName

# Filtering is not reliably supported on this endpoint, so match client-side
$existing = (Invoke-MgGraphRequest -Method GET -Uri $baseUri).value |
    Where-Object { $_.displayName -eq $name } | Select-Object -First 1

if ($existing) {
    $profileId = $existing.id
    if ($PSCmdlet.ShouldProcess($name, "Update Autopilot profile")) {
        Invoke-MgGraphRequest -Method PATCH -Uri "$baseUri/$profileId" `
            -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"
    }
}
else {
    if ($PSCmdlet.ShouldProcess($name, "Create Autopilot profile")) {
        $created   = Invoke-MgGraphRequest -Method POST -Uri $baseUri `
            -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"
        $profileId = $created.id
    }
}

if ($profileId -and $PSCmdlet.ShouldProcess($name, "Assign to group $GroupId")) {
    $assignment = @{
        target = @{
            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
            groupId       = $GroupId
        }
    }
    try {
        Invoke-MgGraphRequest -Method POST -Uri "$baseUri/$profileId/assignments" `
            -Body ($assignment | ConvertTo-Json -Depth 10) -ContentType "application/json"
    }
    catch {
        Write-Warning "Assignment failed (it may already exist): $($_.Exception.Message)"
    }
    Write-Output "Autopilot profile '$name' deployed."
}
