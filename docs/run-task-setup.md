# Cloudability Run Task Setup

## Overview

IBM Cloudability is already connected at the **HCP Terraform organization level**.
This guide assigns it to the Episode 2 workspaces to gate plans between Plan and Apply.

> **What it does:** After every `terraform plan`, Cloudability receives the resource changes, estimates cost impact, and returns a pass/advisory/fail result before the apply can proceed.

---

## Prerequisites

- IBM Cloudability account with the HCP Terraform integration enabled (already done at org level)
- HCP Terraform organization admin or workspace admin access

---

## Step 1: Verify the Org-Level Run Task Integration

1. Go to **HCP Terraform** → **Organization Settings** → **Integrations** → **Run Tasks**
2. Confirm that `IBM Cloudability` appears in the list

---

## Step 2: Assign the Run Task to the Episode 2 Workspaces

1. Open the Run Task → **Scopes** tab
2. Set scope to apply to the `ep2-dev`, `ep2-staging`, and `ep2-prod` workspaces (or scope to the project containing them)
3. Stage: **Post-plan**
4. Enforcement level:
   - **Advisory** — cost estimate is shown, apply is never blocked (recommended to start)
   - **Mandatory** — cost threshold violation blocks the apply

---

## Step 3: Demo Script (Advisory Mode)

1. Make a change that increases compute (e.g., bump node count) and push
2. Open the workspace → a new plan run begins
3. After the plan completes, observe the **Run Task** checkpoint between Plan and Apply:
   - Status: `Passed` or `Advisory: cost increase detected`
   - Cloudability shows the estimated monthly cost delta
4. Approve the apply — cost visibility is embedded in the governance pipeline, not bolted on after

---

## Step 4: Demo Script (Mandatory Mode — Policy Trip)

1. Switch the Run Task enforcement to **Mandatory**
2. Set a low cost threshold in Cloudability (e.g., flag any apply that adds > $50/month)
3. Temporarily scale up a node group to a large instance type
4. Observe the apply being **blocked** with the Cloudability cost reason
5. Revert the change and re-apply to show the pass path

---

## Notes

- Cloudability Run Task results are included in the **HCP Terraform audit log**
- Cost thresholds and budgets are configured in the Cloudability UI, not in Terraform HCL
- The Run Task fires for every plan — including speculative plans on PRs if VCS is connected
