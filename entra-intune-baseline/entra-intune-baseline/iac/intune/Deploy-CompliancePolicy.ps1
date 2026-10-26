<#
.SYNOPSIS
    Deploys the Windows compliance policy from JSON and assigns it to a group.
    Idempotent: updates the policy if one with the same display name exists.
.NOTES
    Requires: Microsoft.Graph.Authentication module
    Scopes:   DeviceManagementConfiguration.ReadWrite.All
    Use -WhatIf to preview.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PolicyPath = "$PSScriptRoot/policies/windows-compliance.json",

    # Object ID of the Entra group to assign (e.g., a test device/user group)
    [Parameter(Mandatory)]
    [string]$GroupId
)

Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome

$baseUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies"
$body    = Get-Content -Path $PolicyPath -Raw | ConvertFrom-Json -AsHashtable
$name    = $body.displayName

$filter   = [uri]::EscapeDataString("displayName eq '$name'")
$existing = (Invoke-MgGraphRequest -Method GET -Uri "$baseUri`?`$filter=$filter").value

if ($existing.Count -gt 0) {
    $policyId = $existing[0].id
    if ($PSCmdlet.ShouldProcess($name, "Update compliance policy")) {
        # scheduledActionsForRule cannot be patched; omit on update
        $body.Remove('scheduledActionsForRule')
        Invoke-MgGraphRequest -Method PATCH -Uri "$baseUri/$policyId" `
            -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"
    }
}
else {
    if ($PSCmdlet.ShouldProcess($name, "Create compliance policy")) {
        $created  = Invoke-MgGraphRequest -Method POST -Uri $baseUri `
            -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"
        $policyId = $created.id
    }
}

if ($policyId -and $PSCmdlet.ShouldProcess($name, "Assign to group $GroupId")) {
    $assignment = @{
        assignments = @(
            @{ target = @{
                    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                    groupId       = $GroupId
            } }
        )
    }
    Invoke-MgGraphRequest -Method POST -Uri "$baseUri/$policyId/assign" `
        -Body ($assignment | ConvertTo-Json -Depth 10) -ContentType "application/json"
    Write-Output "Policy '$name' deployed and assigned."
}
