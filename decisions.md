# Game decisions

Last updated: October 18, 2026

Living design log for a cyberpunk call center management game. Confirmed direction records the intended game; Current implementation records what is playable now. Keep tuning placeholders and proposals separate from confirmed rules, and preserve the reason when changing a decision.

## Confirmed direction

- **Setting:** In 2189, the player is newly promoted Regional Sales Floor Manager Grade C-7 at 1-800-CHROMED, an independent telesales agency selling megacorp cybernetics. See [WORLD.md](docs/WORLD.md) for narrative canon. The game remains a call-center management game; this setting does not change the Prepare → Play → Report loop or introduce mechanics.
- **Team:** Employees occupy a 3×3 grid. Salespeople are part of the roster; customer success is still under consideration.
- **Management horizon:** The player manages one company for a 60-workday quarter, divided into three months of 20 workdays. Each playable workday uses its own Prepare → Play → Report loop. The prototype preserves the lineup within the session; broader quarter progression and persistence remain to be designed.
- **Management feel:** The player should feel like they are managing unpredictable humans. Positioning creates opportunity, and employee behavior determines the result. Keep assignment simple, deterministic, and explainable; let the player learn from observation and reports rather than predicted revenue bonuses. Business decisions should have believable consequences and be capable of making or breaking the company.
- **Engagement pace:** Use a pause-and-think model. During Play, Pause/Resume freezes and resumes the simulation, including arrivals, waiting patience, handling progress, and workload time. Pausing allows inspection; seating remains locked until Prepare.
- **Core workday flow:** Use a **Prepare → Play → Report** model. The implementation shares one sales floor across phases, with the planner in Prepare, the queue in Play, and results in Report. Seating is editable only in Prepare. Report becomes available when the day closes, and **Prepare Next Day** explicitly opens the next preparation phase.
- **Autonomous operation:** The sales floor must keep functioning without human intervention. Routine lead handling and employee work cannot depend on manual assignments or player approvals. The player builds and improves the system; the prototype uses fixed row-major lead priority and automatic first-available employee assignment.
- **Position-based lead assignment:** Positions are numbered 1–9 in fixed row-major order, from top-left to bottom-right. Numbers stay with the positions when employees move. The oldest waiting lead is automatically assigned to the first available employee in that order, skipping busy employees and empty positions. Employees handle one active lead at a time. If nobody is available, the lead waits FIFO until assignment or abandonment. Simultaneous vacancies use the same fixed slot priority. The player never assigns individual leads.
- **Employee behavior:** Keep routing separate from how employees handle their opportunities. Employee-specific handling speed, patience, sales behavior, relationships, and adjacency effects can be added later. This foundation uses a shared baseline; it does not introduce personalities, lead preferences, or best-match routing.
- **Reporting and reset:** Reports should explain the consequences of seating through actual assignments, completed interactions, busy/idle time, sales, and waiting-lead losses. Keep aggregate floor metrics. New days clear active work, waiting leads, and daily counters while preserving the session lineup.
- **Roster building:** “Moneyball for a call center.” Finding the correct mix of employees matters more than filling every seat with a star performer.
- **Cybernetics:** The direction includes modifying employees with cybernetic enhancements between days. Enhancements are not implemented yet.
- **Different companies:** The player can play at different companies, each inspired by fiction. The player stays at one company for the whole quarter. A paper supplier inspired by Dunder Mifflin is an initial example; the company lineup and names are undecided. CHROMED is the confirmed narrative workplace; how the multi-company gameplay direction fits its contracts remains unresolved.
- **Products affect management:** What a company sells must meaningfully change how the player manages the sales floor.
- **Incoming leads:** Leads flow in independently. The prototype uses the deterministic 2/3/1 arrival pattern and allows leads to wait FIFO with a patience deadline. Lead-source variety and advanced routing remain to be designed.
- **Lead sources:** The player can use different lead sources, each with its own characteristics. Source selection and optimization are part of managing the floor. The exact sources and their attributes are undecided.
- **Revenue milestones:** Different revenue levels introduce problems and twists that require the player to improve and adapt the team. These replace the original month-based problem introduction. A single static build should not solve the whole quarter. Threshold values and the revenue measure used are undecided.
- **Learning curve:** Start with mostly standard employees, leads, and systems. Revenue milestones progressively introduce more options and complexity, including lead-type optimization. The exact unlock sequence is undecided.
- **Avoiding stagnation:** A marginally successful company must not be able to coast on small revenue with no meaningful gameplay. The mechanism that encourages or requires improvement is still to be chosen.
- **Department budget:** Revenue has a relationship with the department's budget, which can be spent on cybernetic enhancements. The funding formula and when money becomes available are undecided.
- **Commercial goal:** Sell the game on Steam, let players wishlist it before release, and participate in Steam Next Fest. The festival edition and release dates have not been selected.
- **Music:** The user selected `assets/welcome_mix_110bpm.ogg` for the current game build. It loops from the opening through the sales floor, including workday pause, with a Music: On/Off control in both scenes. Default level is -18 dB and the toggle is session-only. The source page lists the track under CC0 1.0; see [assets/MUSIC_CREDITS.md](assets/MUSIC_CREDITS.md). This records the current asset choice, not a commitment about future musical choices.

