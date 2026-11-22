# 1-800-CHROMED — Augments & Financial Systems Implementation Specification

**Audience:** Claude working in the existing Godot/GDScript game repository.  
**Purpose:** Implement the agreed augment rules, dual monetary accounting, reactive financial effects, and their integration with the workday loop.  
**Status:** Confirmed mechanics are requirements. Sample augments are illustrative content, not a mandatory final catalog. Open decisions must remain configurable or be surfaced rather than silently decided.

## 0. Instructions to Claude

1. Inspect the current repository, scenes, data models, `decisions.md`, and any existing augment, employee, inventory, sales, payroll, and event code before changing anything. Do not assume the project is empty or overwrite working implementations.
2. Preserve existing game behavior except where this specification explicitly supersedes it. Reconcile naming differences (Prepare/Plan, Play/Workday, Report/Review) with actual project structure.
3. Implement **data-driven** augments, composable modifiers, event triggers, and cash effects. Avoid hardcoding sample augment behavior into UI scenes or employee classes.
4. Separate simulation rules from presentation. The simulation must be deterministic with a seeded RNG and testable without rendering.
5. Update repository `decisions.md` with *confirmed* decisions and references to this specification. Do not promote sample values or unresolved options to confirmed design.
6. Add tests or reproducible simulation cases for the edge conditions below. If the repo lacks test infrastructure, add a lightweight test harness or clearly documented manual test procedure.
7. Report files changed, architectural choices, test results, and any unresolved design questions. Do not silently invent economy balance numbers.

## 1. Core game context

- Cyberpunk call-center management autobattler; workday phases: planning/team management, autonomous simulated workday, review/reward.
- Sales floor is a **3×3 grid** of nine positions. Lead assignment follows fixed slot priority 1–9, skipping busy reps. Orthogonal adjacency means up/down/left/right, not diagonals.
- Inactive employee inventory is **1×6**; shared item/augment inventory is **2×6**. New hires enter inactive inventory.
- Salespeople have Speed, Conversion, Upsell Chance, Upsell Multiplier, and **daily upkeep**. Employees have distinct identities and can be hired only once per run. A Recycler works only from the day's discarded leads; failed Recycler attempts permanently remove those leads from discard.
- Baseline call progress uses `delta_progress_fraction = effective_speed / 18 * delta_seconds` for progress normalized to 0–1. A completed call rolls Conversion and, on success, Upsell Chance, using effective stats at completion.
- Each workday has a sales goal. Missing the sales goal or failing to pay upkeep can cause **at most one write-up per workday**; three write-ups end the run. Unpaid upkeep carries forward.
- All hired employees incur **full applicable daily upkeep**, whether active or in inactive inventory. Players may fire employees during planning; installed augments are destroyed with fired employees.

## 2. Two monetary ledgers — CONFIRMED

Maintain two **separate** quantities, both displayed in dollars:

| Ledger | Meaning | Lifecycle |
| --- | --- | --- |
| **Daily Sales Revenue** | Performance score credited toward the daily sales target and sales-board animation | Starts at zero each workday; resets for the next day |
| **Company Cash** | Actual spendable money for purchases, surgery, hiring, payroll, and cash-based effects | Persists across workdays; cannot go below zero |

**Sale settlement and above-goal cash:** Whenever a successful sale (including an upsell) earns its monetary amount, credit the full amount **immediately to Daily Sales Revenue**. At day-end settlement, Company Cash receives only cumulative daily sales revenue above the day's sales goal: `max(0, daily_sales_revenue - daily_sales_goal)`. Existing Company Cash remains available to augments during Play and carries forward, but it never contributes to the daily sales goal. Sales-derived surplus is not available to cash-based augments until settlement.

