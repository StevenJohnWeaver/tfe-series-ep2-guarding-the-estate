# Drift Detection Setup

## Overview

HCP Terraform's workspace Health feature runs scheduled drift detection: a
`terraform plan -refresh-only` equivalent on a cadence you configure, comparing live
cloud resource attributes against the workspace's state file. When drift is found, the
workspace is flagged as **Drifted** in the HCP Terraform UI.

> This is a UI-level setting — there's no HCL for it.

> **Note on Stack Health:** the original Episode 3 spec describes a "Stack Health" rollup
> (a single Green/Amber/Red signal aggregating drift across all Stack components and
> deployments). As of this recording, Health/drift detection is workspace-only in HCP
> Terraform — there is no equivalent Stack-level setting. This episode demos drift
> detection on the `ep2-dev`, `ep2-staging`, and `ep2-prod` workspaces instead.

---

## Step 1: Enable Drift Detection

Health assessments can be enabled at the org level or per workspace.

**Org level (recommended for this demo — covers all three workspaces at once):**
1. HCP Terraform → **Organization Settings** → **Health**
2. Select **Enable for all workspaces**
3. Click **Update Settings**

**Per workspace (if you want to be selective):**
1. Open the workspace → **Settings** → **Health**
2. Toggle **Drift Detection** on
3. Set the check cadence (default is every 24 hours — for the recording, a shorter
   interval like every 1–2 hours makes it practical to demo without a long wait)

---

## Step 2: Understand the Cost Tradeoff

Each drift check is a refresh-only run against all resources in the workspace state. It:

- Consumes cloud provider API calls (rate limits matter at scale)
- Counts toward your HCP Terraform run quota

For a 3-workspace demo this is trivial. On camera, note that for a large estate the
check cadence is a deliberate visibility-vs-cost dial, not a "set to maximum and forget"
setting.

---

## Step 3: Reading Workspace Health

| State | Meaning |
|---|---|
| ✅ Healthy | All resources match their desired state. No drift detected. |
| ⚠️ Drifted | One or more resources differ from the state file. Review needed. |
| ❌ Errored | Health assessment failed — check the run logs for the cause. |

The workspace health state appears on the workspace overview and in the workspaces list,
so you can scan health across `ep2-dev`, `ep2-staging`, and `ep2-prod` from the project
view without opening each workspace individually.

---

## Step 4: Triggering an On-Demand Health Assessment

You don't have to wait for the schedule during the recording:

1. Open the workspace (e.g. `ep2-dev`)
2. Click **Actions** → **Start health assessment** (or navigate to the **Health** tab and
   trigger from there — exact label may vary by HCP Terraform version)
3. This queues a refresh-only run immediately

Use this right after the manual drift injection in `drift-demo-runbook.md` so the
Drifted status appears on camera within seconds rather than waiting for the schedule.

---

## Notes

- Drift detection only sees resources Terraform actually manages in state. Anything
  created entirely outside Terraform is invisible — drift detection catches *changed*
  attributes, not *unmanaged* resources.
- Remediation is a normal workspace plan/apply queued after detecting drift — it is
  **not auto-applied** unless the workspace has auto-apply enabled.
- Unlike Stack Health, there is no single rollup signal across all three workspaces.
  The project view in HCP Terraform shows per-workspace health indicators side-by-side,
  which is sufficient for the demo.
