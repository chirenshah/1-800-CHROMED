# 1-800-CHROMED — Augment System Implementation Specification

**Audience:** Claude / implementation agent working in the existing Godot/GDScript project  
**Status:** Agreed design rules plus explicitly marked implementation guidance  
**Scope:** Employee augments, stat resolution, live calls, event cascades, rarity, inventory, installation, and reward UX. **Not** the floor-wide Artifact implementation.

> **Implementation instruction:** Inspect the current project, scenes, models, and existing markdown before modifying code. Extend existing architecture rather than creating parallel systems. Preserve existing mechanics unless explicitly superseded below. Update `decisions.md` and relevant character/inventory/gameplay documentation with these decisions. Do not treat illustrative augments, UI mockups, probabilities, or prices as final balance data.

## 1. Core design goals

- Augments **change rules and interactions**, rather than primarily supplying generic +stat upgrades. Support position-dependent effects, coworkers, call progress, lead/discard interactions, momentum, and event-driven effects.
- Build discovery should feel surprising and emergent rather than like a transparent optimization spreadsheet.
- The workday remains an **autobattler**. Players configure employees and augments during planning; sales calls and cascades resolve autonomously during the workday.
- Employee augments are distinct from **Artifacts**, which affect the entire sales floor and may later modify rewards or other rules.

## 2. Existing game integration

- Active floor: **3×3 grid**, fixed lead assignment slot priority **1–9**, skipping busy reps; positioning matters to augment effects.
- Inactive salesperson inventory: **1×6**; active employees and inactive employees are both eligible for augment installation during planning.
- Shared item inventory: **2×6 = 12 slots** for uninstalled augments and other items. Installed augments occupy employee augment slots, not item inventory slots.
- Employees normally have **one augment slot**; a second slot can be unlocked individually by surgery. Do not invent the surgery cost here.
- Workday: planning/prepare → autonomous day → review/reward. The day is currently intended to run about 15–30 seconds, subject to tuning.
- Salesperson stats include **Speed, Conversion, Upsell Chance, Upsell Multiplier**, and **daily upkeep**. Upkeep is an economic property, not necessarily a modifiable combat stat; don't assume augments modify it unless an effect explicitly says so.
- Speed prototype baseline: a full call takes `18 / Speed` seconds for `Speed > 0`.
- Leads not converted go to the day's discard pile; Recycler works only discard leads. Preserve existing Recycler/discard rules.
- Installed augments **stay with their employee**; if that employee is fired, their augments leave the run with them.

## 3. Augment data model

Each augment definition should support:

- Stable definition ID, display name, description, rarity (`Common`, `Rare`, `Epic`, `Legendary`), and effect definitions.
- Effect type and target selectors (self, adjacent, direction, row, column, etc.).
- Trigger conditions, if any, and duration/expiry rules for each effect.
- Stacking semantics, source identity, and any explicit non-stacking rule.
- Optional parameters for tuning (values, percentages, durations, thresholds).

Each **installed augment copy** must have a unique **instance ID**, separate from its definition ID. This is essential for duplicate stacking and once-per-chain activation tracking.

Keep definitions data-driven where feasible, rather than hard-coding one script per augment. Start with a small representative set and an extensible effect/trigger registry; don't implement every example in this document as a finalized content catalog.

## 4. Stat system and dependencies

### 4.1 Numeric rules

- All gameplay stats, including Speed and Upsell Multiplier, support **fractional values** internally.
- Preserve calculation precision; **round only for UI**.
- Ordinary stats have a minimum of **zero**.
- Modified stats can exceed nominal maximums **internally**, including Conversion and Upsell Chance; dependent augment effects read these **uncapped** modified values.
- Clamp **actual Conversion and Upsell probability rolls** to **0–100%** at resolution time.
- Flat bonuses stack additively. Multiple percentage modifiers of the **same stat** stack additively, not multiplicatively. Different-stat effects can chain dynamically.
- No automatic diminishing returns.

### 4.2 Dynamic derived stats