### Confirmed narrative direction — October 18, 2026

- **History:** The setting is 2189. There is no traditional apocalypse; corporate control grew gradually through privatization, crises, outsourcing, and public-private partnerships. The defining line is: “The apocalypse never happened. It was a corporate restructuring.”
- **Government and corporate power:** Governments technically exist, while corporations control society in practice. Corporate and AI systems administer much of ordinary life; private security has replaced much policing.
- **Technology and dependency:** Technology genuinely improved people's lives, while the economic system made access dependent on continued payment. The defining line is: “The technology genuinely improved people’s lives. The economic system made everyone dependent on paying for it.”
- **Subscriptions:** Rights, healthcare, housing, and body systems can be tied to subscriptions, employment, or leases. Organs, eyes, neural services, and emotional regulation may be leased; missed payments can bring ads or degraded access, and leaving a job can threaten housing or leased organs.
- **AI's role:** AI runs administrative and management systems across executive recommendations, HR and productivity, healthcare coverage, legal and policy processes, advertising vulnerabilities, sales pitches, and governance. AI is not rebelling or conquering humanity. The defining line is: “AI didn’t overthrow humanity. Corporations put it in charge of management.”
- **Distributed responsibility:** Accountability loops through people, algorithms, and policy; there is no single villain responsible for the whole system.
- **AI consciousness:** The story never confirms or denies AI consciousness. Apparent empathy, boredom, or inner life stays ambiguous.
- **Ordinary life and tone:** Friendships, hobbies, celebrities, and ordinary routines matter within a normalized system. The tone is dark corporate satire set in a genuinely horrifying society.
- **CHROMED:** 1-800-CHROMED is an independent third-party telesales agency, primarily selling megacorp cybernetics and able to take other contracts. Its motto is “Your body. Our business.” It markets customer-first service while operating with a revenue focus.
- **Legal role:** Decades-old regulations barred manufacturers from directly selling certain medical cybernetics but exempted independent agencies. CHROMED exploits this loophole as a reputational and legal buffer, not as universally immune from liability.
- **Player and opening:** The player is newly promoted Regional Sales Floor Manager Grade C-7, inheriting nine floor positions that need not all be filled. The predecessor was terminated for poor performance; that stated reason is known, while what “terminated” means and the predecessor's fate remain unexplained. The objective is to make the numbers go up. An original dramatic cinematic crawl introduces the setting and ends with a corporate onboarding reveal.

See [WORLD.md](docs/WORLD.md) for the concise world bible and its separately labeled optional ideas.

## Current implementation — October 18, 2026

### Prepare and the sales floor

The playable flow is opening cinematic → Prepare → Play → Report. Skipping the opening enters fresh Prepare without advancing the workday. The floor has nine fixed positions:

```text
[ 1 ][ 2 ][ 3 ]
[ 4 ][ 5 ][ 6 ]
[ 7 ][ 8 ][ 9 ]
```