| Event | Daily Sales Revenue | Company Cash |
| --- | --- | --- |
| Successful sale for $X | +X immediately | No immediate credit; cumulative above-goal surplus is added at day-end settlement |
| Successful upsell amount $Y | +Y immediately | No immediate credit; cumulative above-goal surplus is added at day-end settlement |
| Cash-granting augment | Unchanged unless effect explicitly says otherwise | +grant immediately |
| Cash-penalty augment | Unchanged | Deduct up to available cash immediately |
| Shop, hiring, surgery | Unchanged | Deduct purchase cost |
| Payroll settlement | Unchanged | Deduct payable upkeep, record any unpaid remainder |
| New workday | Reset to zero | Carry forward |

**Cash-limited penalties — CONFIRMED:** Direct augment cash penalties cannot reduce Company Cash below $0. Example: cash $20, penalty $50 => deduct $20, discard the $30 excess; **do not create debt**. Existing **unpaid upkeep** is the separate exception: outstanding payroll obligations carry forward. A direct cash penalty never reduces Daily Sales Revenue. Cash-granting effects do not automatically count toward the sales goal.

**Sales-board presentation:** The scoreboard measures **Daily Sales Revenue**, not Company Cash or net profit. Existing Company Cash does not count toward the goal. Its tally/impact animation uses sales totals; the board is demolished **only when the sales goal is beaten**, even if the company is cash-poor. Avoid double-crediting during the end-of-day animation: the animation replays/visualizes already-settled sales, not additional financial transactions.

**Accounting:** Keep traceable transactions/events with source employee/augment, timestamp, amount requested, amount actually applied, and ledger affected. Display cash and revenue separately in relevant screens; review should show sales performance, cash flow, upkeep paid, unpaid carryover, and write-up cause(s).

## 3. Upkeep and payroll — CONFIRMED / OPEN

- Every hired employee has a base daily upkeep amount. Treat effective upkeep as a dynamically calculated attribute eligible for augment modifiers, just like other stats.
- Augments can increase, decrease, transfer, or conditionally modify upkeep; effective upkeep has a floor of **$0**.
- Upkeep modifiers may depend on employee position, adjacent coworkers, events, current Company Cash, or other effective attributes.
- Upkeep is **charged during the existing payroll settlement**, **not continuously** as time passes. Recompute effective upkeep as relevant conditions change, so it is available for displays and dependent augments.
- Upkeep owed that cannot be paid remains outstanding into future days. A missed payroll can trigger a write-up, subject to the global one-per-day cap. Do not let ordinary cash penalties create debt.
- Do not waive upkeep for employees sitting in inventory; position-dependent effects may be inactive when a rep has no board position, but the employee still owes upkeep.

**OPEN: How is the day's final payroll obligation sampled?** End-of-day snapshot of effective upkeep was **recommended but not yet explicitly selected**; a time-weighted calculation was offered as an alternative. Do not present either as confirmed. Implement an isolated payroll-amount policy or configurable strategy and request a decision before locking the rule. A simple end-of-day snapshot may be used as a clearly marked prototype assumption if necessary.

**OPEN: Payroll payment priority / handling of prior unpaid balances** has not been specified here. Preserve existing repository behavior or surface the question. Ensure no double-charge and carryover is auditable.

## 4. Augment philosophy and rarity — CONFIRMED

Augments are employee-installed cybernetics that change **behavior and interactions**, not merely provide bland flat-stat upgrades. The goal is emergent synergies, meaningful drawbacks, positioning choices, and surprising builds. Augments may affect sales stats, call progress, coworker relationships, upkeep, Company Cash, and credited revenue when explicitly specified.

- Rarities: **Common, Rare, Epic, Legendary**. Rarity affects availability and **mechanical complexity**, not a guaranteed power hierarchy. Common effects may enable powerful combinations.
- Broad pattern: Common = simple conditional/stat interaction; Rare = neighbor/position effects; Epic = triggers/momentum/multi-rep interactions; Legendary = transformative rules.
- Shop rarity odds **60/25/12/3** were only tentative and **are not finalized**. Pricing and balance remain open.
- Each augment must explicitly specify duration/expiry: continuous, next call, timed, until condition, end-of-day, limited activations, etc. Temporary buffs expire as declared and ordinarily reset at day end; the installed augment persists.
- Downsides are intentional and may be financial (upkeep, cash costs), personal, positional, conditional, or escalating. Ideally some drawbacks can become useful in another build.