- An augment may read another augment's **modified** stat value, not only its base value.
- Recompute derived stats when relevant state changes: employee position, occupancy, current call state, temporary buff/expiry, relevant event, or upstream stat.
- Equip order, hire order, and arbitrary iteration order must not change results.
- For **circular dependencies**, resolve effects in the cycle against a **shared pre-cycle snapshot**, applying each once. Downstream non-circular dependencies can then read the resulting values. Do not iterate feedback loops to convergence or let them amplify indefinitely.
- Implement dependency evaluation explicitly enough to detect cycles and give deterministic results; expose debug traces for development.

### 4.3 Steal versus copy

- `Steal 30% of Conversion` means 30% of the victim's available Conversion amount; `steal 30 Conversion points` means a fixed 30 percentage-point request. Keep units explicit.
- Theft **transfers**, never duplicates: thief receives only what the victim actually loses; victim never drops below zero.
- If multiple thieves simultaneously request more than is available, distribute the available amount **proportionally to requested amounts**, based on the same snapshot. Do not use first-come-first-served allocation.
- `Copy` is distinct: source loses nothing.
- Simultaneous transfers must be order-independent. Handle zero availability and fractional values safely.

## 5. Position and adjacency

- `Adjacent` means **orthogonal only**: up, down, left, right; **not diagonal**.
- Effects may explicitly target diagonals, left/right/above/below, rows, columns, or other selectors.
- Empty cells provide no employee-based stat bonus unless the effect explicitly says otherwise.
- Position-based effects update when a rep moves or relevant state/stats change.
- Grid coordinates and selectors should use a single shared utility to avoid inconsistent interpretations.

## 6. Temporary effects and durations

- **Every augment effect explicitly defines its duration** for now (continuous, next call, timed, until condition, until end of workday, limited uses, etc.). Do not impose a global duration default.
- Temporary effects participate fully in dynamic stat calculation. Expiration immediately recalculates dependents, including effects on active calls.
- Repeated temporary stacks must define whether each expires independently or together.
- Temporary effects reset at the end of the workday unless explicitly defined otherwise. Installed augments themselves remain across days.
- Once an augment fires in a chain, an ongoing buff it created can remain active after that augment has reached its per-chain trigger limit.

## 7. Dynamic active calls

- Model an active call as progress in the **0–100%** range (or normalized 0–1 internally).
- Natural progress rate at current Speed is `Speed / 18` of a call per second (for normalized progress). A mid-call Speed change **immediately** changes subsequent progress rate; it does **not** reset progress.
- `Speed == 0` stops natural progress but **direct progress effects can still complete** the call.
- Augments can **directly add or subtract progress**, including setbacks. Direct progress changes do not themselves change Speed.
- Sum simultaneous progress adjustments to a call **before clamping** to [0, 100]. Example: 90% + 20 percentage points − 30 percentage points = 80%, not a completed call.
- An idle employee has no active call to modify; progress effects on idle reps do nothing unless the effect explicitly defines a different behavior.
- Once call completion has been **committed**, subsequent setbacks cannot reopen it.
- Evaluate Conversion and Upsell Chance at **call completion**, using current modified stats; evaluate Upsell Multiplier when an upsell succeeds. Clamp probability only at the roll.
- Progress reaching 100% through an augment can complete a call and produce conversion/upsell events that continue a cascade.
- Keep time progression deterministic and frame-rate independent; use simulation time rather than relying on visual frame ordering.

## 8. Event and cascade engine

### 8.1 Confirmed semantics

- **Every qualifying event triggers independently**, including two conversions at the same timestamp.
- Triggered augments may cause further gameplay events, which may trigger other augments: **full cascades**, no arbitrary chain-depth cap.
- Each **installed augment instance** may activate **at most once per originating chain**. The same augment definition installed on multiple employees counts as multiple instances.
- An augment may activate again for a **different originating chain**, even at the same timestamp.
- An augment affecting four targets is **one activation**, not four.
- Normal stat recalculation does **not automatically emit a gameplay trigger**. An explicitly designed stat-change event is a separate future capability.
- Process simultaneous events and effects in **deterministic batches**; same-timestamp calls resolve using a shared pre-outcome stat snapshot. Outcome-triggered effects apply afterward.
- Independent root events at the same timestamp retain **distinct chain IDs**. Example: two adjacent reps convert simultaneously; a listening augment may activate once in each root chain, producing two buffs.