The five-person planning roster is Nina, Zip, Victoria, Ada, and Dex. Nina starts in position 1, Zip in 2, and Victoria in 4; Ada and Dex start on the bench. The planner shows qualitative Speed/Conversion profiles, proposed strengths, and tradeoffs. These are character previews; everyone currently shares the same simulation behavior.

During Prepare, selecting a seat allows assignment or benching. Moving a seated employee to an occupied seat swaps the two occupants; moving to an empty seat vacates the original position. Assigning from the bench replaces the destination occupant and returns that occupant to the bench. Employees cannot occupy multiple positions. The UI requires at least one seated employee to start; the queue model also handles an entirely empty floor.

Seat cards retain their fixed intake numbers, and the Prepare guide explains the row-major priority. Play, paused Play, and Report lock all seating changes. The interface shows observed activity and results without predicted revenue bonuses for positions.

### Simulation and placeholder balance

The existing workday Timer drives the single queue simulation. Current tuning is **0.75 simulation seconds per tick**, **45 ticks per workday** (33.75 seconds of unpaused operation), **four ticks per interaction** (3 seconds), and **eight ticks of waiting patience** (6 seconds). The player can also choose **End Workday**, including while paused. These durations are prototype balance values.

Each tick runs in this order:

1. Record busy or idle time for each seated employee over the elapsed interval.
2. Progress every active interaction and finish all interactions due on that tick before assigning any new work.
3. Remove every waiting lead whose waiting time has reached its patience limit, preserving FIFO order among survivors.
4. Generate the next arrivals in the existing repeating 2 / 3 / 1 pattern.
5. Dispatch waiting leads FIFO to available employees in fixed position order, marking each recipient busy immediately.

At an exact patience deadline, abandonment wins over assignment, even if an employee becomes available on that tick. Active interactions never abandon because of queue patience. Once an interaction finishes, its employee may receive another waiting lead in the same tick. Assignments and completions follow simulation state; cosmetic pulses and progress displays do not determine timing.

All employees currently use the same placeholder sale rule: completed leads whose IDs are not divisible by three produce a sale. A lead's value is `180 + 15 × lead ID`, and revenue is credited only on completion. Arrival, duration, and outcome rules use no random draws, so identical starting states reproduce identical results, including with identical seeds. These formulas are implementation placeholders, not final employee stats or product economics.

Pause freezes simulation ticks, patience, and busy/idle accounting. Music continues independently. The floor shows queued leads, the latest assignment, active call IDs/progress, completion feedback, and the number of callers who left while waiting.

### Reports and the next day

Report is available after automatic or early day close. Aggregate results include revenue, handled calls, conversion, incoming calls, waiting at close, unfinished interactions, and abandonment. Per-employee rows show assigned and handled leads, sales/revenue, and busy/idle seconds, attributed by employee ID and displayed with that day's seat. The model also retains the aggregate sale count.

Assigned leads count immediately; handled leads and sales require a completed interaction. Busy time includes time spent on interactions unfinished at close. Each seated employee's busy and idle ticks cover the elapsed workday, excluding pauses. Closing preserves waiting and unfinished leads for the report rather than counting them as completed or abandoned.

**Prepare Next Day** retains seating and returns to the planner. It clears active/waiting leads, busy states, daily metrics, and activity events. Starting Play takes a fresh copy of the prepared lineup. Persistence is session-local; there is no save-game system. The day display caps at 60, but quarter-end success, failure, and an ending are not implemented.

### Architecture, validation, and scope

- [floor_plan.gd](scripts/floor_plan.gd) owns seating, swaps, and the bench; [planning_roster.tres](data/planning_roster.tres) supplies employee previews.
- [lead_assignment.gd](scripts/lead_assignment.gd) contains the pure `next_available_seat` selection function. [call_queue_simulation.gd](scripts/call_queue_simulation.gd) owns the clock-driven queue lifecycle and employee metrics, with separate duration/outcome hooks for future behavior.
- [workday.gd](scripts/workday.gd) owns phase controls and the Timer; employee cards, queue, and report panels present simulation state.
- [test_lead_assignment.gd](tests/test_lead_assignment.gd) covers fixed priority, empty/busy floors, same-tick completions, FIFO, abandonment deadlines, attribution, resets, and deterministic accounting. Queue, planning, and opening tests cover phase locks, pause/resume, reports, next-day handoff, and supported layouts.

