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
- **Org-level static AWS credential variable sets break dynamic credentials.** An org
  variable set named "AWS Credentials" (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` for
  `steveweaver-demo-user`) scoped to all workspaces conflicts with the dynamic provider
  credential set. The AWS *provider* uses dynamic creds correctly via
  `TFC_AWS_PROVIDER_AUTH`, but `data.aws_eks_cluster_auth` calls the SDK directly and picks
  up the static env vars instead — producing Kubernetes RBAC `forbidden` errors for
  `steveweaver-demo-user` instead of the dynamic role. Fix: remove the static variable set
  from any workspace using dynamic credentials, or scope it away from those workspaces.
- **EKS access entry propagation race on destroy/recreate.** When the cluster is
  destroyed and recreated, `aws_eks_access_entry.this["cluster_creator"]` (granted via
  `enable_cluster_creator_admin_permissions = true`) gets replaced for whichever principal
  ran `CreateCluster` this time. `module.auth`'s `data.aws_eks_cluster_auth` only depends on
  `module.cluster.cluster_name`, not on the access entry — a sibling resource — so it can
  generate a token before the new entry has propagated through the EKS control plane,
  causing `module.app` to fail with `Unauthorized`. Fixed with a `time_sleep` (30s) gating
  `module.auth` on all of `module.cluster` completing — see `main.tf`. If it still races,
  bump the sleep duration or just re-run apply (the entry will already exist on retry).

## Destroy sequence (ep2-dev cost-saving teardown)

This environment is periodically destroyed to save AWS costs and reapplied before recording.
The destroy has several non-obvious failure modes — follow this sequence to avoid them.

### Pre-destroy order
Downstream workspaces that live inside ep2's VPC must be destroyed first:
1. `ep4-ops-vm` — no AWS resources, destroy from HCP Terraform UI
2. `ep4-vm-prod` — EC2 instance/SG in ep2's VPC; destroy from HCP Terraform UI
3. `ep2-dev` — VPC and everything under it; steps below

### Removing Kubernetes resources from state before destroying
The Kubernetes provider authenticates via `module.auth.token` (a short-lived EKS token).
During a destroy run the token may resolve to empty (`system:anonymous` forbidden errors)
because the data source refresh fails or the token has expired. Rather than fighting this,
remove all Kubernetes-managed resources from state before queuing the destroy — the EKS
cluster deletion cleans up the underlying pods/namespaces anyway:

```bash
# Set up local CLI access to HCP Terraform (VCS-connected workspace blocks CLI-triggered runs
# in Remote mode — switch ep2-dev to Local execution mode first in HCP Terraform UI:
# Settings → General → Execution Mode → Local → Save)
export TF_WORKSPACE=ep2-dev
export TF_TOKEN_app_terraform_io=<your-hcp-terraform-token>
terraform init
terraform state rm module.app   # removes namespace, deployment, service from state
```

### Destroy the LoadBalancer Service's orphaned AWS resources manually
`module.app` includes a `kubernetes_service_v1` of type LoadBalancer, which creates an AWS
ELB and its own security group. Removing `module.app` from state does NOT delete these AWS
resources — they become orphaned and block VPC/IGW/subnet deletion:

1. **Delete the ELB** — AWS Console → EC2 → Load Balancers, or:
   ```bash
   aws elb describe-load-balancers --region us-east-1 \
     --query "LoadBalancerDescriptions[?VPCId=='<vpc-id>'].LoadBalancerName" \
     --output text
   aws elb delete-load-balancer --load-balancer-name <name> --region us-east-1
   ```
2. **Delete the ELB's security group** — after the ELB is gone its SG (`k8s-elb-*`) lingers:
   ```bash
   aws ec2 describe-security-groups \
     --filters "Name=vpc-id,Values=<vpc-id>" \
     --query "SecurityGroups[?GroupName!='default'].{ID:GroupId,Name:GroupName}" \
     --region us-east-1 --output table
   aws ec2 delete-security-group --group-id <sg-id> --region us-east-1
   ```

### Queue the destroy from HCP Terraform UI
Switch ep2-dev back to Remote execution mode (Settings → General → Execution Mode →
Remote → Save), then queue a destroy plan: Settings → Destruction and Deletion →
Queue destroy plan. The VPC, subnets, and IGW will now delete cleanly.

If the VPC delete still fails with `DependencyViolation`, wait 2–3 minutes for EKS control
plane ENIs to finish detaching, then re-run the destroy. Re-running is always safe — Terraform
skips already-deleted resources.

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