### 8.2 Suggested implementation algorithm (engineering guidance)

1. Advance simulation to next meaningful time/event boundary; integrate natural call progress using the stats valid over that interval.
2. Collect calls completing at that timestamp, plus other root gameplay events.
3. Resolve simultaneous call outcomes against a consistent stats snapshot, generating distinct root events and chain IDs.
4. For each event wave, find qualifying installed augment instances; skip only those already activated in **that event's chain**.
5. Mark each activated instance in that chain **before** applying its effects. Queue effect operations rather than mutating state during listener traversal.
6. Aggregate simultaneous stat transfers and call-progress deltas, resolve them against shared snapshots, then apply atomically.
7. Recompute dependent stats; resolve newly completed calls and emit their outcome events with the **same originating chain ID** when caused by that chain's effects. Continue waves until no new events remain.
8. Keep independent chains distinct while batching same-timestamp effects deterministically. If multiple chains jointly push a call to completion, define and document a deterministic causal attribution rule before implementing that edge case; do not silently use iteration order.
9. Log chain ID, event ID, parent event, augment instance ID, target(s), and applied effect for debugging.

**Important open engineering edge case:** If two independent chains jointly complete one call, decide whether its completion is assigned to one root chain or whether it carries multiple causal roots; this affects later once-per-chain activations. Prefer a clear deterministic policy and flag it for design confirmation, rather than inventing player-facing behavior.

## 9. Duplicates and stacking

- Multiple employees may install the same augment definition.
- One employee may install **two copies of the same definition** in their two unlocked slots.
- Each copy is a distinct instance, and triggered effects from each copy can activate independently within a chain.
- **Duplicate augments can always be installed, but the effect only stacks if its underlying rule permits it.**
- Additive effects stack: two copies of `On conversion, adjacent active calls gain 20 percentage points progress` produce +40 percentage points.
- Two copies of `Add this employee's Conversion to Upsell Chance` each contribute separately (e.g., Conversion 35 yields +70 points total).
- Identical **rule-setting** effects such as `Speed is determined by grid position` do not inherently double the assigned Speed; they establish the same rule.
- Explicit non-stacking effects must declare that behavior. Avoid implicit multiplication of assignment/override rules.

## 10. Rarity and sources

### 10.1 Rarity

Four tiers: **Common, Rare, Epic, Legendary**. Rarity controls **both appearance frequency and typical mechanical complexity**; it does **not** guarantee greater raw power or a higher maximum synergy ceiling.

- **Common:** simpler rule changes and stat relationships.
- **Rare:** position, coworkers, conditional interactions.
- **Epic:** multi-employee triggers, momentum, cascading interactions.
- **Legendary:** unusually transformative rules or call behavior; descriptions can still be short.

**Not finalized:** Shop appearance rates and prices. Earlier illustrative rates of 60/25/12/3 are **not** confirmed balancing requirements. Build rarity weights as configurable data.

### 10.2 Acquisition

Augments can be offered through **(1) the shop, (2) end-of-day rewards after every completed workday, and (3) special events**.

- Standard daily reward: **three distinct augment choices**, **choose one or skip all**.
- Default offer count is **always three**, unless an Artifact or other mechanic explicitly modifies it.
- Reward **offer count** and **number of picks allowed** should be independent configurable properties for future mechanics. Default picks = one.
- Three options should be distinct **within the same reward offer** by definition ID; duplicates can appear on later days and across inventories/employees.
- Generate and persist the reward choices **once** per reward opportunity. Opening/closing Team Management must not reroll them.
- Unchosen options are forfeited when the reward is resolved; skipping forfeits the entire opportunity.
- Daily reward must be resolved by claiming, direct installing, or skipping before the next workday begins.
- Exact shop pricing, special event schedules, rarity odds, and reward-generation balancing remain to be designed.

## 11. Installation, replacement, and employee ownership

