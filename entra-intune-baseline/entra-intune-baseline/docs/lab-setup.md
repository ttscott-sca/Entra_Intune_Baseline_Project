# Lab Setup

1. **Tenant**: Microsoft 365 Developer Program sandbox or a trial tenant.
2. **Licenses**: Entra ID P1/P2 (Conditional Access) and Intune.
3. **Test VM**: Windows 11 (Hyper-V/VMware). Use Autopilot or manual Entra join.
4. **Accounts**: one Global Admin for setup, one break-glass account (excluded from CA), a few test users.
5. **Auth for automation**: app registration with least-privilege Graph permissions; use certificate or OIDC federation, not client secrets.

## Checklist
- [ ] Tenant created
- [ ] Break-glass account created and documented
- [ ] Test users + groups
- [ ] Windows 11 VM enrolled in Intune
