# Drift Demo Runbook

The point of this runbook is to produce **real, visible drift** safely and reversibly, so
the recording shows an actual workspace health state change instead of a staged screenshot.

> **Important caveat (this *is* the lesson, not a limitation to work around):** drift
> detection only re-checks resources Terraform already has in state. A brand-new resource
> created entirely outside Terraform (e.g. a new security group rule nobody declared) is
> invisible to it — there's nothing in state to compare against. To get a real drift signal,
> the manual change has to modify an **attribute of a resource Terraform already manages**.
> This is worth saying out loud on camera; it's exactly the "Terraform doesn't manage what
> it doesn't manage" point the script's Hook section makes.

---

## Demo A (primary): Tag drift on the VPC — ties straight into Sentinel governance

This is the most reliable option: tags are a core tracked attribute on every resource
Terraform manages via `default_tags`, so the drift always shows up, it's impossible to
break connectivity by changing a tag, and it pays off the "Reconciling at Scale" section's
claim that remediation still passes through Sentinel (`require-tags`) and Cloudability.

1. **Confirm baseline:** all three workspaces (`ep2-dev`, `ep2-staging`, `ep2-prod`) are
   healthy, last apply clean.
2. **Inject drift:** In the AWS Console, open the `ep2-dev` VPC (find it via the
   `ep2-dev` workspace's state output `vpc_id`, or look it up in the VPC console by
   the `environment = dev` tag) → **Tags** tab → remove the `owner` tag (or change its
   value to something obviously wrong, e.g. `unknown`).
3. **Trigger the check:** In HCP Terraform, open `ep2-dev` → **Actions** →
   **Start health assessment** (see `drift-detection-setup.md`).
4. **On camera:** `ep2-dev` workspace health flips to **Drifted**. Show the health
   assessment run — it reports `tags.owner` differs between state and live AWS.
5. **Remediate:** Queue a normal plan on `ep2-dev`. Terraform proposes restoring
   `owner = "platform"` (from `default_tags`). This plan passes through the full
   governance stack:
   - Sentinel's `require-tags` policy evaluates and passes cleanly — proving remediation
     can't silently reintroduce a tagging violation.
   - Cloudability Run Task fires post-plan with a cost estimate (cost delta is near-zero
     for a tag change, but the gate still runs — good point to make on camera).
6. **Approve and apply.** `ep2-dev` health returns to Healthy.
7. **Revert:** Nothing to revert — the apply already restored the correct tag.

---

## Demo B (optional, for visual variety): Security group rule description drift

Mirrors the Hook section's "toggling a firewall rule" line more literally. Slightly more
fragile to set up than Demo A — use only if you want a second drift example on camera.

1. In the AWS Console, find the **node security group** for the `ep2-dev` EKS cluster
   (`stacks-demo-dev-ep2` — find the security group via the EC2 console or the
   `ep2-dev` workspace state).
2. Edit an **existing** inbound rule's description field (not its CIDR/port — leave actual
   access unchanged) to something like `"manually edited"`.
3. Trigger an on-demand health assessment on `ep2-dev` as in Demo A.
4. The workspace shows Drifted; the health run reports the description change.
5. Queue a plan on `ep2-dev` to remediate — it reverts the description to its declared
   value. Approve and apply.

**Do not** add a brand-new security group rule for this demo — per the caveat above, an
entirely new, untracked rule won't be detected as drift at all, which undercuts the point.

---

## What NOT to demo live: instance-type "bill drift"

The script's fiscal-drift beat (upsizing a node's instance type directly in the console,
bypassing any plan-based cost gate) is real, but EKS managed node groups in this repo use
direct `instance_types` (see `modules/cluster/main.tf`), not a launch template — changing
the instance type isn't a console-editable in-place action; it requires replacing the node
group. **Narrate this one instead of demoing it live**: explain that *any* governance built
around a Terraform plan — Sentinel and Cloudability included — is blind to a change that
never produced a plan.

---

## Recovery

If anything looks wrong after the demo, the fastest reset is: re-run a normal plan/apply
on `ep2-dev` to reconcile state back to declared config, then re-run a health assessment
to confirm the workspace returns to Healthy before moving to the next section.
