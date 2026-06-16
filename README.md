# Episode 2 Demo: Guarding the Estate — Identity, Policy, and Cost

This repo demonstrates three layers of enterprise governance on a standard HCP Terraform **workspace** (not Stacks):

- **Sentinel** — Hard and soft-mandatory policy-as-code
- **Vault** — Dynamic credentials via OIDC; zero static secrets
- **Cloudability** — Cost guardrails as a Run Task gate between Plan and Apply

> **Why workspaces instead of Stacks?** This episode originally targeted Terraform Stacks, but as of this recording Stacks does not yet support Run Tasks, and Sentinel policy evaluation against Stack plans is unproven. All three governance layers are fully supported on standard workspaces today, so this repo uses that model. The infrastructure (VPC → EKS → Kubernetes App) is otherwise identical to the Ep1/Stacks version.

---

## Structure

```
.
├── main.tf            # network, cluster, auth, app, secrets modules
├── providers.tf        # AWS, Kubernetes, Vault, dynamic credentials config
├── variables.tf         # Workspace input variables
├── outputs.tf            # config_facts output for the Ep5 Ansible handshake
├── modules/
│   ├── network/          # VPC
│   ├── cluster/           # EKS
│   ├── app_auth/           # EKS auth token
│   ├── app/                 # Kubernetes app
│   └── secrets/               # Vault KV read via dynamic credentials
├── sentinel/
│   ├── sentinel.hcl
│   ├── allowed-instance-types.sentinel
│   └── require-tags.sentinel
└── docs/
    └── run-task-setup.md   # Cloudability Run Task setup guide
```

---

## Prerequisites

- HCP Terraform org (same org used for Ep1/Ep2 Stacks demos)
- AWS account with an IAM role trusting HCP Terraform's OIDC issuer
- HCP Vault cluster with JWT auth enabled
- IBM Cloudability connected at the HCP Terraform org level

---

## Setup

### 1. Create three workspaces

Create `ep2-dev`, `ep2-staging`, `ep2-prod` in HCP Terraform, each connected to this repo (CLI-driven or VCS-connected — VCS recommended so plans trigger on push).

### 2. Configure AWS dynamic credentials (per workspace)

Set these as workspace **environment variables**:

| Variable | Value |
|---|---|
| `TFC_AWS_PROVIDER_AUTH` | `true` |
| `TFC_AWS_RUN_ROLE_ARN` | `arn:aws:iam::<account-id>:role/<your-role>` |

**AWS-side:** update the IAM role's trust policy to allow the workspace OIDC subject format:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::<account-id>:oidc-provider/app.terraform.io" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "app.terraform.io:aud": "aws.workload.identity" },
    "StringLike": { "app.terraform.io:sub": "organization:<org>:project:*:workspace:ep2-*:run_phase:*" }
  }
}
```

### 3. Configure Vault dynamic credentials (per workspace)

Set these as workspace **environment variables**:

| Variable | Value |
|---|---|
| `TFC_VAULT_PROVIDER_AUTH` | `true` |
| `TFC_VAULT_ADDR` | Your HCP Vault cluster address |
| `TFC_VAULT_NAMESPACE` | `admin` |
| `TFC_VAULT_RUN_ROLE` | `hcp-terraform-ep2-dev` (or `-staging`/`-prod`) |

**Vault-side:** update (or create) the JWT roles to bind on the workspace `sub` claim format:

```shell
vault write auth/jwt/role/hcp-terraform-ep2-dev \
  role_type="jwt" \
  bound_audiences="vault.workload.identity" \
  bound_claims_type="glob" \
  bound_claims='{"sub":"organization:<org>:project:*:workspace:ep2-dev:run_phase:*"}' \
  user_claim="sub" \
  policies="ep2-demo" \
  ttl="1h"
```

Repeat for `ep2-staging` and `ep2-prod`, swapping the workspace name in `bound_claims`.

The `ep2-demo` policy and KV secrets are unchanged from the original setup:

```shell
vault policy write ep2-demo - <<EOF
path "secret/data/ep2-demo/*" {
  capabilities = ["read"]
}
path "auth/token/create" {
  capabilities = ["create", "update"]
}
EOF
```

### 4. Set workspace Terraform variables

Per workspace, set:

| Variable | dev | staging | prod |
|---|---|---|---|
| `region` | `us-east-1` | `us-east-1` | `us-west-2` |
| `cluster_name` | `stacks-demo-dev-ep2` | `stacks-demo-stg-ep2` | `stacks-demo-prd-ep2` |
| `kubernetes_version` | `1.30` | `1.30` | `1.30` |
| `vpc_cidr` | `10.100.0.0/16` | `10.101.0.0/16` | `10.102.0.0/16` |
| `environment` | `dev` | `staging` | `prod` |
| `default_tags` | `{environment="dev", owner="platform"}` | `{environment="staging", owner="platform"}` | `{environment="prod", owner="platform"}` |

### 5. Attach the Sentinel policy set

1. HCP Terraform → **Policies** → **Policy Sets** → **Create Policy Set**
2. Source: this repo, **Policies path**: `sentinel/`
3. Scope: the `ep2-dev`, `ep2-staging`, `ep2-prod` workspaces

### 6. Set up the Cloudability Run Task

Follow [`docs/run-task-setup.md`](docs/run-task-setup.md).

---

## Demo Sequence (Recording Guide)

1. **Sentinel Pass** — Apply as normal → both policies pass → annotate the policy checkpoint in the UI
2. **Sentinel Fail (hard)** — Change an instance type to `p3.2xlarge` → `allowed-instance-types` hard-blocks the plan
3. **Sentinel Override (soft)** — Remove a tag → `require-tags` soft-blocks → demonstrate the admin override flow
4. **Vault Zero-Trust** — Show the run logs: dynamic credentials → KV read → no static token anywhere
5. **Cloudability Gate** — Show cost estimate between Plan and Apply; flip to Mandatory and demonstrate a cost block

## Notes

- The EKS auth token (`module.app_auth`) is valid for ~15 minutes. Approve plans promptly so apply doesn't run against a stale token.
- `output.config_facts` mirrors the contract consumed by the Episode 5 Ansible handshake.
