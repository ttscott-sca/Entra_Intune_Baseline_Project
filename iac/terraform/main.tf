# Break-glass group: excluded from all Conditional Access policies
resource "azuread_group" "breakglass" {
  display_name     = "CA-Exclude-BreakGlass"
  security_enabled = true
  description      = "Emergency access accounts excluded from Conditional Access"
}

# Dynamic group: IT department users
resource "azuread_group" "it_users" {
  display_name     = "Dept-IT-Users"
  security_enabled = true
  types            = ["DynamicMembership"]

  dynamic_membership {
    enabled = true
    rule    = "(user.department -eq \"IT\")"
  }
}

# Require MFA for all users (report-only while testing)
resource "azuread_conditional_access_policy" "require_mfa" {
  display_name = "CA001 - Require MFA for all users"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [azuread_group.breakglass.object_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# Block legacy authentication (report-only while testing)
resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "CA002 - Block legacy authentication"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [azuread_group.breakglass.object_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# Require a compliant device for Microsoft 365 apps on Windows (report-only while testing)
resource "azuread_conditional_access_policy" "require_compliant_device" {
  display_name = "CA003 - Require compliant device (Windows, M365)"
  state        = "enabledForReportingButNotEnforced"

  conditions {
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]

    applications {
      included_applications = ["Office365"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [azuread_group.breakglass.object_id]
    }

    platforms {
      included_platforms = ["windows"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["compliantDevice"]
  }
}

# Dynamic group: all Autopilot-registered devices (target for the deployment profile)
resource "azuread_group" "autopilot_devices" {
  display_name     = "Autopilot-Devices"
  security_enabled = true
  types            = ["DynamicMembership"]

  dynamic_membership {
    enabled = true
    rule    = "(device.devicePhysicalIDs -any (_ -contains \"[ZTDId]\"))"
  }
}
