# 1-800-CHROMED — Financial Gameplay & Employee Termination

**Implementation handoff for Claude / Codex**  
**Status:** Confirmed gameplay decisions, with explicitly labeled implementation assumptions  
**Scope:** Daily employee upkeep, payroll shortfalls and debt, disciplinary write-ups, firing employees, and permanent augments.

> **Supersession note:** For dual-ledger accounting, immediate sale settlement, cash-based augments, and dynamically modified upkeep, the newer [1-800-CHROMED_augments_financial_implementation.md](1-800-CHROMED_augments_financial_implementation.md) is authoritative. This older handoff remains applicable only where its firing, write-up, and payroll-carryover rules do not conflict.

## Objective

Integrate recurring personnel costs and financial consequences into the existing Prepare/Planning → Play → Report workday loop. Make hiring and keeping employees a meaningful commitment without adding player micromanagement during the autonomous sales day. **Inspect the actual codebase and existing documentation before editing; reuse its naming and architecture.**

## Confirmed design decisions

1. Every hired salesperson has a base **Daily Upkeep** stat; effective upkeep can be modified by augments and cannot fall below $0.
2. **All hired salespeople owe effective upkeep**, whether assigned to the 3×3 active floor or stored in the six-slot inactive salesperson inventory. Position can change an augment's effective modifier but does not waive the obligation.
3. Upkeep is charged at the existing payroll settlement, not continuously during the simulation. The prototype samples effective upkeep at end of day; snapshot versus time-weighted sampling remains unresolved.
4. If available funds cannot cover the day's upkeep, **unpaid upkeep carries into the next day**; it is not forgiven.
5. **Failure to cover current-day upkeep causes a financial write-up.** Previously accumulated debt does not by itself automatically cause another write-up if the current day's upkeep is covered.
6. Revenue-goal failures and financial failures use **one shared disciplinary counter**. **At most one write-up per workday**, even when both failures occur.
7. **Three cumulative write-ups terminate the run.** Write-ups persist across the quarter.
8. Players can **fire hired employees during Planning/Prepare only**. Firing permanently removes the employee from that run; unique employees cannot be rehired during the same run.
9. Firing costs no severance for now, triggers no write-up by itself, and stops that employee's **future** upkeep. It does **not** erase accrued debt.
10. **Installed augments are permanent.** They cannot be removed, transferred, or recovered. When a salesperson is fired, all installed augments are lost with them. Uninstalled augments remain in item inventory.
11. Position-based lead assignment, the 3×3 floor, automatic sales simulation, lead/discard systems, and existing class mechanics must continue working; this task must not replace them.

## Gameplay behavior by phase

### Planning / Prepare

- Show each employee's Daily Upkeep on relevant employee details and hiring UI.
- Show the **total projected upkeep** of all hired employees, including the bench, before starting the day.
- Show available cash, outstanding upkeep debt, and a comprehensible indication of financial risk.
- Allow firing a selected employee from either the floor or inactive roster. Provide an explicit confirmation warning that the employee **and installed augments will be permanently lost** and that the employee cannot be rehired this run.
- On confirmation, remove the employee from the roster and grid/inventory slot, update projected upkeep, and preserve existing debt and historical records.
- Do not permit firing during the active Play phase or after termination.

### Play

- Keep the sales floor fully autonomous; do not charge upkeep per call, tick, or animation frame.
- Preserve the existing revenue and sales-goal presentation, including sales-board feedback.
- Do not modify employee assignment priority because of upkeep or debt.

### Report / End of day

- Use already-settled Daily Sales Revenue, compute the day's effective upkeep from **all employees hired for that day**, and settle payroll exactly once.
- Evaluate whether current-day upkeep was fully covered and whether the existing revenue goal was met.
- Record both failure reasons independently, but increment the shared write-up counter by **no more than one** for the workday.
- Show gross revenue, total upkeep (ideally active and bench subtotals), debt brought forward, debt remaining, ending cash, goal result, payroll result, write-ups issued, and total write-ups.
- If write-ups reach three, enter the existing termination/game-over flow and prevent another workday from starting.

## Financial model — recommended implementation interpretation

The confirmed rule is that **unpaid upkeep carries forward**, while **old debt alone does not create a fresh financial write-up**. To implement these consistently, use explicit accounting for current-day payroll versus carried debt. The following allocation order is a **proposed implementation convention**; preserve a preexisting equivalent accounting model if one exists, or flag a conflict before changing it.

1. Sale proceeds are credited to Company Cash immediately; `available = company_cash immediately before payroll` (including any legitimate cash effects already settled).
2. `current_upkeep = sum(daily_upkeep for all employees hired for this workday)`.
3. `paid_current = min(available, current_upkeep)`.
4. `current_shortfall = current_upkeep - paid_current`.
5. `cash_after_current = available - paid_current`.
6. `paid_old_debt = min(cash_after_current, opening_upkeep_debt)`.
7. `ending_debt = opening_upkeep_debt - paid_old_debt + current_shortfall`.
8. `ending_cash = cash_after_current - paid_old_debt`.
9. `payroll_failed = current_shortfall > 0`.
10. `writeup_today = payroll_failed OR revenue_goal_failed`; apply **one** write-up if true.

