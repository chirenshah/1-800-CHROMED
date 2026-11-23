# Vision audit — working discussion

**Status:** Proposals and questions, not final decisions, except the starting rep choice below. Update `decisions.md` only after a choice is settled. This audit compares the November 8 direction with the playable build and existing design notes.

**Settled in discussion and now implemented:** The game opens on a main menu with New Quarter, Resume, and Settings. New Quarter plays the existing roughly 75-second cinematic, then introduces the first day on the floor with Nina already seated. A short explanation precedes the player's start of day one. The game autosaves after every completed workday, and Resume loads the latest autosaved quarter. See `decisions.md` for the confirmed direction.

## Vision being tested

The player manages a sales floor at a cyberpunk corporation over a 60-workday quarter. Each shift lasts 12 in-game hours. Daily targets create pressure; three missed targets may lead to a corporate “retirement” that means death and replacement. The opening should teach a small number of visible measures before adding complexity. The main build choices are workstations, sales representatives, and modifications at either employee or department scope. Modifications should create advantages and costs that combine in interesting ways.

## Current build and delta

| Topic | Current state | Decision to make |
| --- | --- | --- |
| Quarter and shift | A 60-day quarter is the intended horizon; the shift is 12 in-game hours. Quarter-end success and full persistence are not implemented. | Define a quarter objective after the opening loop works. |
| Failure | Missing the daily sales target **or** current payroll issues at most one write-up that day. Three cumulative write-ups terminate the run. | Decide whether to retain the payroll condition, rename write-ups as strikes, and reveal literal retirement to the player. |
| Opening economy | Nina is owned in seat 1, $500 cash is available, a hire costs $100, and priced shop augments cost $100–$450. These are prototype values. | Set cash and opening offers together, then playtest whether the first choice is meaningful and payroll remains survivable. |
| Workstations | All nine positions exist from the start. Empty seats and seat order matter, but positions cannot be bought or unlocked. | Decide whether “slots” are purchasable capacity, a fixed positioning resource, or both. |
| Representatives | Nineteen named candidates exist; one is owned at start. Speed, Conversion, Upsell Chance, Upsell Multiplier, Stamina, upkeep, and Recycler behavior can all appear early. | Choose the first visible metrics and delay the rest of the explanation until each matters. |
| Employee augments | One slot per employee is initially available; $300 surgery unlocks a second. Each item copy installs once and stays on that employee. It cannot be moved; replacement destroys the old copy. Duplicate definitions can stack. | Confirm whether “only applied once” means each physical item is single-use, or each augment **type** may appear only once per rep. |
| Department effects | An earlier implementation spec names floor-wide effects **Artifacts**, but they have no implemented inventory, slot, or rules. Employee augments can affect coworkers without being department items. | Choose a player-facing name and define scope, capacity, costs, and timing. |
| Tradeoffs | The effect engine supports sacrifices and synergies, while the six priced store augments are simple positive stat bonuses. More complex entries are test fixtures, not a finished catalog. | Author a small launch set with readable benefits, downsides, and combinations. |
| Teaching | The design log already calls for starting with standard systems and unlocking complexity by revenue milestones. The current interface exposes a much broader system immediately. | Define an opening sequence, what stays visible, and when new concepts arrive. |
| Story | The world bible intentionally leaves the predecessor's fate and the meaning of “terminated” unexplained. | Decide whether confirmed murder is known up front, gradually revealed, or only established behind the scenes. |

## Recommendation for the first playable arc

1. Begin with Nina working. A rep-versus-augment choice can later teach capacity versus specialization.
2. Teach only **daily target**, **cash**, **reps working**, and **calls converted** on day one. Show shift time and strikes, but explain upsell, stamina, upkeep, Recycler recovery, and adjacency when a decision or outcome introduces them. Keep payroll visible before the player can fail it.
3. Use **Rep Augments** for permanent employee hardware. Consider **Floor Directives** for department-level rules; the older term is **Artifacts**. A directive should have a department-wide benefit, an explicit cost or restriction, and limited active capacity so it creates a build choice.
4. Design early augments as choices with two legible consequences: for example, faster calls but higher upkeep, or higher conversion for one rep but reduced speed for adjacent reps. Ensure the downside is visible in Prepare and traceable in Report.
5. Keep the 12-hour fiction but do not equate more real-time waiting with difficulty. Use the short simulated shift to show the consequences of a build, then let the player revise it.

## Questions to settle next

1. Are workstations unlocked over time, or are the nine fixed seats the strategic grid from day one?
2. Is the failure rule three **missed targets**, or three **write-ups from target and/or payroll**?
3. Should the player know immediately that “retirement” means death?
4. Is each augment copy single-use, or is each augment type limited to once per rep?
5. Should department modifiers be called **Artifacts**, **Floor Directives**, or something else?

## First-run UX audit — November 8

At the time of the audit, the 75-second cinematic (including a 58-second text crawl) opened Prepare on the seven-offer Chrome Market rather than the floor with Nina. That exposed four standard augments, a premium augment, two hires, reroll, cash, rarity, and Start Workday before the player saw a call. The first-day flow now opens on Nina's floor instead; later Prepare screens still carry the fuller management interface and merit further UX review.

The earlier suggestion to shorten or defer the cinematic is superseded. The first two items below are implemented; the later presentation ideas remain proposals:

1. Open on the floor with Nina already seated after New Quarter and the cinematic. A three-step guide now explains automatic calls, today's target, and the shift before **Start First Shift**. It also states the current write-up rule.
2. Let the first shift run with Nina before opening the Store. Sampled Nina-only shifts indicate the current first-day target is reachable, but human playtesting is still needed.
3. Make the first report answer three questions: Did we hit the target? What did Nina do? What is the most useful next decision? Reveal hire versus augment with one example of each and a short explanation of permanent installation.
4. Add the wider store, rerolls, reserve, surgery, upsells, Recycler, and advanced modifiers after the player has a reason to use each. This is a presentation sequence proposal, not a rule to disable or remove existing simulation systems.

**Implemented flow:** Main Menu → New Quarter → cinematic → guided Nina floor → first shift → first report → autosave after the completed day. Resume loads the latest autosave and skips the new-quarter cinematic. The completed report and pending reward are saved together; Resume returns to the unresolved report. Starting a new quarter warns before the existing save is replaced at the end of the first shift. Settings currently controls session music; a broader Settings scope and save-slot model remain open. Main Menu is available from the workday, with a warning before leaving a live shift.

**Validation needed:** A headless layout check covers the guide and Main Menu button at 960×540. Rendered visual review and new-player observation are still needed to judge legibility and comprehension.

Source of current state: [`decisions.md`](../decisions.md), [`WORLD.md`](WORLD.md), [`augments.md`](augments.md), [`augment_implementation_spec.md`](augment_implementation_spec.md), [`augment_catalog.tres`](../data/augment_catalog.tres), and [`augment_manager.gd`](../scripts/augment_manager.gd).