## 5. Installation, inventories, and rewards — CONFIRMED

- One augment slot initially per employee; an **individual surgery unlocks a second slot**. Surgery pricing is not finalized.
- Installed augments are **permanent**: they cannot be unequipped, recovered, or transferred.
- During planning, an augment may **replace** an installed augment for **no extra replacement/surgery fee**; the old installed augment is **destroyed**, and the new augment is consumed. Confirm destructive replacements in UI.
- Duplicates are allowed on the same employee (subject to available slots) and across employees. Separate installed copies are separate effect/trigger instances. Explicit rule-setting effects may not stack meaningfully; specify behavior per augment.
- Firing an employee destroys their installed augments. Inactive employees retain installed augments and incur upkeep.
- Augments can be acquired from shops, **every completed workday's reward**, and special events.
- Default daily reward: **choose 1 of 3 distinct random augments, or skip**. Number offered and number selectable should be separate tunable parameters for future artifact effects. No duplicate within a single offer set; the same augment can recur on later days.
- Generate reward choices once and preserve them when navigating to management; unchosen options disappear after resolution.
- A selected reward can go into the shared **12-slot item inventory**, or be **installed directly onto any active or inactive employee**, bypassing inventory, including replacement with confirmation.
- If inventory is full, leave the reward **pending**. Allow access to full team management to install/discard inventory items or direct-install the pending reward; return to the unchanged offer set. Do not start the next day until claim/install/skip resolves the reward. Skipping forfeits it; consider confirmation for valuable choices.
- Target UI layout **1280×720**, avoiding gratuitous vertical scrolling; preserve floor, employee inventory, item inventory, employee detail/augment slots, and pending reward access as feasible.

## 6. Stat resolution — CONFIRMED

- Base stats plus modifiers produce **effective stats**. Flat modifiers stack additively; percentage modifiers **on the same stat** stack additively, not multiplicatively.
- Cross-stat dependencies use **modified/effective values**, not just base values. E.g., Conversion-derived Upsell Chance should respond to changes in Conversion.
- Circular stat dependencies use a **shared pre-cycle snapshot**: each effect in a cycle reads that snapshot and applies once; unrelated downstream effects may read the resulting values. Equip/order of processing must not change the outcome.
- Stats may exceed normal caps internally; clamp actual probability rolls to **0–100%**. Other ordinary stats floor at **0**, including Speed and upkeep. Preserve fractional precision internally and round only in the UI.
- Stealing transfers a value, never duplicates it; a source cannot be reduced below zero. “Steal 30% Conversion” means 30% of current effective Conversion, whereas “steal 30 Conversion points” is absolute.
- Competing thieves draw from a shared snapshot; if demands exceed supply, distribute available stat **proportionally** to requested amounts. Copy effects do not reduce the source.
- Orthogonal adjacency only by default. Empty cells do not count as coworkers. Explicit diagonal/row/column effects are possible. Recompute positional effects when positions/stats change.
- Recalculate effective upkeep with the same dependency machinery; protect against cycles involving upkeep and Company Cash using the event/snapshot principles below.

## 7. Workday simulation, progress, and cascades — CONFIRMED

- Calls use a **0–100% progress** meter. Continuous progress rate responds immediately to effective Speed changes: `delta_progress_fraction = Speed / 18 * delta_seconds` (normalized 0–1).
- Speed 0 stops natural progress, but **direct progress boosts** can still advance or complete the call.
- Augments may add/subtract progress. Clamp progress to [0,100%]; sum simultaneous progress deltas **before** clamping. Once call completion is committed it cannot be reopened.
- Conversion, Upsell Chance, and Upsell Multiplier are evaluated using **current effective values when the call completes**. Clamp chance rolls to 0–100%.
- Simultaneous events resolve in deterministic batches: advance to timestamp, snapshot completing calls, resolve outcomes, apply resulting augment effects, recalculate, and continue.
- Full trigger cascades are allowed; triggered events can trigger other augments and complete other calls. **No arbitrary chain-depth cap.** Each **installed augment instance** can activate **once per originating event chain** to prevent infinite cycles.
- Distinct qualifying events are processed separately even at the same timestamp. Distinct originating chains may each activate the same augment instance once. A single activation affecting multiple reps still counts as one activation.
- Stat recalculation is **not itself** a gameplay trigger event unless an augment explicitly declares a threshold/transition trigger. Persistent/continuous effects remain after an activation where specified.

