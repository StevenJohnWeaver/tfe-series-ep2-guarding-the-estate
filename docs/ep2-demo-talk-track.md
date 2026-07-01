# Episode 2 Demo Talk Track
## "Guarding the Estate — Identity, Policy, and Cost"
**Format:** Lightboard / Demo | **Target Duration:** ~15 minutes

> **Before you record:**
> - `ep2-dev` applied cleanly — all three workspaces Healthy in HCP Terraform
> - Org-level "AWS Credentials" variable set removed from ep2-dev (or scoped away) — leaving
>   it attached breaks the Kubernetes auth and will derail the Vault segment
> - Cloudability Run Task connected to ep2-dev (Settings → Run Tasks)
> - Vault dynamic credentials configured and JWT roles in place (see `vault-setup.md`)
> - Have HCP Terraform (ep2-dev runs tab) open and ready
> - Know where `modules/cluster/main.tf` line 52 is — you'll edit `instance_types` live
> - Know where the `default_tags` workspace variable is in the UI — you'll remove `owner` live
> - **15-minute EKS token window:** once the cluster is up, you have ~15 min to approve
>   any plan before `module.auth` expires and the apply fails with Unauthorized. Keep a
>   clock running and approve plans immediately after reviewing them.

---

## 0:00 – 2:00 | The Hook: The Governance Gap

**On screen:** Lightboard. Draw a timeline labeled **DAY 1** on the left and **DAY N** on the
right. Write **DEPLOY** under Day 1 and **OPERATE** under Day N. Draw three columns between
them labeled **POLICY**, **IDENTITY**, **COST** — then draw an X through each one.

**Say:**
> "In Episode 1, we built a governed estate with Terraform Stacks — scalable, automated,
> repeatable. But there's a gap. Day 1 infrastructure is deployed. What governs what it
> *becomes* on Day 2, Day 10, Day 100?
>
> Today we close that gap with three governance pillars that wrap every change you make to
> your infrastructure — before it ever touches a cloud resource.
>
> The first is **Sentinel** — policy-as-code. Not documentation, not a checklist, not an
> email thread asking someone to review a plan. Machine-enforced policy embedded directly in
> the Terraform workflow.
>
> The second is **Vault dynamic credentials** — zero static secrets. No access keys. No
> rotation schedules. No shared credentials in a variable that seven people have touched.
>
> The third is **Cloudability** — cost guardrails as a gate. Not a bill at the end of the
> month. A check between your plan and your apply, before the expensive resource exists.
>
> Three gates. One workflow. Let's walk through each."

---

## 2:00 – 7:00 | Pillar 1: Sentinel — Policy as Code

**On screen:** Lightboard. Write **SENTINEL** and draw the HCP Terraform run lifecycle:
Plan → **Policy Check** → Apply. Circle Policy Check.

**Say:**
> "Sentinel is HashiCorp's policy-as-code framework, built into the HCP Terraform run
> lifecycle. Every plan — every single one — passes through a policy evaluation before
> anyone can click Apply. It's not a suggestion. It's not a lint warning. It's a gate."

**On screen:** Show HCP Terraform — ep2-dev → a recent run → Policy Checks section. Both
policies green.

> "Here's what a passing run looks like. Two policies evaluate against this plan:
> `allowed-instance-types` — a hard-mandatory policy that blocks GPU instance types from
> being deployed without an explicit exception process — and `require-tags` — a soft-mandatory
> policy that enforces cost attribution tags on every resource.
>
> Both passing. Clean plan. The policies ran, evaluated the change, and confirmed it's within
> the guardrails we defined. Let me show you what it looks like when it isn't."

---

### Trip-wire 1: Hard Block (`allowed-instance-types`)

**On screen:** Open `modules/cluster/main.tf`, line 52. Change `instance_types = ["t3.small"]`
to `instance_types = ["p3.2xlarge"]`. Commit and push to `main`.

**Say:**
> "I'm changing the EKS node group instance type to a p3 GPU instance. In a real estate,
> this might be someone trying to run a workload that isn't approved for the account, or just
> picking the wrong type from a dropdown. Let's push it and see what happens."