Hiring costs, active character abilities, differing employee stats, personalities, relationships, adjacency synergies, enhancements, lead-source selection, qualification, transfers, advanced matching, funding, and revenue-triggered twists are not implemented. Their presence in the direction or proposals below does not mean they affect the current simulation. The next behavior features should extend employee handling without requiring a routing rewrite.

## Development context

- The user is a software developer and intends to learn game-engine development while making this game.
- The user's usual programming language is Python. Prior engine experience has not been specified. The user selected Godot and requested project initialization on October 17, 2026. The project uses Godot 4.7.2 Standard, GDScript, and the Compatibility renderer. The opening, floor planner, autonomous queue, position-based assignment, and daily reporting are implemented; the broader management economy and employee behavior systems remain future work.

## Ideas to explore — not yet decisions

### Autonomous operation and player engagement

The user considered SimCity and Clash Royale as engagement references, chose pause-and-think play, and then clarified that the entire floor should work independently of human intervention. Earlier suggestions about routinely rescuing deals through manual actions are superseded by autonomous operation.

Pause/Resume and inspection during Play are implemented. Seating stays locked while paused, and individual leads are always assigned automatically. Speed controls, automatic pauses, and any additional future operating controls remain proposals. Cybernetic modifications are planned between days and are not active yet.

Confirmed workday loop:

- **Prepare:** Configure the roster and seating before the workday. Enhancements and additional operating controls belong to the future direction.
- **Play:** Run the autonomous sales floor. The player observes results and can pause to understand bottlenecks.
- **Report:** Review performance information in a report tab to understand outcomes and inform the next Prepare phase.

In the intended game, revenue affects department funding and triggers twists at milestones; neither system is implemented yet. The current report already supports reviewing assignments and workload before adjusting seating in the next Prepare phase.

For example, a future fast employee could finish sooner and become eligible for another lead, while a patient employee might spend longer with a difficult customer. Fixed slot priority would still decide the next opportunity. These are behavior possibilities, not active abilities or a commitment to a new routing policy.

Possible source of engagement: understanding why a team succeeds, identifying the next bottleneck, and choosing which investment will help. Competing commitments and incomplete information can make planning difficult even with time to think. What information is visible needs to be designed.

The shared floor, phase-specific panels, Prepare-only seating changes, pause controls, closed-day reports, and explicit next-day transition are implemented. Further report explanations, final pacing, and additional preparation systems remain open; the current behavior is detailed above.

### Growth changes what the company needs

Revenue-triggered twists are confirmed; these examples and balancing principles are suggestions:

- **Early business:** Straightforward customers favor a team that can handle routine work efficiently.
- **Larger accounts:** Higher-value opportunities introduce more complex needs, rewarding specialist knowledge and coordination.
- **Established customer base:** Repeat business and service demands compete with new sales for limited staff capacity.

Each company could express these stages differently. A paper supplier might gain larger recurring business accounts, while an implant company might gain customers needing more specialist advice and aftercare.

Suggested principle: milestones bring new earning opportunities along with new demands, giving the player a reason to grow. Twists should expose different weaknesses and encourage different solutions; their warning signs and activation timing need design.

### Lead sources and gradual learning

Multiple sources and a gentle learning curve are confirmed. These source profiles are examples, not a committed lineup:

| Possible source | Characteristics | Possible team implication |
| --- | --- | --- |
| Standard inbound | Predictable demand and straightforward needs | Generalists can handle the initial floor; useful for learning the basic loop. |
| Paid campaigns | More volume, acquisition costs, and mixed buying intent | Qualification and efficient handling can matter more than raw closing skill. |
| Referrals | Low volume, existing trust, and relationship expectations | Account knowledge and consistent service can be valuable. |
| Corporate brokers | Fewer, larger opportunities with complex requirements | Specialists and coordination can justify slower handling. |

