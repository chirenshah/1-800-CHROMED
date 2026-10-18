# Game decisions

Last updated: October 18, 2026

Living design log for a cyberpunk call center management game. Keep agreed direction separate from suggestions. Move an idea into confirmed decisions when we agree on it; preserve the reason when changing a decision.

## Confirmed direction

- **Setting:** In 2189, the player is newly promoted Regional Sales Floor Manager Grade C-7 at 1-800-CHROMED, an independent telesales agency selling megacorp cybernetics. See [WORLD.md](docs/WORLD.md) for narrative canon. The game remains a call-center management game; this setting does not change the Prepare → Play → Report loop or introduce mechanics.
- **Team:** Employees occupy a 3×3 grid. Salespeople are part of the roster; customer success is still under consideration.
- **Management horizon:** The player manages one company for a 60-workday quarter, divided into three months of 20 workdays. Each individual game represents one workday. What persists between days is still to be defined.
- **Management feel:** Business decisions should have believable consequences and be capable of making or breaking the company.
- **Engagement pace:** Use a pause-and-think model. The player can pause to consider management decisions. The user prefers this because it fits the intended real-life management feel. Exact pause controls remain undecided.
- **Core workday flow:** Use a **Prepare → Play → Report** model. Prepare lets the player configure the floor before operation. Play shows the autonomous workday in progress. Report gives the player performance information through a report tab. Prepare and Play may use the same floor screen with editing enabled only during Prepare, but the exact scene and navigation structure remains undecided.
- **Autonomous operation:** The sales floor must keep functioning without human intervention. Routine lead handling and employee work cannot depend on manual assignments or player approvals. The player builds and improves the system; exact configuration controls remain undecided.
- **Roster building:** “Moneyball for a call center.” Finding the correct mix of employees matters more than filling every seat with a star performer.
- **Cybernetics:** The player can modify employees with cybernetic enhancements between days.
- **Different companies:** The player can play at different companies, each inspired by fiction. The player stays at one company for the whole quarter. A paper supplier inspired by Dunder Mifflin is an initial example; the company lineup and names are undecided. CHROMED is the confirmed narrative workplace; how the multi-company gameplay direction fits its contracts remains unresolved.
- **Products affect management:** What a company sells must meaningfully change how the player manages the sales floor.
- **Incoming leads:** Leads flow in independently. Arrival timing, routing, and whether leads can wait are still to be designed.
- **Lead sources:** The player can use different lead sources, each with its own characteristics. Source selection and optimization are part of managing the floor. The exact sources and their attributes are undecided.
- **Revenue milestones:** Different revenue levels introduce problems and twists that require the player to improve and adapt the team. These replace the original month-based problem introduction. A single static build should not solve the whole quarter. Threshold values and the revenue measure used are undecided.
- **Learning curve:** Start with mostly standard employees, leads, and systems. Revenue milestones progressively introduce more options and complexity, including lead-type optimization. The exact unlock sequence is undecided.
- **Avoiding stagnation:** A marginally successful company must not be able to coast on small revenue with no meaningful gameplay. The mechanism that encourages or requires improvement is still to be chosen.
- **Department budget:** Revenue has a relationship with the department's budget, which can be spent on cybernetic enhancements. The funding formula and when money becomes available are undecided.
- **Commercial goal:** Sell the game on Steam, let players wishlist it before release, and participate in Steam Next Fest. The festival edition and release dates have not been selected.

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

## Development context

- The user is a software developer and intends to learn game-engine development while making this game.
- The user's usual programming language is Python. Prior engine experience has not been specified. The user selected Godot and requested project initialization on October 17, 2026. The starter project uses Godot 4.7.2 Standard, GDScript, and the Compatibility renderer; gameplay remains to be implemented.

## Ideas to explore — not yet decisions

### Autonomous operation and player engagement

The user considered SimCity and Clash Royale as engagement references, chose pause-and-think play, and then clarified that the entire floor should work independently of human intervention. Earlier suggestions about routinely rescuing deals through manual actions are superseded by autonomous operation.

Pause remains confirmed. Speed controls, automatic pauses, and the actions available while paused remain open. Whether the player can optionally change operating rules during a day or only between days is undecided. Cybernetic modifications are currently planned between days.

Confirmed workday loop:

- **Prepare:** Configure the roster, seating, enhancements, and any available operating rules before the workday.
- **Play:** Run the autonomous sales floor. The player observes results and can pause to understand bottlenecks.
- **Report:** Review performance information in a report tab to understand outcomes and inform the next Prepare phase.

Revenue still affects department funding and triggers twists at milestones. The player uses reports to decide how to invest and adjust the team during a later Prepare phase.