This prioritizes **current-day upkeep** before prior unpaid upkeep. It allows old debt to persist without automatically generating another write-up. Debt is automatically paid down with cash remaining after current payroll; cash and debt should not both be positive at the end of settlement under this convention.

**Do not treat the debt balance as a new charge every day:** only the newly accrued upkeep is a new expense. Otherwise debt will compound incorrectly.

**Do not assume the sales goal is based on net earnings.** Keep the existing gross-revenue goal semantics unless current project documentation specifies otherwise.

### Worked example

| Day | Opening cash | Opening debt | Sales revenue | New upkeep | Closing debt | Closing cash | Payroll write-up? |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | $0 | $0 | $600 | $1,000 | $400 | $0 | Yes |
| 2 | $0 | $400 | $1,200 | $1,000 | $200 | $0 | No |
| 3 | $0 | $200 | $1,500 | $1,000 | $0 | $300 | No |

Revenue-goal failure may still cause a write-up on Days 2 or 3, subject to the one-per-day cap.

## Employee firing and augment lifecycle

- Fired employees must be removed from all active and bench slot references; no orphaned slot occupancy or dangling assignments.
- Do not fire during an in-progress call; the action is Planning-only.
- Preserve a record of fired unique character IDs so shop/hiring cannot offer them again in the current run.
- Destroy or mark permanently unavailable **only installed augments** belonging to the fired employee. Do **not** put them back in the 12-slot item inventory or sell them automatically.
- Do not remove uninstalled inventory augments.
- Firing does not refund hiring costs, surgery costs, or prior upkeep, and does not reduce debt already owed.
- Upkeep for the next day is computed using the remaining hired roster.
- Avoid adding severance, morale penalties, salvage, implant extraction, or rehire mechanics in this task.

## Write-up logic and edge cases

- Use **one shared write-up counter**, not separate financial and sales counters.
- Capture failure reasons separately for reporting, e.g. `revenue_goal_missed`, `current_upkeep_unpaid`.
- When both are true on one day, record both reasons and issue **exactly one** write-up.
- When neither is true, issue zero.
- Ensure settlement and write-up issuance are **idempotent**: reopening Report, replaying animations, or resuming a saved completed day must not charge upkeep or add write-ups again.
- An empty roster incurs zero employee upkeep; no financial write-up should arise from zero upkeep alone. Other existing loss conditions remain applicable.
- Employees on the bench cost exactly the same as when active.
- If the run ends on the third write-up, show all reasons from that day before the termination screen.
- Pause/resume, day transition, and save/load must not duplicate charges or erase debt.
- Clamp monetary amounts and upkeep to nonnegative valid values; avoid floating-point currency drift (prefer integer currency units if compatible with existing code).

## Important existing-system compatibility checks

Before implementing, inspect whether the game currently has a single budget/currency or separate cash, upgrade funds, and revenue counters. **Do not silently redefine an existing currency.** If a new cash ledger is needed, keep it distinct from gross sales and from any restricted enhancement budget; document how the two relate. Preserve existing purchases and sales-board calculations.

Also inspect the current status of daily revenue goals: previous design notes discussed them as an open question, while later gameplay discussion treats missing a daily goal as a write-up condition. **Use the project's actual current goal mechanic if present. Do not invent a new goal amount or failure rule merely to complete this task.** Flag any discrepancy in the implementation summary.

The base Daily Upkeep stat is confirmed; salary values and balance remain placeholders. Upkeep modification by augments is now confirmed by the newer implementation specification; do not treat any prototype fixture or its values as finalized balance.

## Acceptance tests

1. A rep on the active floor and a rep on the bench each contribute full upkeep.
2. Moving a rep between floor and bench does not change total upkeep.
3. Current upkeep is assessed once, at end of day, including on a zero-revenue day.
4. Unpaid upkeep carries into the next day and is reduced by subsequent surplus cash.
5. A day with current payroll fully covered but old debt remaining does **not** trigger a financial write-up solely because of old debt.
6. Missing the revenue goal alone issues one write-up (where the existing goal mechanic applies).
7. Failing payroll alone issues one write-up.
8. Failing both on the same day issues one write-up, with both reasons shown.
9. Three write-ups across different days terminate the run.
10. Firing from the floor or bench is allowed during Planning and disallowed during Play.
11. Fired employees cannot reappear in hiring during the same run.
12. Firing reduces future upkeep but does not change outstanding debt or erase a write-up.
13. Installed augments are permanently lost when their employee is fired; inventory augments are unaffected.
14. Reopening Report, save/load, and pause/resume cannot duplicate daily settlement.
15. Existing position-priority lead routing, Recycler/discard behavior, and sales outcome systems remain intact.

## Documentation and deliverables

1. Implement in the existing architecture and UI; do not create duplicate finance or employee-management systems.
2. Update `decisions.md` by **appending or reconciling these confirmed decisions**, preserving unrelated decisions and distinguishing unresolved economics from approved rules.
3. Update any employee, augment, inventory, and gameplay docs that define conflicting behavior.
4. Add focused automated tests where the project has a test framework; otherwise provide reproducible manual test steps.
5. Return a concise summary: changed files, behavior implemented, tests performed, outstanding ambiguities, and any departures from this document.

**Scope guard:** Do not add interest on debt, bankruptcy timers, extra penalties, new salary negotiations, morale, severance, firing refunds, augment salvage, or additional failure conditions without asking first.