Suggested distinction: a source controls the distribution of incoming leads; an individual lead has needs, value, and other traits. A source can produce several lead types. Choosing sources should not require manually assigning individual calls.

Possible learning sequence:

1. Start with a standard source, mostly generalist employees, and a small set of visible performance measures.
2. An early revenue milestone introduces one alternative source and explains its key tradeoff.
3. A later milestone introduces a new customer need and a relevant employee or enhancement choice.
4. Later milestones invite mixing sources and building a more specialized team.

Introduce one major concept at a time. Keep earlier sources useful in some builds. An unlock that helps the player grow must be reachable with the tools already available.

### Revenue funds improvement

Keep revenue earned and budget available to spend as distinct quantities. The confirmed relationship does not yet imply that every unit of revenue becomes upgrade money.

Possible funding model: a base allowance plus performance-based funding, with optional grants at milestones. A base allowance could leave room to recover from an underperforming build. No formula or grant system has been chosen.

Possible spending choice: save for one major enhancement or improve several employees sooner. Whether the same budget also pays for hires, salaries, or other expenses is open.

### Employees create value in different ways

An employee's value depends on the team, customers, and work assigned to them. Useful contributions could include qualifying leads, closing deals, rescuing difficult accounts, or coaching coworkers.

Examples:

- A weak closer who qualifies leads well makes stronger closers more productive.
- A veteran with low call volume helps rookies and handles difficult customers.
- A star seller brings in revenue but may cherry-pick leads, cost more, or hurt morale.

The player should be able to discover why an overlooked employee is valuable, with enough feedback to understand the result.

### Sales rep archetypes — proposed design reference

See [characters.md](docs/characters.md) for the proposed Workhorse, Closer, Hustler, Coach, Qualifier, and Wildcard archetypes, illustrative characters and compositions, and a minimal testing sequence. The working attribute model uses **Speed** and **Conversion**, without Expertise as a third primary stat. The prototype's fixed slot priority is row-major seats 1–9, with automatic first-available assignment. The principle is: “Position determines opportunity. Employee behavior determines what happens with that opportunity.” Traits and advanced matching are still future work; positional effects, qualification, transfers, and human-factor systems remain proposals to test.

The current five-person roster presents these character ideas in Prepare. Numerical Speed/Conversion differences, abilities, and personality effects are not active; the implementation and validation details are recorded under Current implementation.

### Sales can create future obligations

If the company sells recurring contracts, customer success could protect future revenue by preventing cancellations. Aggressive selling could meet today's target while creating unhappy customers and extra work later.

This depends on what each company sells and when its revenue is earned. Customer success may have different value at different companies.

### Different companies reward different teams

Proposed approach: keep the shared 3×3 management system, while each company's product changes which employees, enhancements, and sales strategies work well.

Candidate company profiles, not a confirmed lineup:

| Company concept | Product | Possible management challenge |
| --- | --- | --- |
| Paper supplier inspired by Dunder Mifflin | Business paper orders | Build repeat accounts, handle price pressure, and balance new sales against keeping existing customers. |
| Cybernetics manufacturer (candidate client/product profile for CHROMED) | Expensive implants | Give technical specialists time to explain products; balance high-value sales against suitability and aftercare demands. How this profile maps to CHROMED's contracts is unresolved. |
| Neural entertainment service | Memory or experience subscriptions | Balance fast acquisition against cancellations and the ongoing workload of keeping subscribers satisfied. |
| Bunker corporation | Shelter reservations or contracts | Decide how aggressively to use fear in selling; manage promises, customer trust, and refund demands. |

An employee overlooked at one company could be valuable at another. For example, a slow, technically knowledgeable salesperson might struggle with routine paper orders but excel at explaining complex implants.

Possible shared design dimensions: sale value, time to close, repeat business, and support required after a sale. Each company could emphasize a different combination and introduce one distinctive problem, keeping the core game learnable.

Paper supply and cybernetics are a suggested pair to compare because they could expose very different staffing needs. CHROMED is the confirmed narrative starting workplace; the first gameplay contract/product profile and how other company profiles fit CHROMED remain undecided.

### The grid has a management purpose

