# 1-800-CHROMED — Godot Architecture Audit

## Scope and approach

This is a read-only architecture review: no gameplay or project files were changed. The inventory covers the repository's GDScript files, with exact physical line counts for scripts over 400 lines. The audit also traces the main Workday scene, representative UI scenes, Resources, Autoload configuration, and the principal game-state and simulation relationships.

The codebase already has recognizable state, simulation, presentation, and content concepts. The recommendations below preserve those existing seams; they do not call for a folder reorganization or rewrite.

## A. Script inventory: files over 400 lines

| File | Lines | Primary responsibility | Secondary responsibilities | Major dependencies | Recommendation |
|---|---:|---|---|---|---|
| [scripts/workday.gd](../scripts/workday.gd) | 884 | Workday screen controller and phase flow | UI signal wiring, layout, staff/store/reward commands, simulation lifecycle, payroll and settlement, report presentation | `CallQueueSimulation`, `InventoryManager`/`FloorPlan`, `AugmentManager`, `FinancialLedger`, and nearly every Workday panel/scene | Keep as the scene composition root, but gradually move day lifecycle and settlement orchestration out of the Control script. Leave node binding and view refreshes at the presentation boundary. |
| [scripts/call_queue_simulation.gd](../scripts/call_queue_simulation.gd) | 722 | Clock-driven call-queue simulation | Call assignment and outcomes, workload metrics, recovery, augment event waves, temporary effects, and ledger callbacks | `EmployeeRoster`, `LeadAssignment`, `AugmentEffectEngine`, `GridSelector`; finance through `Callable` properties | Keep it free of UI nodes. If effect behavior continues to grow, extract the event-wave/effect-batch processor behind a narrow model API; do not split solely to reduce line count. |
| [scripts/sales_slam_board.gd](../scripts/sales_slam_board.gd) | 641 | Animated sales-replay presentation | Dynamic board construction, playback controls, audio coordination, visual effects, and replay tally | `SalesSlamPlan`, `SalesSlamAudio`, Godot Controls/Tweens | This is a cohesive presentation component despite its size. Keep it unchanged unless visual effects or playback become independently reused. |
| [tests/test_augment_implementation.gd](../tests/test_augment_implementation.gd) | 521 | Integration/regression coverage for augments | Stat resolution, event effects, finance, rewards, installation, and store behavior | Test-created `EmployeeRoster`, `AugmentManager`, `CallQueueSimulation`, `FinancialLedger` | Split into focused test scripts by behavior when convenient; preserve assertions and setup coverage. This is test organization, not a production architecture problem. |
| [scripts/augment_manager.gd](../scripts/augment_manager.gd) | 498 | Augment-facing game service and state | Store generation/purchases, daily rewards, hiring/equipment wrappers, stat resolution, cash bridge, serialization | `AugmentCatalog`, `EmployeeRoster`, `AugmentEffectEngine`, `InventoryManager`, `FinancialLedger` | Keep ownership mechanics in `InventoryManager`; as features grow, separate store/reward policy only at an existing functional seam. Avoid introducing extra services preemptively. |
| [scripts/augment_effect_engine.gd](../scripts/augment_effect_engine.gd) | 437 | Resolve augment stat/effect rules | Derived-stat graph, conditional effects, position transfers, triggered event operations, debug trace | `AugmentCatalog`, `EmployeeRoster`, `GridSelector` | The effect domain is coherent for now. Consider separating passive stat resolution from triggered operations only if their schemas or tests evolve independently. |
| [scripts/store_panel.gd](../scripts/store_panel.gd) | 418 | Store UI construction and state rendering | Dynamic offer cards, layout, affordability/feedback presentation, effect descriptions | `AugmentManager`, `AugmentCatalog`, scene Controls | Keep presentation-only. If offer-card layouts are reused or repeatedly changed, move a card into a reusable scene; otherwise dynamic construction is reasonable. |

## B. Architectural problems

Severity describes architectural risk, not a claim that the current gameplay is incorrect. No Critical issue was identified.

### High — Workday controller combines orchestration and multiple domains