- Install augments only during **planning/management** (including Team Management opened to resolve a pending reward).
- Installing an uninstalled augment consumes it from shared item inventory and occupies an employee's unlocked augment slot.
- Installation is **permanent**: no unequip, refund, recovery, or transfer between employees.
- **Destructive replacement is allowed during planning**: select an occupied slot, install a new augment, **permanently destroy the old augment**. **No extra surgery fee** for replacement.
- Replacing does not change slot capacity. Surgery to unlock the second slot is a separate existing mechanic.
- Fired employees leave with **all installed augments**, which are not returned to inventory.
- Both floor employees and inactive roster employees are eligible targets.
- Confirm destructive replacement explicitly before committing. Cancel must leave all data unchanged.

## 12. Inventory overflow and pending reward UX

- Shared item inventory remains **12 slots** for uninstalled items and augments.
- A reward does **not** disappear because inventory is full.
- From the pending reward interface, players may:
  1. Claim chosen augment into inventory **if space exists**.
  2. **Directly install** chosen augment onto an employee's empty unlocked slot, **bypassing inventory**.
  3. **Directly replace** an installed augment with chosen reward, destroying the old augment after confirmation, **bypassing inventory**.
  4. Open **Team Management** to install existing inventory augments, replace installed augments, or discard uninstalled items to free space; then return to the **same** pending offer.
  5. **Skip all** reward choices.
- Claim-to-inventory is disabled if inventory is full, but direct installation and skip remain available.
- Freeing inventory space does **not** auto-claim the pending reward.
- A pending reward survives navigation back and forth to Team Management; the UI should retain selected option and avoid accidental rerolls.
- Require confirmation for destructive replacement and for skip-all (recommended UX safety; whether every rarity needs identical confirmation is an implementation detail).
- On resolution, clear the pending reward atomically, consume only the chosen augment (if claimed/installed), and invalidate unchosen options.
- Apply direct installation to shop purchases as well where compatible with existing purchasing flow; don't bypass purchase cost.

## 13. Team Management UI guidance

Target current **1280×720** prototype. Prefer fitting key content without vertical scrollbars or nested modal stacks. Exact visual layout is not locked; implement in existing scene architecture.

Visible or readily selectable sections:

- Active **3×3 sales floor**, selectable employees.
- Shared **2×6 item inventory** and capacity indicator.
- Inactive **1×6 employee inventory**.
- Selected employee's stats and unlocked/occupied augment slots.
- When relevant, persistent **pending reward banner** with chosen augment, action to return to offer, and direct-install affordance.

Interactions:

- Click/select employee to inspect augments.
- Drag/drop or equivalent explicit action to install inventory augment into an empty slot.
- Drop on occupied slot → replacement confirmation showing **old destroyed** and **new permanently installed**.
- Direct-install reward → choose employee (active or inactive), choose slot, preview target/effect if feasible, confirm.
- Discard an uninstalled inventory item with confirmation (if the existing inventory system already supports discard, reuse it).
- Return to reward without changing generated choices.
- Prevent modifications during autonomous workday; pending-reward management is a non-running planning context.

A preview of orthogonal affected neighbors is desirable but **not required for the first functional pass**. Do not block implementation on art assets.

## 14. Example augment definitions — test fixtures, NOT finalized content

Use these to validate engine expressiveness; names/values are examples only.

| Example | Illustrative effect | System exercised |
| --- | --- | --- |
| Conversion Leech | Add holder's current modified Conversion value to their Upsell Chance | Cross-stat dynamic dependencies; duplicates |
| Neural Parasite | Steal 25% Speed from orthogonally adjacent employees | Position, transfer, proportional contention |
| Neural Relay | When holder converts, adjacent active calls gain 20 percentage points progress | Event triggers, cascades, duplicates |
| Progress Vampire | On starting a call, take up to 10 percentage points progress from each adjacent active call and add actual total to own call | Progress setbacks, transfer semantics |
| Position Override | Set Speed according to floor position | Rule-setting duplicates, movement recalculation |
| Momentum Transmitter | Consecutive conversions add temporary Upsell Chance to adjacent employees until streak ends | Temporary duration and conditional expiry |
| Corporate Saboteur | On failed conversion, adjacent calls lose 15 points progress; holder gains temporary Speed | Negative progress, temporary buffs |