Neighboring employees could coach one another, share information, or cause distractions. Seating and lead allocation could work together to make team composition matter.

Keep the rules understandable and connected to how the workplace operates. Exact adjacency mechanics are undecided.

### Cybernetics change roles and introduce tradeoffs

Enhancements could give employees new capabilities, making an overlooked hire useful in a particular role. Prefer interesting tradeoffs over upgrades that only increase a sales statistic.

Possible examples:

- **Voice emulator:** Helps build rapport, but performs poorly with customers who distrust synthetic voices.
- **Predictive sales implant:** Helps with familiar customer patterns, but can misread a changing market.
- **Shared memory link:** Lets paired employees share customer knowledge, but could also transmit stress.

These are illustrative concepts, not a committed upgrade list.

### Revenue objectives and failure — under reconsideration

The initial concept required a daily revenue target to pass the day. The user has since questioned that idea, so it is no longer a confirmed requirement. Revenue now has confirmed roles in triggering twists and influencing the enhancement budget. Its role in winning or failing remains open.

Possible direction: daily performance affects cash reserves and future opportunities, while success is judged over the quarter. Pressure could also come from a growing lead backlog, unhappy customers, or employee stress.

The earlier suggestion that missed targets could damage cash reserves, lender confidence, or retention remains a candidate if targets are retained. No failure model has been selected.

### Preventing stagnant low-revenue runs — proposed solution

The user's requirement is to avoid a marginally successful company producing small revenue without meaningful gameplay. A proposed solution combines a clear quarter-end growth objective with known operating costs and useful progress forecasts.

- **Finite growth objective:** Give the player a clear business outcome to reach within the confirmed 60 workdays. The exact target and success measure remain open. A barely profitable starting build could survive while still falling short of that outcome.
- **Cost of time:** Known recurring operating costs could make low output consume financial runway. These would be baseline rules introduced early, rather than new problems triggered by calendar dates. Costs alone cannot prevent a slightly profitable build from coasting.
- **Visible forecast:** Show remaining days, current performance, and a projection toward the quarter objective. Give enough explanation of bottlenecks for the player to identify a useful change early.
- **Accessible improvement:** Preserve at least one affordable way forward before the next milestone. Avoid requiring an unlock to reach the revenue threshold that grants that same unlock.
- **Pacing:** Let the player fast-forward stable periods so autonomous operation does not require watching repetitive work. Exact speed controls remain undecided.

Possible starting-source constraint: limited daily volume and modest deal values, encouraging source diversification as options unlock. Keep source choices situational so later sources do not automatically replace earlier ones.

This is a recommendation to discuss, not a selected failure model. Revenue would control the introduction of problems and complexity; the quarter clock would limit the time available to achieve the business objective.

### Problem timing — decision history

The original concept introduced a new problem each month. The user explicitly replaced that with revenue-based problem introduction. Months remain units of 20 workdays in the quarter, rather than problem-unlock triggers.

Possible problems include a cheaper competitor, a declining lead source, or cancellations from earlier rushed sales. Warning signs could let the player prepare, so outcomes depend on management choices as well as surprises.

### Technology and Steam plan — Godot selected; remaining proposals