[`Workday._ready`](../scripts/workday.gd#L67) wires a large set of panel signals, initializes state owners, configures simulation callbacks, creates dialogs, and starts layout. The same script handles staff/store/reward commands ([`_assign_employee`](../scripts/workday.gd#L165), [`_bench_employee`](../scripts/workday.gd#L172)), financial callbacks ([`_settle_sale`](../scripts/workday.gd#L262), [`_apply_augment_cash_effect`](../scripts/workday.gd#L269)), responsive layout ([`_update_layout`](../scripts/workday.gd#L593)), phase transitions ([`_show_phase`](../scripts/workday.gd#L658)), simulation timing, payroll, settlement, and report/reward progression ([`_finish_day`](../scripts/workday.gd#L787)).

This makes changes to a single feature likely to touch unrelated UI and game-flow code, increases regression surface, and leaves important game flow owned by a scene node. Keep Workday as the composition root, but move a coherent lifecycle responsibility at a time after tests capture its behavior.

### High — Static dependency cycle between inventory and augment service

[`InventoryManager`](../scripts/inventory_manager.gd#L44) uses `AugmentManager.CATALOG` to validate and create items, while [`AugmentManager`](../scripts/augment_manager.gd#L55) constructs and owns an `InventoryManager`. The inventory data model therefore depends on its higher-level coordinating service just to access content. This couples ownership rules to store/reward orchestration and makes isolated construction or later service changes more fragile.

Pass the catalog through the inventory boundary (or otherwise make the content dependency independent of `AugmentManager`) while retaining the current validation and item behavior.

### Medium — Content Resource and effect engine depend on each other

[`EmployeeRoster`](../scripts/employee_roster.gd#L12) preloads the effect engine and creates one inside [`modified_stats`](../scripts/employee_roster.gd#L90). The engine's public resolution methods accept `EmployeeRoster` ([`resolve_stats`](../scripts/augment_effect_engine.gd#L10), [`resolve_floor_stats`](../scripts/augment_effect_engine.gd#L98)). This makes a content Resource responsible for invoking simulation/rule interpretation, while the interpreter also depends on the Resource's type and API.

That inversion complicates testing and content evolution. Keep the Resource focused on authoring/profile lookup; have the existing game service or simulation caller invoke the effect engine. Make the change incrementally because the roster convenience methods are already used.

### Medium — Simulation event processing and financial integration are broad internal responsibilities

The queue model appropriately has no UI-node dependency, but [`_process_event_waves`](../scripts/call_queue_simulation.gd#L328), [`_apply_effect_batch`](../scripts/call_queue_simulation.gd#L345), temporary-effect expiry, call resolution, and queue scheduling all live in one model. It also exposes three runtime `Callable` contracts for finance/context ([callback fields](../scripts/call_queue_simulation.gd#L47), [`_financial_context`](../scripts/call_queue_simulation.gd#L534)); Workday supplies these callbacks.

This is a useful separation from the UI, but broadens the model's responsibilities and leaves callback setup/payload contracts dependent on runtime strings and dictionaries. Changes to effect processing can become risky, and a missed callback setup is discovered only at runtime. Preserve current behavior; add focused tests around the callback contract, then extract event processing only if it can have a narrow, testable interface.

### Medium — Multiple possible APIs mutate seating

Gameplay staff management goes through [`InventoryManager.deploy`](../scripts/inventory_manager.gd#L205) and `recall`, which preserve ownership and reserve-slot rules. [`FloorPlan.assign`](../scripts/floor_plan.gd#L23) and `bench` provide a second, lower-level mutation path with different assumptions. The latter is not used by the production Workday path, but it remains an alternate public API and is exercised independently in tests.

If both remain valid, their distinct responsibilities and invariants should be explicit. Otherwise, make `InventoryManager` the single gameplay mutation entry point and retain `FloorPlan` as seating state/query data. This prevents a future caller from bypassing ownership, reserve, or fired-employee rules.

### Medium — Deep scene paths make Workday hierarchy changes fragile

Workday binds controls through long paths such as `$PageMargin/Page/Workspace/MainContent/MainPanels/...` (for example [`@onready` bindings](../scripts/workday.gd#L18)) and repeats paths in [`_update_layout`](../scripts/workday.gd#L593). These are valid and direct, but a layout-only rename or reparent can break controller setup in multiple places.

Prefer local panel APIs and signals for panel-owned controls; keep root-level references only for controls the root actually coordinates. Do not replace every NodePath with a new abstraction—reduce the repeated deep paths when those scene areas are next changed.

### Medium — Content and cross-layer messages use implicit Dictionary schemas

`AugmentCatalog.augments` and `EmployeeRoster.employees` are `Array[Dictionary]` data in Resources, and the effect, simulation, and finance paths pass dictionaries with string-keyed fields. Profiles such as [`AugmentCatalog.profile`](../scripts/augment_catalog.gd#L23) return those dictionaries directly. This supports flexible content, but misspelled or missing keys and payload-shape changes are mostly detected at runtime.

Keep the current data-driven approach. Document/validate the fields at the content boundary and add checks when new effect types or payload keys are introduced; do not convert every dictionary to a custom Resource without a concrete need.

### Low — Small presentation helpers are duplicated

Number formatting exists separately in [`CallQueuePanel`](../scripts/call_queue_panel.gd#L153), [`ReportPanel`](../scripts/report_panel.gd#L286), and [`SalesSlamBoard`](../scripts/sales_slam_board.gd#L635). Augment effect descriptions are also independently rendered by [StorePanel](../scripts/store_panel.gd#L375), [PlanningPanel](../scripts/planning_panel.gd#L284), and [InventoryPanel](../scripts/inventory_panel.gd#L169).

The duplication is limited and context-specific today. If formatting or effect wording changes often, consolidate the shared presentation rule; avoid adding a utility solely to remove a few short methods.

### Positive boundaries to preserve

- `project.godot` has one Autoload, `MusicPlayer`, appropriate for music that persists across opening and gameplay; it is not being used as a general game-state container.
- `CallQueueSimulation` is a `RefCounted` model and does not reference UI nodes. Its callback boundary is imperfectly typed, but the simulation/presentation separation itself is sound.
- `FinancialLedger`, `InventoryManager`, and `FloorPlan` are separate state owners; [AugmentCatalog](../scripts/augment_catalog.gd) and [EmployeeRoster](../scripts/employee_roster.gd) are data Resources backed by `.tres` content.
- The main scene composes the Workday scene, and Workday composes focused panel scenes. `EmployeeCard` is a reusable scene; UI-to-controller actions generally use signals. These are good Godot-native patterns.
- `SalesSlamBoard` is large but mostly owns one visual replay experience. Do not split it based on size alone.

## C. Proposed architecture

Continue using the existing four conceptual layers without requiring four new folders or base classes:

| Layer | Existing responsibilities | Practical boundary |
|---|---|---|
| **Game State** | `InventoryManager` and its `FloorPlan`, `FinancialLedger`, state held by `AugmentManager`, and run/day fields currently in `Workday` | State owners expose domain operations and snapshots; UI reads state and requests actions rather than becoming an additional source of truth. |
| **Simulation** | `CallQueueSimulation`, `AugmentEffectEngine`, `LeadAssignment`, `GridSelector`, `SalesSlamPlan` | Simulation consumes content and state inputs and produces model outcomes. It stays independent of UI nodes. |
| **Presentation** | Workday scene/controller, panels, `EmployeeCard`, `SalesSlamBoard`, opening scene | Panels own their local controls and emit user intent; Workday coordinates scene composition and forwards intent to game services. |
| **Content** | `AugmentCatalog`, `EmployeeRoster`, and their `.tres` files | Resources define and look up content. Simulation interprets rules; content should not instantiate simulation engines. |

### Keep unchanged unless a concrete feature requires a change

- Keep `MusicPlayer` as the sole Autoload; do not move ordinary run state into a global singleton.
- Keep the panel scenes and `EmployeeCard` as composed presentation components, and preserve signal-based user actions.
- Keep `SalesSlamBoard` as one cohesive replay component and `SalesSlamPlan` as its deterministic plan/calculation counterpart.
- Keep `FinancialLedger` as the authority for company cash, revenue, settlements, and transactions.
- Keep the current Resources and `.tres` content format while it remains useful; improve validation at the existing content boundary before considering a broad schema migration.

### Responsibilities to extract incrementally

1. Make content access independent of `AugmentManager` so `InventoryManager` can validate augments without depending on the manager that owns it.
2. Move effect-engine invocation out of the content Resource boundary while keeping roster profile data and current stat results unchanged.
3. Keep Workday's scene composition and presentation updates, but move day lifecycle/settlement coordination out of its Control script after characterization tests exist.
4. If event-effect behavior continues to grow, isolate event-wave processing from queue scheduling while keeping the existing simulation API stable.

## D. Refactoring roadmap

Each step is incremental and should preserve current gameplay values, timing, ordering, and UI behavior. No step requires doing the next one.

| Priority / step | Files affected | Responsibilities to extract or clarify | Expected benefits | Regression risks | Behavior verification |
|---|---|---|---|---|---|
| **0. Characterize existing seams before moving code** | `tests/test_augment_implementation.gd`, `tests/test_call_queue.gd`, Workday-related tests (add focused tests only where coverage is absent) | Capture phase transitions, callback setup, day settlement, lineup mutations, and key UI flow outcomes | Makes later structural changes measurable and safer | Tests can mirror implementation instead of observable behavior | Run the focused existing suites before/after; compare simulation totals, ledger snapshots, offers/rewards, and phase transitions for the same seeded inputs. |
| **1. Remove dependency cycles and unify seating mutation** | `scripts/inventory_manager.gd`, `scripts/augment_manager.gd`, `scripts/employee_roster.gd`, `scripts/augment_effect_engine.gd`, `scripts/floor_plan.gd`, related tests | Make the catalog dependency independent of `AugmentManager`; have callers invoke effect resolution; establish `InventoryManager` as the gameplay seating mutation API | Reduces coupling and prevents ownership rules being bypassed | Constructor/default catalog differences or seat swap/recall behavior changing | Keep tests for item validation, equip/install, deployment swaps, reserve limits, stat outputs, and augment effects; compare serialized state before/after equivalent operations. |
| **2. Extract Workday day-flow coordination** | `scripts/workday.gd`, a focused coordinator only if justified, `tests/` | Move start/tick/end/next-day and settlement sequencing out of the Control script; leave node updates and signal binding in Workday | Smaller scene controller; day-flow behavior can be tested without building the full UI | Timing/order changes among timer, simulation, sales settlement, payroll, reward generation, and board playback | Use deterministic simulation tests and a Workday integration test to assert exact day totals, ledger settlement, reward state, and final phase; verify pause/end-day paths in the running scene. |
| **3. Isolate event-effect batch processing if it continues to grow** | `scripts/call_queue_simulation.gd`, possibly one focused simulation helper, `scripts/augment_effect_engine.gd`, augment/simulation tests | Separate event-wave/effect-batch application and temporary effects from queue timing and dispatch | Limits the surface area of the densest simulation logic while retaining a UI-free model | Event order, causal attribution, progress transfer, and recursive wave handling can change subtly | Replay fixed seeds and compare event logs, causal chains, employee stats, sale logs, and queue results byte-for-byte or field-for-field. |
| **4. Reduce fragile presentation coupling when scenes are next edited** | `scripts/workday.gd`, `scenes/workday.tscn`, affected panel scripts/scenes | Let panels own local control paths and layout; expose only required state/action methods or signals to Workday | Scene hierarchy changes affect fewer scripts and duplicate NodePaths | A missing signal or stale view after phase changes; layout regression | Run UI layout tests at supported viewport sizes; verify panel visibility, focus, resize behavior, and all existing actions. |
| **5. Consolidate only repeatedly changing presentation/content conventions** | `scripts/store_panel.gd`, `scripts/planning_panel.gd`, `scripts/inventory_panel.gd`, `scripts/call_queue_panel.gd`, `scripts/report_panel.gd`, content tests | Share formatting/effect-description rules only if they need to remain consistent across screens; add boundary validation as effect schemas grow | Prevents wording/format divergence and catches malformed content earlier | Shared formatting could unintentionally alter screen-specific presentation; over-generalized schema could constrain content | Add focused formatter/content validation tests and compare representative UI strings and catalog validation for all current `.tres` entries. |

## E. Lightweight architecture guidelines

1. **Use 400 lines as a review prompt, not a limit.** At that point, check whether a script has independently changing responsibilities and a real extraction seam; do not split a cohesive scene or model for size alone.
2. **Keep simulation free of scene-tree dependencies.** Pass values, Resources, and narrow collaborators into models; return model results or use explicit callbacks/signals at orchestration boundaries.
3. **Maintain one authority per kind of state.** Make ownership and seating operations go through one gameplay API; avoid storing derived copies unless there is a measured need, and keep them synchronized from one source.
4. **Keep content declarative.** Resources should define and retrieve content. Rule engines interpret it. Validate new effect fields, identifiers, and payloads at the content boundary.
5. **Treat Dictionaries as contracts.** For cross-script payloads, document required keys and types, validate at boundaries, and add tests whenever the schema changes. Prefer existing typed methods where a Dictionary is not needed.
6. **Keep scene ownership local.** A panel should own paths to its children and emit intent through signals. The root scene should coordinate panels, not reach deeply into every panel's internal layout.
7. **Use Autoloads sparingly.** Reserve them for truly application-wide services such as persistent music, not for convenient access to run or workday state.
8. **Characterize behavior before structural changes.** Preserve seeded simulation outcomes, transaction ordering, workday phase behavior, and UI interaction flows with focused tests before moving responsibilities.
9. **Extract only at demonstrated seams.** Prefer a small responsibility already grouped by methods and tests over a generic manager, framework, or new inheritance hierarchy.