*[Switch to HCP Terraform — ep2-dev. Show the plan queuing, then the policy check result.]*

> "The plan finished. But before anyone can approve it — Sentinel ran. `allowed-instance-types`
> evaluated the planned EKS node group and found `p3.2xlarge` is not in the allowed prefix
> list. **Hard-mandatory block.** There is no override, no exception flow, no 'ask your
> manager.' This plan cannot proceed. Period.
>
> The policy didn't block the *deploy*. It blocked the *plan*. The resource was never created.
> That's the distinction: you're not cleaning up after a bad deploy — you're preventing it
> from ever existing."

**On screen:** Revert `modules/cluster/main.tf` line 52 back to `["t3.small"]`. Push.

---

### Trip-wire 2: Soft Block + Override (`require-tags`)

**On screen:** HCP Terraform → ep2-dev → Variables. Find `default_tags`. Remove the
`owner = "platform"` entry. Queue a plan manually (no code push needed).

**Say:**
> "Now I'm removing the `owner` cost-attribution tag from the workspace variable. No code
> change — just a workspace variable edit. Let's see if governance catches it."

*[Show the plan result — `require-tags` soft-mandatory block.]*

> "`require-tags` fired. Every resource in this plan is missing the `owner` tag — because
> it's no longer in the default tags. Soft-mandatory, which means this *can* be overridden.
> But watch how."

*[Demonstrate the override flow — show the override comment/justification field.]*

> "An admin can override a soft-mandatory block with a justification. And here's the key:
> that override is logged. It becomes part of the run's audit record — who overrode it, when,
> and what they said. Governance didn't disappear when the admin clicked override.
> It *recorded* the exception. That's the difference between policy-as-code and
> policy-as-honour-system."

*[Restore `owner = "platform"` in `default_tags`. Queue a new plan to show it passing clean.]*

---

## 7:00 – 10:30 | Pillar 2: Vault — Zero Static Secrets

**On screen:** Lightboard. Draw a lock with the label **STATIC SECRET** — cross it out.
Draw a clock labeled **DYNAMIC CREDENTIAL** with a short TTL arrow.

**Say:**
> "Every static credential is a liability. An access key sitting in a workspace variable
> has a blast radius: anyone who can read that variable, any process that logs it, any rotation
> gap — those are all attack surface. And in a large organisation, static credentials are
> often shared, copied, and forgotten.
>
> The answer isn't more rotation. It's elimination."

**On screen:** Show the HCP Terraform workspace — ep2-dev — environment variables. Point to
`TFC_VAULT_PROVIDER_AUTH=true` and `TFC_VAULT_RUN_ROLE`.

> "HCP Terraform has a native integration with HashiCorp Vault via OIDC. When a run starts,
> HCP Terraform requests a short-lived credential from Vault using a JWT that identifies this
> specific workspace, this specific run. Vault validates the JWT, issues a token scoped to
> exactly what this workspace needs, and the run uses it. The token expires when the run ends.
>
> There's no access key. There's nothing to rotate. There's nothing to steal — because there's
> nothing static."

**On screen:** Show the ep2-dev apply logs — scroll to the Vault authentication event and
the KV secret read.

> "Here in the apply logs — Vault dynamic credentials authenticated. The workspace exchanged
> its OIDC JWT for a scoped token, used that token to read the KV secret, and the secret is
> in state as a sensitive value. No token persists after this run. The next run will get a
> different token. The previous one is already expired.
>
> Zero static secrets. Not in the variables. Not in the logs. Not in the state file.
> Nowhere."

---

## 10:30 – 13:30 | Pillar 3: Cloudability — Cost as a Gate

**On screen:** Lightboard. Draw the HCP Terraform run lifecycle again: Plan → Policy Check →
**Cost Estimate** → Apply. Circle Cost Estimate.

**Say:**
> "The third gate sits between your policy check and your apply: cost. Most organisations find
> out about infrastructure spend at the end of the month. By then, the resource has been
> running for weeks. Cloudability brings the cost signal forward — into the plan review, before
> the resource exists."

**On screen:** Show the ep2-dev run — the Cloudability Run Task result between plan and apply.

