# Augment System

## Current behavior

Augments belong to individual employees, whether seated or in reserve. The first augment slot is available by default; surgery unlocks the existing second slot for $300. Installed augments are permanent: they cannot be unequipped or transferred. During Prepare, a player may replace one after explicit confirmation; the old instance is destroyed and replacement has no extra fee. Firing an employee permanently removes their installed augments. Uninstalled items remain in the shared 2×6 inventory.

The Store has seven slots: four standard augment offers, one premium augment offer, and two salesperson candidates. Standard and premium augment purchases use the shared Company Cash budget and enter the shared item inventory; they are not auto-equipped. Salesperson hires enter reserve and cannot exceed its capacity. Each available offer can be purchased once. A fixed-cost reroll replaces the complete stock; opening another Prepare view does not regenerate it. Store stock initializes once per day and its state is serializable alongside run state.

After each completed workday, the player receives three distinct augment choices and may claim one into inventory, directly install or replace it on an owned employee, or skip all. Inventory capacity does not block direct installation or skipping. A pending reward and selected option remain unchanged while the player opens Team Management to equip, replace, or discard items. The next workday cannot start until the reward is resolved.

## Stat and simulation rules

- Installed copies have unique instance IDs separate from their stable definition IDs. Duplicates are allowed in inventory, on the same employee, and across employees.
- Speed and Upsell Multiplier retain fractional values. Speed bonuses expressed as percentages add before applying to the baseline. Conversion bonuses add percentage points. UI formatting rounds values; simulation does not.
- Modified Conversion and Upsell Chance can exceed 100. Only the actual probability roll is clamped to 0–100%.
- Stat dependencies resolve from modified values. Cycles use a shared pre-cycle snapshot and are applied once; downstream dependencies read the resolved cycle values. The effect engine records a development trace.
- Stat theft transfers only actual losses. Simultaneous requests against one source are allocated proportionally from the shared snapshot. Orthogonal adjacency is shared through `GridSelector`; diagonals are excluded unless explicitly selected.
- Active calls store normalized progress. Natural progress is `Speed / 18` per second; a Speed change affects the remaining progress without resetting it. Speed zero pauses natural progress but direct effects can still change and complete calls.
- Call-progress changes in one event wave aggregate before clamping. Completed calls are committed and cannot reopen. Conversion and Upsell Chance are evaluated at completion; Upsell Multiplier is read only after a successful upsell roll.
- Gameplay events process deterministic batches and may cascade without an arbitrary depth limit. Each installed augment instance activates at most once per originating chain. Independent same-time root events keep separate chain IDs.
- Temporary effects explicitly specify their duration. Implemented duration forms include timed, next-call, and workday-scoped effects; independently stacked timed buffs expire independently. All temporary effects clear on daily simulation reset.
- Daily Upkeep is an effective stat with a zero floor. Augments can modify, derive from, or transfer upkeep; reserve employees still owe their effective amount.
- Continuous effects can read current Company Cash through conditions or cash-scaled stats. Resolving stats never mutates cash; cash grants, penalties, and cash-funded progress require explicit event triggers and use the per-instance/per-chain activation guard.
- Each sale immediately credits Daily Sales Revenue. At day-end settlement, Company Cash receives only cumulative daily sales above the day's goal; that surplus is not available during Play, while existing Company Cash remains available to cash-based augments. Existing cash is not counted toward the goal. Non-sale cash effects affect only Company Cash; cash penalties are capped at available funds. The end-of-day board replays sale records without settling them again.

## Prototype definitions

The six original shop entries (`AUG_001`–`AUG_006`) retain their existing prototype prices. `AUG_003` uses the spec's `Rare` rarity name. `AUG_012`–`AUG_020` are enabled in the Store at a provisional $100 each; their effects remain prototype fixtures for event triggers, temporary effects, cash-reactive stats, upkeep, and financial events. Other effect definitions in [augment_catalog.tres](../data/augment_catalog.tres) remain excluded from the Store as fixtures. These prices are scaffolding, not approved launch balance or a finalized content catalog.

Rarity weights and reroll cost are data-configurable in `AugmentCatalog`. The current standard/premium weights and $100 reroll cost are tuning placeholders, not approved balance. Current augment catalog prices and the $100 salesperson hire price are also prototype values pending balance. If a weighted rarity has no eligible definitions, generation redistributes its weight across rarities with eligible stock; an augment slot is marked sold out only when no eligible definition remains. The Store's employee offers are selected uniformly without replacement, excluding owned or fired employees; employee rarity/class weights are not applied. The production catalog and multi-pick reward balancing remain unresolved. Daily reward defaults are three offers and one pick.

## Architecture

- [augment_catalog.gd](../scripts/augment_catalog.gd) stores definition and rarity data; [augment_effect_engine.gd](../scripts/augment_effect_engine.gd) resolves stats, dependencies, theft, and trigger operations.
- [grid_selector.gd](../scripts/grid_selector.gd) provides shared floor selectors.
- [call_queue_simulation.gd](../scripts/call_queue_simulation.gd) owns normalized call progress, deterministic event waves, chain activation, temporary effects, and debug event records. [financial_ledger.gd](../scripts/financial_ledger.gd) records immediate sale settlement and explicit cash effects separately from the workday score.
- [inventory_manager.gd](../scripts/inventory_manager.gd) owns unique item instances and permanent employee equipment. [augment_manager.gd](../scripts/augment_manager.gd) handles shop transactions, surgery, reward generation, and pending-reward state.
- [store_panel.gd](../scripts/store_panel.gd) presents augment and employee offers, rerolls, and navigation to the workday. [augment_manager.gd](../scripts/augment_manager.gd) owns daily stock, purchase and hire transactions, and persistence. [planning_panel.gd](../scripts/planning_panel.gd) exposes install, confirmed replacement, discard, and team management. [report_panel.gd](../scripts/report_panel.gd) presents daily reward actions and prevents progression while unresolved.

## Explicitly unresolved

When multiple independent chains jointly complete one call, the current deterministic engineering policy attributes the resulting call event to the sorted union of contributing chain IDs. Its downstream listeners may therefore activate once per contributing root chain. This is implemented transparently but remains flagged for design confirmation. Payroll uses a clearly marked end-of-day effective-upkeep snapshot as a prototype policy; snapshot versus time-weighted sampling is unresolved. Exact currency precision beyond existing integer-dollar conventions, the production augment catalog, rarity weights/prices, special-event schedule, and second-slot surgery cost remain open rather than being inferred from fixtures.

## Validation

The focused [test_augment_implementation.gd](../tests/test_augment_implementation.gd) covers fractional and derived stats, cycles, proportional theft, adjacency, speed changes, direct progress, cascades, cash-reactive stats, upkeep transfers, event cash penalties/grants, spend-scaled progress, and reward/install paths. [test_financial_gameplay.gd](../tests/test_financial_gameplay.gd) covers dual-ledger settlement, payroll carryover, and financial integration; existing [test_augments.gd](../tests/test_augments.gd) and [test_inventory.gd](../tests/test_inventory.gd) cover compatibility and ownership.