Define explicit duration and stacking metadata for any fixture implemented. Example names do not constitute an approved launch catalog.

## 15. Required validation / acceptance tests

### Stat evaluation

- Fractions are preserved internally; UI rounding does not change simulation outcomes.
- Modified Conversion above 100 can feed another effect at its full value, while actual conversion roll is clamped to 100%.
- Flat and same-stat percentage bonuses are additive; no unintended multiplication.
- Circular stat dependencies resolve from a common snapshot and produce the same output regardless of equip/evaluation order.
- Multiple thieves share a constrained source proportionally; source never falls below zero; total gains equal actual loss.
- Orthogonal adjacency excludes diagonals; empty cells don't act as employee sources.

### Live calls

- Changing Speed from 3 to 6 halfway through a call accelerates only remaining progress; no reset.
- Speed zero pauses natural progress, but a direct +progress effect can finish the call.
- Simultaneous +20/−30 progress at 90 resolves to 80, without transient completion.
- Progress clamps to [0,100]; completed calls cannot reopen.
- Conversion and upsell use completion-time stats, not call-start stats.

### Events

- One conversion triggers two installed copies of Neural Relay independently (+40 total).
- A → B → C cascading conversions work.
- A → B → A cannot activate the same installed augment instance twice **within the same root chain**.
- Two independent adjacent conversions at the same timestamp each trigger a listening augment, producing two effects.
- An augment affecting four targets counts as one activation in that chain.
- Processing order of same-timestamp outcomes does not affect results.
- Stat recomputation alone does not generate event triggers.

### Rewards and UI

- Default daily reward shows **three distinct choices**, choose one or skip all; no automatic reroll on navigation.
- Full inventory disables claim-to-inventory but **does not** block direct install, direct replacement, Team Management, or skip.
- Direct install bypasses inventory and consumes only selected reward on confirmation.
- Replacement destroys old augment permanently with **no additional fee**; cancel is lossless.
- Installed augments remain attached when employee moves floor ↔ inactive roster; firing removes employee and their augments.
- Second slot remains locked until surgery; replacement doesn't unlock it.
- Pending reward blocks starting next workday until resolved, and survives management navigation.
- Default offer count and pick count are separate config fields; modifiers can override them.

## 16. Implementation sequence

1. **Audit current code** and map existing stats, calls, events, employee/item inventories, augments, rewards, and screens. Record incompatibilities.
2. Implement data model and unique augment instance IDs; preserve existing save data or add migrations if needed.
3. Implement deterministic stat dependency/transfer resolution and duration handling.
4. Implement dynamic call progress and direct positive/negative progress effects.
5. Implement chain-aware event dispatcher and deterministic batch resolution.
6. Implement installation, destructive replacement, employee ownership, and inventory persistence.
7. Implement daily reward generation (three distinct options, one pick or skip), pending state, and direct installation.
8. Integrate Team Management navigation and full-inventory recovery.
9. Add representative test fixtures and automated tests, then manual 1280×720 UI checks.
10. Update `decisions.md` and relevant design docs. Summarize changes, tests, and any unresolved decisions.

## 17. Explicitly unresolved — do not silently invent permanent design decisions

- Shop prices, rarity weights, rarity progression, and special event frequency.
- Second augment-slot surgery cost.
- Exact UI composition/art assets and preview polish.
- Exact interaction between simultaneous **independent** chains jointly causing one call completion (causal attribution).
- Full production augment catalog and individual balance numbers.
- Whether special event rewards use the same three-choice format (only the **daily** default is confirmed).
- Whether all skip actions require confirmation (recommended, not user-confirmed).

**Delivery expectation:** Implement confirmed behaviors in the existing Godot project, with configurable placeholders for unfinalized numbers. Where an unresolved point blocks correctness, document the question instead of assuming a permanent rule. Provide a short file-by-file change summary and evidence of passing tests.