> "After the plan passes Sentinel, Cloudability fires. It analyses the planned resources,
> estimates the monthly cost delta, and returns a result. Here the estimate passes — the
> planned change is within our cost envelope.
>
> But watch what happens when I flip the enforcement level."

*[In HCP Terraform Run Task settings, flip Cloudability from Advisory to Mandatory and set a
low cost threshold. Queue a new plan.]*

> "Advisory means the estimate appears but doesn't block the run. Mandatory means it does.
> I've set a low threshold — let's see if this plan clears it."

*[Show the Cloudability block — run cannot proceed without approval.]*

> "Blocked. The planned cost delta exceeds the threshold. Before anyone clicks Apply — before
> the resource exists — the cost gate fired.
>
> This is the shift: from reactive cost management to proactive cost governance. Not a bill
> review. A gate. Same workflow, same audit trail, same approval process as Sentinel.
> Cost is just another policy."

*[Restore Cloudability to Advisory enforcement before finishing.]*

---

## 13:30 – 15:00 | Summary & The Bridge to Episode 3

**On screen:** Lightboard — write all three pillars in a column: **SENTINEL**, **VAULT**,
**CLOUDABILITY**. Draw a single bracket around all three labeled **THE GOVERNANCE LAYER**.
Then write **EPISODE 3: THE VIGILANT STATE**.

**Say:**
> "Three gates. Every plan passes through all three — in that order. Policy first, because
> a plan that violates policy should never reach a cost estimate. Credentials are dynamic,
> because the governance layer itself shouldn't have static secrets. And cost is a gate, not
> a report.
>
> Together, these turn Terraform from a deployment tool into a governance platform. The
> infrastructure doesn't just get built — it gets built within guardrails that are enforced,
> logged, and auditable.
>
> But there's still a gap. These gates run at plan time. What about the moment between
> applies — when someone changes something directly in the console, outside Terraform? When
> reality drifts away from your blueprint without anyone queuing a plan?
>
> In the next episode, we close that gap. **The Vigilant State** — drift detection, workspace
> health, and what it means to maintain infrastructure integrity across your entire estate,
> not just at deploy time."

**Call to action:**
> "Look at your current Terraform workflows — and identify one policy that lives in a wiki
> or a review checklist. Make it a Sentinel rule. Make it a gate."

---

## Timing Reference

| Segment | Duration |
|---|---|
| The Hook | 2:00 |
| Sentinel — pass + hard block + soft block/override | 5:00 |
| Vault — zero static secrets | 3:30 |
| Cloudability — cost as a gate | 3:00 |
| Summary & Bridge to Ep3 | 1:30 |
| **Total** | **~15:00** |

---

## Recording Tips

- **EKS token is your clock.** The `aws_eks_cluster_auth` token expires in ~15 minutes. Start
  it when the cluster apply finishes and approve plans immediately — don't let the plan sit
  waiting for you to finish narrating. If it expires mid-recording, re-run apply; the
  `time_sleep` fix means it will succeed on retry.
- **Hard block is fast — give it room.** The p3 block happens at policy check, before apply,
  so it's quick. Budget ~2 minutes including the edit, push, plan queue, and narration. Don't
  rush — the block is the payoff, linger on the UI long enough for the audience to read it.
- **Soft block: restore the tag before moving on.** After the override demo, restore
  `owner = "platform"` in `default_tags` and confirm a clean plan before recording the Vault
  segment. A workspace still in soft-block adds visual noise to subsequent screenshots.
- **Vault log scroll.** The dynamic credential auth appears early in the apply log — know
  where to scroll before recording so you don't hunt for it on camera. Run a test apply
  and screenshot the relevant log section to use as a reference during the recording.
- **Cloudability: flip back to Advisory.** After showing the cost block, restore the Run Task
  to Advisory enforcement before ending the recording — otherwise ep3 remediation plans will
  be blocked by a cost gate set to an artificially low threshold.
- **The three-gate summary diagram is the closer.** SENTINEL → VAULT → CLOUDABILITY in a
  column with a single bracket is the visual the audience takes away. Write it slowly and let
  it sit on screen while you deliver the bridge to Ep3.