- **Engine:** Godot selected on October 17, 2026; the starter uses Godot 4.7.2 Standard with GDScript for 2D/UI development. Its dedicated 2D tools and flexible UI suit the floor, employee panels, and management reports. It is free under the MIT license. Given the user's Python background, GDScript's familiar indentation-based syntax is an additional reason to try it; it is a separate language. Sources: [Godot features](https://godotengine.org/features/), [license](https://godotengine.org/license/), [scripting languages](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_languages.html).
- **Simulation structure:** Keep business simulation separate from visual presentation so the same model supports autonomous operation, pause, reports, and balancing. Keep employee, enhancement, and company definitions easy to edit as data.
- **Learning approach:** The earlier proposed one-desk exercise is superseded by the implemented 3×3 floor, planner, autonomous queue, pause, and reports. Continue learning the editor, nodes, scenes, and signals through focused increments to this prototype; Godot's [step-by-step guide](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html) remains a reference. A meaningful employee behavior difference or an enhancement is a possible next learning increment, not a chosen task.
- **Broader playable scope — proposed:** One company, the 3×3 floor, independent leads, autonomous sales, pause, revenue-linked enhancement funding, and two revenue-triggered twists. The floor, queue, pause, and daily reports exist; enhancement funding and twists remain unimplemented. Aim to demonstrate how changing the team improves results before expanding to multiple companies.
- **Wishlist milestone:** Publish a reviewed Steam Coming Soon page with representative gameplay and store assets, then collect wishlists while development continues. This can happen before the finished game is released. Steam Direct currently charges $100 USD per app, with applicable taxes depending on location. Sources: [Coming Soon](https://partner.steamgames.com/doc/store/coming_soon), [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee).
- **Festival edition:** Steam Next Fest participation is confirmed as a goal. Propose February 2027 as a conditional demo target. Registration closes January 10, required review submissions are due February 8, and the event runs February 22–March 1. Participation requires a public store page and playable demo, with the full game releasing after the event. A game can participate only once. Source: [February 2027 Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027).
- **Later option:** June 14–21, 2027 is another announced Next Fest window if the demo needs more time. Source: [Steam event calendar](https://partner.steamgames.com/doc/marketing/upcoming_events).

Steam facts checked October 15, 2026. Demo scope, platforms, and festival edition remain unconfirmed; recheck event requirements before registration.

## Open questions

1. **Additional Prepare controls:** Beyond the implemented assignment, swaps, moves, and benching, which enhancements or operating controls should be introduced next? The shared floor and Prepare-only seating lock are established.
2. **Products and revenue:** Which companies should be playable, and how does each product change the floor? When do one-time purchases, recurring contracts, or longer sales processes count toward daily revenue?
3. **Quarter progression and persistence:** Beyond the session lineup, what should persist between days and across saves? What final day length and quarter-end flow should replace the current 45-tick pacing and capped day counter? The next Prepare currently begins through Prepare Next Day after Report.
4. **Objectives and failure:** Are there daily targets at all? What makes a quarter successful, and what causes the company to fail?
5. **Customer success:** Is it a distinct employee role, and does it occupy seats in the same 3×3 grid?
6. **Roster decisions:** Beyond the current qualitative character previews and measured daily workload, what should the player learn about candidates, and how should they discover undervalued employees?
7. **Enhancement costs:** What limits cybernetic modification, and how reversible is it?
8. **Company rosters:** Do companies share an employee pool or have their own rosters?
9. **Lead flow:** Which source characteristics matter, and how should sources produce different lead types? What arrival and patience tuning supports the intended experience? Fixed row-major assignment and FIFO waiting are established; best-match routing and employee lead preferences are outside the current foundation.
10. **Milestones:** Are twists triggered by cumulative quarter revenue, daily revenue, or another measure? How are upcoming changes signaled, and when do they take effect?
11. **Budget:** How does revenue translate into department funding, when is funding allocated, and what can it pay for beyond cybernetics, if anything?
12. **Preventing stagnation:** Should the game use the proposed quarter-end growth objective and operating costs, or a different mechanism? How does a stalled player identify and afford a useful improvement?
13. **Learning sequence:** Which standard systems are available at the start, and what single major concept does each early revenue milestone introduce?
14. **Next development increment:** Which feature should follow the working assignment foundation: an employee behavior difference, one enhancement, or lead-source variety? These are possible increments, not a selected implementation order.
15. **Steam plan:** Which Next Fest edition is feasible, and which desktop platforms should be supported?
16. **Further reporting:** Which additional explanations or historical comparisons would help the player understand team behavior beyond the implemented daily totals and per-employee workload? The current Report opens only after the day ends; Play provides the live floor and queue.

## Next design discussion

Use the implemented starting floor and assignment reports as the baseline. Choose a mechanism that makes marginal low-revenue play require improvement, then sketch the first meaningful employee behavior or enhancement choice, lead-source choice, and early revenue milestones. Check that each step is understandable and reachable with the previous tools. Keep daily revenue gates, the quarter success measure, and the exact funding formula open; retain the confirmed fixed-priority assignment rule as the foundation.