## 8. Financially reactive augments — CONFIRMED

- Augments may **read current Company Cash continuously** as a condition or input, and their effective stat/upkeep effects update when cash changes.
- Augments may also use **current effective upkeep** as an input to other effects. Thus financial state, positioning, and employee stats can interact dynamically.
- **Safeguard:** A passive/continuous financial condition may **read** cash but may not automatically debit or mint cash on each stat recalculation. Any augment that **spends or generates cash** must have an **explicit gameplay event trigger** (sale, upsell, failed conversion, call start, workday start/end, etc.) and participate in the existing event-chain once-per-instance guard.
- Treat threshold crossing as a recalculation condition, not an endlessly firing payment event. If a specific augment explicitly triggers on crossing a threshold, define transition semantics, timestamp ordering, and chain handling.
- Cash mutations settle immediately and trigger recalculation of cash-dependent continuous effects. Avoid recursive recalculation/payment loops.

## 9. Illustrative augments — DESIGN EXAMPLES, NOT REQUIRED FINAL CONTENT

These are examples to validate the engine's expressiveness; values, names, rarities, and balance are placeholders. Implement a small representative vertical slice if needed, but do not assume all belong in the shipped roster.

| Name | Illustrative behavior | Why it matters |
| --- | --- | --- |
| Conversion Leech | Add effective Conversion to Upsell Chance | Dynamic cross-stat dependency |
| Neural Parasite | Steal 25% current Speed from orthogonally adjacent reps | Transfer and shared-source contention |
| Neural Relay | On conversion, adjacent active calls gain +20 progress points | Trigger cascades |
| Ghost Operator | On adjacent conversion, gain +25 progress points on own active call | Cascading completions, even at zero Speed |
| Dead Weight | Set Speed to 0, gain +50 Conversion points | Drawback turned into synergy |
| Executive Lifestyle | Double Upsell Multiplier and daily upkeep | Simple financial drawback |
| Illegal Firmware | +40 Conversion; each failed conversion costs $25 cash | Event-based cash penalty, floor at zero |
| Commission Junkie | Upsell yields extra cash; completed call without upsell costs cash | Distinguish cash grant from revenue credit |
| Payroll Parasite | Reduce own upkeep 50%; increase adjacent employees' upkeep 25% | Positional financial dependency |
| Performance Bonus | Each conversion adds $10 upkeep and +5 Upsell Chance until day end | Event-based temporary stacking |
| Corporate Dependency | Gain +1 Speed per $100 current effective upkeep | Upkeep-to-Speed dependency |
| Desperation Protocol | +30 Conversion while Company Cash is below $500 | Cash threshold, dynamic recalculation |
| Golden Age | +1 Speed per $1,000 Company Cash | Cash-dependent stat scaling |
| Panic Selling | Below $250 cash, double Speed and halve Upsell Multiplier | Conditional drawback |
| Golden Parachute | Below $500 cash, upkeep $0; otherwise upkeep triples and Conversion +50 | Financial threshold affecting payroll |
| Liquidation Engine | On conversion, spend up to $100 cash to boost adjacent call progress | Explicit event-triggered cash spend; actual spend determines effect |

**Example precision:** For Liquidation Engine, if actual spend is $40, scale the benefit from **$40**, not the $100 requested. For Illegal Firmware, if cash is $10 and the penalty is $25, deduct only $10 and create no debt. For a threshold augment, a sale that crosses the threshold should change the effective stats for **subsequent** resolution steps, with deterministic simultaneous-event snapshot semantics.