For example, a lead-routing policy could decide what happens when the best specialist is busy. The player's decision would be how to configure that policy and build enough capacity, rather than needing to route every difficult call personally.

Possible source of engagement: understanding why a team succeeds, identifying the next bottleneck, and choosing which investment will help. Competing commitments and incomplete information can make planning difficult even with time to think. What information is visible needs to be designed.

The three-phase structure is confirmed. The exact preparation controls, routing policies, report contents, session length, pause controls, and whether Prepare and Play share one screen remain undecided.

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

See [characters.md](characters.md) for the proposed Workhorse, Closer, Hustler, Coach, Qualifier, and Wildcard archetypes, illustrative characters and compositions, and a minimal testing sequence. The working attribute model uses **Speed** and **Conversion**, without Expertise as a third primary stat. The document preserves the fixed slot-priority baseline named in the character brief while flagging undocumented routing details. Positional effects, qualification, transfers, and human-factor systems remain proposals to test.

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
- **Learning approach:** Learn the editor, nodes, scenes, and signals using Godot's [step-by-step guide](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html), then apply them to a small prototype of this game. Start with one desk, independently arriving leads, automatic sales, a revenue display, and pause/resume. Add a second employee and one enhancement to demonstrate a meaningful performance difference before expanding to the full floor. This is a proposed learning sequence, not a scope commitment.
- **First playable scope:** One company, the 3×3 floor, independent leads, autonomous sales, pause, revenue-linked enhancement funding, and two revenue-triggered twists. Aim to demonstrate how changing the team improves results before expanding to multiple companies.
- **Wishlist milestone:** Publish a reviewed Steam Coming Soon page with representative gameplay and store assets, then collect wishlists while development continues. This can happen before the finished game is released. Steam Direct currently charges $100 USD per app, with applicable taxes depending on location. Sources: [Coming Soon](https://partner.steamgames.com/doc/store/coming_soon), [Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee).
- **Festival edition:** Steam Next Fest participation is confirmed as a goal. Propose February 2027 as a conditional demo target. Registration closes January 10, required review submissions are due February 8, and the event runs February 22–March 1. Participation requires a public store page and playable demo, with the full game releasing after the event. A game can participate only once. Source: [February 2027 Next Fest](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027).
- **Later option:** June 14–21, 2027 is another announced Next Fest window if the demo needs more time. Source: [Steam event calendar](https://partner.steamgames.com/doc/marketing/upcoming_events).

Steam facts checked October 15, 2026. Demo scope, platforms, and festival edition remain unconfirmed; recheck event requirements before registration.

## Open questions

1. **Prepare controls:** Which rules can the player configure during Prepare? Do Prepare and Play share the floor screen with editing enabled or disabled by phase, or use separate screens?
2. **Products and revenue:** Which companies should be playable, and how does each product change the floor? When do one-time purchases, recurring contracts, or longer sales processes count toward daily revenue?
3. **Between days:** What persists through the confirmed 60-workday quarter, how long does a workday take to play, and when does the next Prepare phase begin?
4. **Objectives and failure:** Are there daily targets at all? What makes a quarter successful, and what causes the company to fail?
5. **Customer success:** Is it a distinct employee role, and does it occupy seats in the same 3×3 grid?
6. **Roster decisions:** What can the player see about candidates, and how do they discover undervalued employees?
7. **Enhancement costs:** What limits cybernetic modification, and how reversible is it?
8. **Company rosters:** Do companies share an employee pool or have their own rosters?
9. **Lead flow:** Which source characteristics matter, how do sources produce different lead types, and how do routing and waiting affect results?
10. **Milestones:** Are twists triggered by cumulative quarter revenue, daily revenue, or another measure? How are upcoming changes signaled, and when do they take effect?
11. **Budget:** How does revenue translate into department funding, when is funding allocated, and what can it pay for beyond cybernetics, if anything?
12. **Preventing stagnation:** Should the game use the proposed quarter-end growth objective and operating costs, or a different mechanism? How does a stalled player identify and afford a useful improvement?
13. **Learning sequence:** Which standard systems are available at the start, and what single major concept does each early revenue milestone introduce?
14. **Development:** Which first Godot exercise should follow project setup? The one-desk simulation remains a proposed learning sequence.
15. **Steam plan:** Which Next Fest edition is feasible, and which desktop platforms should be supported?
16. **Reports:** Which results and explanations appear in the Report tab, and can the player inspect it during Play or only after a workday ends?

## Next design discussion

Choose a mechanism that makes marginal low-revenue play require improvement. Then sketch one company's standard starting floor, first lead-source choice, and early revenue milestones, checking that each step is understandable and reachable with the previous tools. Keep daily revenue gates, the quarter success measure, and the exact funding formula open.
