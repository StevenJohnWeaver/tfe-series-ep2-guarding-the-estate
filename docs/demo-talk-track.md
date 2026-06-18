# Episode 3 Demo Talk Track
## "The Vigilant State — Drift Detection & Remediation"
**Format:** Lightboard / Demo | **Target Duration:** ~15 minutes

> **Before you record:** all three workspaces (`ep2-dev`, `ep2-staging`, `ep2-prod`) applied
> cleanly and showing Healthy, workspace Health/drift detection enabled
> (see `drift-detection-setup.md`), and the drift injection from `drift-demo-runbook.md`
> rehearsed at least once so you know the actual time-to-Drifted on your configured
> check cadence.
>
> **One adaptation from the original script, called out here so it doesn't surprise you
> mid-recording:**
> The script's Stack Health visual shows a single Green/Amber/Red rollup across fictional
> regions (US-East/EU-West/AP-South). HCP Terraform Health is workspace-scoped — there is
> no Stack-level rollup as of this recording. The demo uses per-workspace health on
> `ep2-dev`, `ep2-staging`, and `ep2-prod` instead. The narrative ("a single view of
> infrastructure health across your environments") still holds — describe what you see in
> the workspaces list as your multi-environment health dashboard.
>
> **Upside of the workspace pivot:** Cloudability is back in scope. Remediation plans run
> through the full governance stack — Sentinel AND Cloudability — which is a stronger payoff
> than Sentinel alone.

---

## 0:00 – 2:30 | The Hook: The "Shadow Infrastructure" Problem

**On screen:** Lightboard. Write **TRUTH** (green) and **REALITY** (red) with a widening gap
labeled **DRIFT**, plus a "Day N" label.

**Say:**
> "We've spent Episodes 1 and 2 building a governed estate — one that's scalable, secure, and
> cost-aware. But the moment you click Apply, the entropic clock starts. Drift at its most
> basic level happens when someone does something like toggling a firewall rule, but in the
> bigger picture, it's the environment evolving underneath your code.
>
> Today we move from Day 1 deployment to Day N verification — closing the gap between code
> intent and cloud reality. If your Terraform state diverges from what actually runs, your
> policies are checking a fiction."

**Key point:** Drift is the silent killer of governance.

**Note (say this explicitly):** "Drift is detected for resources Terraform manages in state —
things Terraform doesn't manage are invisible to drift checks. And these checks run on a
scheduled cadence, not as a real-time stream."

---

## 2:30 – 6:30 | The Handshake Integrity: When Reality Breaks the Blueprint

**On screen:** Lightboard — the three-workspace governance diagram from Episode 2 (the
Sentinel → Vault → Cloudability chain). Highlight that all three gates ran at plan time.
Then cut to HCP Terraform / AWS Console for the live demo.

**Say:**
> "In Episode 2 we established three governance gates — Sentinel policy, Vault dynamic
> credentials, and Cloudability cost guardrails — all evaluated at plan time. But those gates
> only fire when there's a plan. If someone changes something in the cloud console directly,
> there's no plan — so there's no gate. Governance is blind to it."

**On screen — live demo (Demo A from `drift-demo-runbook.md`):** Open the AWS Console, find
the `ep2-dev` VPC, remove the `owner` tag.

> "Let me show you exactly how HCP Terraform catches this. I'm changing a tag directly on
> this VPC, in the console — completely outside Terraform."

*[Switch to HCP Terraform, trigger a health assessment on ep2-dev]*

> "HCP Terraform's Health feature runs a scheduled refresh — essentially a
> `terraform plan -refresh-only` — on a cadence you configure. Default is every 24 hours,
> but you can tune it down. During the refresh, HCP Terraform queries the cloud provider
> APIs and checks if resources match the state file. I've set a short interval for the
> recording, but in production this runs on its own schedule.
>
> One important consideration: each health assessment consumes cloud API calls and counts
> toward your HCP Terraform run quota. For large estates, tune the frequency to balance
> visibility against cost."

*[ep2-dev workspace health flips to Drifted]*

> "And there it is. The ep2-dev workspace just went from Healthy to Drifted."

**On screen:** Show the health states in the workspaces list:
- ✅ Healthy — all resources match desired state
- ⚠️ Drifted — one or more resources differ from state
- ❌ Errored — health assessment failed

> "Open the health assessment run and you see exactly what drifted — here,
> `tags.owner` on the VPC differs between state and live AWS. That's your signal: something
> changed outside Terraform."

**On screen:** Cut to the bill-drift narration (no live demo — see `drift-demo-runbook.md`
for why).

> "Drift goes beyond just the technical — it can have a fiscal impact too. If a developer
> upsizes an instance directly in the console, there's no Terraform plan, so no policy
> evaluates it at all. No Sentinel check. No Cloudability cost gate. You've created bill
> drift — unauthorized spend the governance loop never saw, because governance only runs
> when there's a plan to evaluate."

---

## 6:30 – 10:30 | The Solution: Workspace Health & Multi-Environment Visibility

**On screen:** Lightboard — the HCP Terraform workspace list with health indicators across
`ep2-dev`, `ep2-staging`, `ep2-prod`. Draw a dashed line connecting them labeled
"HEALTH DASHBOARD".

**Say:**
> "In a traditional setup you'd check drift workspace-by-workspace — that's unscalable for
> large enterprise infrastructure. HCP Terraform's Health feature gives you a per-workspace
> drift signal visible from the project view. One place to look across all your environments.
>
> When one workspace drifts, you see it immediately in the dashboard without hunting through
> logs. That's your NOC-style view of architectural health across the estate."

*[Back to the live UI — show the ep2-dev Drifted state in context with ep2-staging and
ep2-prod still Healthy]*

> "Here you can see dev is drifted, while staging and prod are healthy. Exactly where the
> problem is, without any manual investigation.
>
> Remediation on workspaces is a normal plan — HCP Terraform queues a
> `terraform plan -refresh-only`-informed run against the drifted workspace, scoped to
> what's changed. It doesn't plan staging or prod — just the workspace that drifted."

**Note:** "Remediation doesn't auto-apply by default. It produces a plan for review and
approval, same as any other change — unless you've explicitly enabled auto-apply."

---

## 10:30 – 13:30 | Reconciling at Scale: Governance All the Way Through

**On screen:** Lightboard — the three-gate governance diagram from Episode 2 (Sentinel →
Vault → Cloudability). Draw an arrow labeled "REMEDIATION PLAN" flowing through all three
gates.

**Say:**
> "This is where the Episode 2 governance investment pays off in a day-2 scenario. We
> established three gates in that episode — and here's the key: a remediation plan isn't
> special. It's still a Terraform plan. So it still passes through every gate we set up."

*[Queue and show the remediation plan on ep2-dev]*

> "Watch what happens when I queue a plan to restore that tag. Sentinel's `require-tags`
> policy evaluates the plan — and passes. The plan is proposing to restore `owner = platform`,
> which is exactly what the policy requires. Fixing drift can't quietly reintroduce a
> policy violation — the policy is the gatekeeper on the way back in, not just on the way
> out."

*[Show the Cloudability Run Task firing]*

> "And Cloudability fires its cost estimate between plan and apply. The cost delta for
> restoring a tag is effectively zero, so it passes through. But notice: the gate ran. If
> this remediation had proposed a resource replacement that ballooned the bill, Cloudability
> would have flagged it before anyone clicked Apply."

*[Approve and apply. ep2-dev returns to Healthy.]*

> "Dev is healthy again. The entire remediation loop — detect, plan, governance check,
> apply — ran without touching staging or prod."

**On screen:** Lightboard — VCS repo icon at the top with arrows down to three workspaces.

> "And here's the scale story. These three workspaces are all VCS-connected to the same
> repo. When drift reveals a misconfiguration in the shared infrastructure code — not just
> a manual console change, but something in the Terraform itself — you fix it once in the
> repo. That single commit triggers a governed plan across dev, staging, and prod
> simultaneously. One source of truth, three governed deployments."

---

## 13:30 – 15:00 | Summary & The Bridge to Episode 4

**On screen:** Lightboard — circle "REMEDIATION", write "EPISODE 4: THE REACTIVE FABRIC".

**Say:**
> "We've built the engine, the brakes, and now the radar. We can detect when reality
> deviates from our blueprint and reconcile it across the estate with the full governance
> stack — Sentinel, Vault, and Cloudability — still in play. But some fixes need
> coordination beyond a Terraform apply — rotating credentials, restarting services,
> notifying owners. Next time: Terraform Actions and the Reactive Fabric that ties
> infrastructure events to the rest of your business.
>
> One more note: we focused on drift detection here — checking whether resources match their
> configuration. Continuous Validation is a related but separate feature that runs custom
> validation rules against live infrastructure — things like 'is the SSL certificate still
> valid?' We'll cover that in a future deep dive."

**Call to action:** "Enable Health on your workspaces today, and reclaim the integrity of
your infrastructure."

---

## Timing Reference

| Section | Duration |
|---|---|
| The Hook | 2:30 |
| Handshake Integrity (incl. live drift demo) | 4:00 |
| Workspace Health & Multi-Environment Visibility | 4:00 |
| Reconciling at Scale | 3:00 |
| Summary & Bridge | 1:30 |
| **Total** | **~15:00** |

---

## Recording Tips

- Rehearse the drift injection (`drift-demo-runbook.md`, Demo A) at least once before
  recording so you know how long the health assessment takes after injection — trigger it
  manually rather than waiting for the schedule on camera
- Have the AWS Console and HCP Terraform UI both open in separate tabs/windows ahead of time
- The workspaces list with per-workspace health indicators side-by-side is your "dashboard"
  shot — make sure ep2-staging and ep2-prod are Healthy when you show ep2-dev as Drifted,
  so the contrast is clear
- The Cloudability gate firing on the remediation plan is a genuine payoff moment — make
  sure it's connected to the workspace before recording (see `docs/run-task-setup.md`)