## 10. Implementation architecture guidance

Prefer existing project conventions, but keep these responsibilities distinct:

1. **Employee model:** base stats/upkeep, effective stat query, installed augment instances, slot unlock state, active/inactive location.
2. **Augment definitions:** stable ID, rarity, description, trigger types, conditions, targets, effect operations, stacking behavior, duration/expiry, and financial ledger affected.
3. **Stat/dependency resolver:** additive/percentage modifiers, position-based relationships, transfer arbitration, cross-stat graph/cycle snapshots, precision/clamps.
4. **Simulation event engine:** timestamps, originating event chain IDs, per-chain augment-instance activation set, deterministic batching, explicit gameplay triggers.
5. **Call engine:** continuous progress, progress manipulation, completion snapshots, conversion/upsell outcomes, lead/discard integration.
6. **Economy ledger:** independent `daily_sales_revenue`, `company_cash`, `unpaid_upkeep`; atomic sale settlement, capped cash penalties, transaction log.
7. **Payroll service:** effective upkeep and payment settlement, carryover, write-up integration, configurable final-upkeep sampling policy pending decision.
8. **Inventory/rewards/UI:** persistent offer state, direct install, destructive replacement, item storage limits, inactive staff upkeep, visible ledger separation.

Do not make a passive stat query mutate Company Cash. All cash changes should go through explicit, auditable economy operations.

## 11. Required verification scenarios

- With a $1,000 daily goal and $1,300 in cumulative sales, sales revenue is $1,300 and the day-end sales-derived Company Cash credit is $300. Existing Company Cash does not change the goal. A $50 cash augment grant adds only to cash; a $25 penalty subtracts only from cash. End-of-day board animation causes **no second credit**.
- Company Cash $20 + $50 direct augment penalty => cash $0, no new debt. Separately, insufficient payroll creates carryover unpaid upkeep.
- Cash crossing $500 activates/deactivates Desperation Protocol without a new call or equipment change; already-running call progress responds to any Speed changes without resetting.
- Employee in inventory is charged applicable upkeep; firing employee removes its augments and future upkeep.
- Two neighboring thieves compete for one stat source; proportional allocation and nonnegative source are preserved independent of processing order.
- Cyclic effective-stat dependencies resolve deterministically using a common snapshot.
- Multiple same-time progress changes sum before clamp; a completed call cannot reopen; a cascade can complete another call, and an augment instance fires once per originating chain.
- Two installed copies of an augment can trigger independently; same-instance loop does not repeat indefinitely.
- Reward with full inventory remains pending across navigation; direct-install resolves it; replaced augment is destroyed; skip forfeits options.
- Missed sales target and unpaid payroll on the same day produce **one** write-up, not two.
- Dynamic upkeep is visible before settlement and final amount uses the **explicitly selected** payroll sampling policy, not an undocumented assumption.

## 12. Open decisions / do not silently finalize

- **Daily upkeep assessment policy:** end-of-day snapshot versus time-weighted average (end-of-day snapshot recommended, not confirmed).
- Exact payroll ordering and allocation of cash to old vs new unpaid upkeep if not already defined in code.
- Specific augment prices, rarity probabilities, thresholds, sale/upsell balancing, and exact final augment catalog.
- Exact monetary precision/rounding policy (prefer integer smallest currency units or another deterministic money representation, but confirm repository conventions).
- Any new cash-dependent effect that explicitly changes *credited sales revenue* independently of sale proceeds must define that behavior per augment.

## Definition of done

The game maintains distinct daily revenue and persistent cash; sales immediately credit both; cash penalties stop at zero; unpaid payroll carries over; dynamically reactive augments can read cash and upkeep without passive financial loops; event-triggered financial effects are safe and auditable; installation/reward rules work; and deterministic tests cover the listed cases. Update `decisions.md` with confirmed decisions and link to this spec, then summarize any open decisions to the designer.
