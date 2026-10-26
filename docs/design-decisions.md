# Design Decisions

Document the *why* here. Recruiters read this.

| Decision | Why | Trade-off |
|---|---|---|
| CA policies in report-only first | Avoid lockout, validate impact | Slower to enforce |
| Dynamic groups for targeting | Less manual membership work | Rule syntax/propagation delay |
| Compliance gating via CA | Ties device health to access | Needs reliable Intune reporting |
| Terraform for Entra, DSC for Intune | Best provider coverage per service | Two toolchains |
| Compliance policy defined as JSON, deployed via Graph | Reviewable in PRs, repeatable, idempotent | Custom script instead of a managed provider |
| 24h grace period before blocking | Lets new devices finish encryption/enrollment | Brief window of non-compliance |
| CA003 scoped to Windows + M365 only | Smaller blast radius while validating | Other platforms/apps not yet covered |
| Autopilot profile defined as JSON, assigned to a dynamic group | New devices pick up the profile automatically | Group membership delay after registration |
| Standard user + single-user device | Least privilege for end users | Admin tasks need separate elevation |
| Win32 apps defined by `app.json` + one publish script | Adding an app = adding a folder; reviewable in PRs | Depends on community module and Windows-only packaging tool |
| File-exists detection rule | Survives version updates | Doesn't verify the installed version |
