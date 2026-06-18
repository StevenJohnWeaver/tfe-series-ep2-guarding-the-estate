# Vault Setup for Episode 2

Complete commands to configure HCP Vault for this repo's workspace dynamic credentials.
Run these against the HCP Vault cluster referenced in the workspace environment variables
(`TFC_VAULT_ADDR`) with the `admin` namespace.

```shell
export VAULT_ADDR="https://<your-hcp-vault-cluster>.z1.hashicorp.cloud:8200"
export VAULT_NAMESPACE="admin"
# vault login <your-token>
```

---

## 1. Enable JWT Auth (once per cluster)

```shell
vault auth enable jwt

vault write auth/jwt/config \
  oidc_discovery_url="https://app.terraform.io" \
  bound_issuer="https://app.terraform.io"
```

---

## 2. Create Vault Policy

A single policy covers all three workspaces — each reads from its own `ep2-demo/*` path.

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

---

## 3. Create JWT Roles

Workspace dynamic credentials use the workspace `sub` JWT claim (not `terraform_workspace_name`,
which is a different field). The `sub` format for workspaces is:
`organization:<org>:project:<project>:workspace:<workspace-name>:run_phase:<phase>`

Replace `<org>` with your HCP Terraform organization name.

```shell
vault write auth/jwt/role/hcp-terraform-ep2-dev \
  role_type="jwt" \
  bound_audiences="vault.workload.identity" \
  bound_claims_type="glob" \
  bound_claims='{"sub":"organization:<org>:project:*:workspace:ep2-dev:run_phase:*"}' \
  user_claim="sub" \
  policies="ep2-demo" \
  ttl="1h"

vault write auth/jwt/role/hcp-terraform-ep2-staging \
  role_type="jwt" \
  bound_audiences="vault.workload.identity" \
  bound_claims_type="glob" \
  bound_claims='{"sub":"organization:<org>:project:*:workspace:ep2-staging:run_phase:*"}' \
  user_claim="sub" \
  policies="ep2-demo" \
  ttl="1h"

vault write auth/jwt/role/hcp-terraform-ep2-prod \
  role_type="jwt" \
  bound_audiences="vault.workload.identity" \
  bound_claims_type="glob" \
  bound_claims='{"sub":"organization:<org>:project:*:workspace:ep2-prod:run_phase:*"}' \
  user_claim="sub" \
  policies="ep2-demo" \
  ttl="1h"
```

> **Workspace vs Stacks claim difference:** workspace runs use `user_claim="sub"` with
> `bound_claims` pinning the workspace name. Stacks identity tokens also use `user_claim="sub"`
> but their `sub` format is different:
> `organization:<org>:project:<project>:stack:<stack-name>:deployment:<deployment-name>:operation:<operation>`.
> The claim name `terraform_workspace_name` does NOT exist in Stacks tokens — using it
> gives a 400 "claim not found in token" error.

---

## 4. Enable KV v2 and Write Secrets

```shell
vault secrets enable -path=secret kv-v2

vault kv put secret/ep2-demo/dev/app-config \
  db_host="demo-db.internal" \
  api_key="DEMO"

vault kv put secret/ep2-demo/staging/app-config \
  db_host="demo-db-stg.internal" \
  api_key="DEMO"

vault kv put secret/ep2-demo/prod/app-config \
  db_host="demo-db-prd.internal" \
  api_key="DEMO"
```

---

## 5. Configure Workspace Environment Variables

Per workspace, set the following as **Environment Variables** (not Terraform Variables):

| Variable | Value |
|---|---|
| `TFC_VAULT_PROVIDER_AUTH` | `true` |
| `TFC_VAULT_ADDR` | Your HCP Vault cluster address |
| `TFC_VAULT_NAMESPACE` | `admin` |
| `TFC_VAULT_RUN_ROLE` | `hcp-terraform-ep2-dev` (or `-staging` / `-prod`) |

> These must be **Environment Variables**, not Terraform Variables — easy to miscategorize
> in the UI.

---

## 6. Verify

After a successful workspace apply, confirm dynamic credentials are working by checking
the run logs for the `secrets` module. Look for a Vault JWT auth exchange followed by a
KV read — no static token should appear anywhere in the output.
