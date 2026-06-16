# Episode 2: Guarding the Estate — Identity, Policy, and Cost

## Series context
Part of "Mastering Infrastructure Lifecycle Management with Terraform" — 9-episode series.
Audience: Practitioners & Enterprise Architects (intermediate/advanced). ~15 min lightboard format.

## This episode
Goal: demonstrate three governance pillars on top of Ep1's infrastructure — Sentinel
policy-as-code, Vault dynamic credentials (zero static secrets), and Cloudability cost
guardrails via Run Tasks.

## Architecture decision: workspaces, not Stacks
This episode originally targeted Terraform Stacks (archived repo:
`stacks-demo-ep2-tfe-series`, kept unreferenced). Stacks does not support Run Tasks, and
Sentinel policy evaluation against Stack plans never worked in that repo despite a
correctly-configured policy set. Both work cleanly on standard HCP Terraform workspaces,
so this repo uses that model. Infrastructure (VPC → EKS → K8s App) is unchanged from Ep1.

## Status: feature-complete, pending recording
All three governance pillars confirmed working on `ep2-dev`:
- Sentinel: both policies (`allowed-instance-types` hard-mandatory, `require-tags`
  soft-mandatory) pass cleanly
- Vault: dynamic credentials authenticate and read the KV secret with zero static tokens
- Cloudability: Run Task fires post-plan, returns a cost estimate (confirmed in UI)

Not yet recorded. Demo flow below.

## Setup reference (already done)
- 3 workspaces: `ep2-dev`, `ep2-staging`, `ep2-prod`, VCS-connected to this repo
- AWS dynamic credentials: `TFC_AWS_PROVIDER_AUTH=true`, `TFC_AWS_RUN_ROLE_ARN=<role>`;
  IAM trust policy updated for the workspace `sub` claim format
  (`organization:...:workspace:ep2-*:run_phase:*`)
- Vault dynamic credentials: `TFC_VAULT_PROVIDER_AUTH=true`, `TFC_VAULT_ADDR`,
  `TFC_VAULT_NAMESPACE=admin`, `TFC_VAULT_RUN_ROLE=hcp-terraform-ep2-{env}` per workspace;
  Vault JWT roles bound to the workspace `sub` claim format
- Sentinel policy set `ep2-guardrails` scoped to all 3 workspaces, source = this repo,
  path = `sentinel/`
- Cloudability Run Task assigned to all 3 workspaces, post-plan, advisory

## Known gotchas (don't re-debug these)
- Sentinel has no `sprintf()` builtin — use `+` string concatenation and `string()` for
  scalar conversion (no list support)
- Sentinel: `not x contains y` parses as `(not x) contains y` — always parenthesize:
  `not (x contains y)`
- Sentinel: multi-line function call argument lists can break the parser — keep calls on
  one line
- Sentinel: check `tags_all`, not `tags`, to see provider-level `default_tags` merged in;
  many `aws_*` resources have no `tags_all` at all — guard with
  `after contains "tags_all"` before checking
- EKS auth token (`module.app_auth`) expires in ~15 minutes — approve plans promptly or
  apply will fail with `Unauthorized`
- HCP Terraform workspace dynamic-credential env vars must be added under
  **Environment Variables**, not **Terraform Variables** — easy to mis-categorize in the UI
- `.terraform.lock.hcl` generated on macOS lacks `linux_amd64` hashes HCP Terraform needs —
  regenerate with `terraform providers lock -platform=linux_amd64` from a plain
  `providers.tf` if this ever needs rebuilding

## Demo flow (recording guide)
1. **Sentinel pass** — both policies green on a normal plan
2. **Hard block** — edit `modules/cluster/main.tf:52`, change `instance_types` from
   `["t3.small"]` to `["p3.2xlarge"]`, push, show the hard block, then revert
3. **Soft block + override** — remove `owner =` from the `default_tags` workspace
   variable in the UI (no commit needed), queue a plan, show the soft block and the admin
   override-and-approve flow, then restore the tag
4. **Vault zero-trust** — show apply logs: dynamic credential auth → KV read → no static
   token anywhere
5. **Cloudability gate** — show the cost estimate firing post-plan; flip to mandatory with
   a low threshold to show a hard cost block

## Ep2→Ep5 handshake
`output.config_facts` (`outputs.tf`) is the contract consumed by Episode 5's Ansible
handshake. Keep this stable if refactoring.
