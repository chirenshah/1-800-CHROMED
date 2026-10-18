# Character archetypes for 1-800-CHROMED

Last updated: October 18, 2026

**Status:** Proposed sales rep system. The foundations below are agreed direction; archetype mechanics, named characters, compositions, and challenges are design hypotheses for testing. The Prepare prototype now supports seating a small test roster and inspecting these proposals; archetype abilities and numerical stat differences are not yet simulated.

Related documents: [game decisions](../decisions.md) and [player persona](../player-persona.md).

## 1. Overview and design philosophy

1-800-CHROMED is a cyberpunk call center management roguelite/strategy concept. The player manages nine cubicles in a 3×3 grid and builds a team whose members solve different business problems.

Take inspiration from Clash Royale's recognizable unit purposes and complementary compositions: tanks, glass cannons, swarms, support, and control. Apply that composition philosophy to an autonomous workplace. The player prepares the system and observes its operation; employees do not require manual deployment or individual call approvals.

**A team of average employees with excellent synergy should be capable of outperforming nine individually exceptional employees with poor synergy.** This is a design target to demonstrate in testing, rather than a guaranteed outcome for every lead environment.

An archetype describes a tactical purpose. A character gives that purpose a personality, a behavioral hook, and a limitation. Multiple distinct characters can belong to the same archetype. The player should recognize a dependable colleague, an impatient hustler, or a supportive mentor through their behavior. Numerical information should help explain those people and choices.

The current quarter structure remains intact. Run resets, procedural generation, and other roguelite progression rules are outside this proposal.

## 2. Confirmed foundations

From [decisions.md](../decisions.md):

- Employees occupy a 3×3 floor, with nine available seats.
- The workday follows **Prepare → Play → Report**.
- Routine lead handling and employee work operate autonomously.
- The player can pause to think and inspect performance; exact pause controls remain open.
- Complementary employees and situational value underpin the “Moneyball for a call center” direction.
- Employees can receive cybernetic enhancements between days.
- Leads arrive independently, and lead sources have different characteristics.
- The company's product must affect management decisions.
- Revenue milestones introduce new problems and complexity. The quarter contains 60 workdays; calendar months do not schedule these challenges.

Direction supplied by the current character brief:

- Use recognizable roles and character behaviors to make composition matter.
- Focus the working numerical model on **Speed** and **Conversion**. Do not add Expertise as a third primary employee stat.
- Preserve the **fixed slot-priority routing** baseline specified in the brief. Any extension needs an explicit design decision and a separate test.
- A successful team does not have to include every archetype.

The six archetypes are proposed. Their exact effects, balance, adjacency rules, lead transfers, qualification actions, and configurable routing policies remain unconfirmed. Stress, morale, relationships, and other human factors are possible future systems.

**Routing evidence:** The brief names fixed slot priority as established direction, while the design log leaves its exact rules open. The [queue visualization prototype](../scripts/call_queue_simulation.gd) assigns the oldest waiting call to the first available occupied seat in ascending seat order. Prepare supplies the occupied seats; their numbering and priority remain fixed when colleagues move. Its shared handling duration and deterministic outcomes are placeholders, with no patience limit, qualification, transfers, or archetype abilities. This makes queue flow observable; the broader routing rules still need design. See [README.md](../README.md) for the prototype assumptions.

### Implemented planning prototype — October 18, 2026

Prepare now offers Nina, Zip, Victoria, Ada, and Dex as a small test roster. Nina, Zip, and Victoria begin in seats 01, 02, and 04; Ada and Dex are available on the bench. Select a workstation and a candidate to assign, move, swap, or bench employees. Each candidate has the proposed strength, tradeoff, and qualitative Speed/Conversion profile from this document, with an explicit notice that abilities are previews. No numerical ratings have been invented.

Seating controls lock during Play, pause, and Report. The lineup carries between days in the current session, while daily calls and counters reset. The planner enforces one seat per named employee and requires at least one occupied seat to start; these are bounded prototype rules, not a finalized hiring, duplicate-hire, or economy design. All occupied employees still use the same simulation baseline, including support roles. Full archetype differentiation and the remaining thirteen candidates are deferred; this UI does not establish adjacency buffs, qualification, transfers, hiring costs, or saving between launches.

## 3. Proposed character attribute model

| Primary attribute | Meaning | Questions still to test |
| --- | --- | --- |
| **Speed** | How quickly an employee processes a sales interaction. | Its displayed scale, conversion to handling time, and minimum interaction duration. |
| **Conversion** | How effectively an employee closes a sale on a handled opportunity. | Its displayed scale, relationship to outcome probability, and interaction with lead conditions. |

An archetype suggests a performance profile, but its identity must come from behavior. Two characters with similar base attributes should still create different decisions because they respond differently to teammates, positions, or lead conditions.

For example, Marcus may become faster as the queue grows while losing Conversion. This is a proposed reaction to queue conditions; it does not require a confirmed Stress stat. Brick's recovery can be a visible ability cooldown without establishing a general burnout system.

Lead value and lead difficulty are separate conditions to explore. A valuable lead is not automatically difficult. These conditions belong to leads, rather than becoming additional primary employee stats. A Closer improves the chance of earning a lead's value; higher Conversion does not automatically increase the payout of a successful sale. A trait that changes payout must say so explicitly.

Proposed supporting data includes archetype, named traits, trigger conditions, affected teammates, and temporary state. Exact formulas, caps, durations, trait stacking, costs, and hiring rules remain open. Present effects in plain language, with enough detail to support useful comparisons.

## 4. Six archetypes and their tactical purposes

All descriptions below are proposals.

| Archetype | Tactical analogy | Purpose and strengths | Weaknesses and design boundary |
| --- | --- | --- | --- |
| **Workhorse** | Tank | Capacity, consistency, and absorbing incoming call volume. Sustains throughput and can keep routine demand from overwhelming the floor. | Generally lower Conversion and weaker returns from valuable opportunities. Protecting a Closer from routine calls requires compatible routing; the archetype label alone cannot reserve leads. |
| **Closer** | Glass Cannon | High Conversion, especially on difficult or valuable opportunities. Makes scarce opportunities count. | Slow interactions and limited capacity during surges. Needs access to suitable leads to justify the seat. |
| **Hustler** | Swarm | Extremely fast handling of straightforward leads and high-frequency output. Suits plentiful, low-value opportunities. | Weak Conversion on demanding interactions. Short bursts and narrow conditions can break down when the mix changes. |
| **Coach** | Support | Improves nearby employees' Speed, Conversion, or recovery from explicit ability downtime. Makes the surrounding team more effective. | Low personal sales contribution and an occupied seat that could hold another seller. Requires useful neighbors. Stress recovery is conditional on a future stress system. |
| **Qualifier** | Control | Identifies promising leads and could prepare, prioritize, filter, or redirect them so the floor uses its capacity well. | Limited direct revenue and potentially extra handling time. Its value depends on composition, demand, and an explicitly approved lead-control mechanism. |
| **Wildcard** | High Risk / High Reward | Creates exceptional but inconsistent opportunities through unusual conditions and combinations. | Unreliable output can destabilize a fragile floor. Requires understandable risk and may benefit from supporting teammates. |

**Workhorse versus Hustler:** A Workhorse should be useful for reliable, sustained capacity under pressure; a Hustler should excel at short, explosive interactions with straightforward opportunities. Test that difference under both steady and bursty demand. If the player's choice reduces to comparing two versions of Speed, merge or redesign the roles.

## 5. Character examples for every archetype

These 18 characters are illustrative candidates. Qualitative behavior is intentional; numerical values would imply a balance model we have not tested. Additional characters could exist within each archetype. Rules for unique characters or duplicate hires are open.

### Workhorses

| Character name | Archetype | Proposed behavior and strength | Weakness or tradeoff |
| --- | --- | --- | --- |
| **Marcus** | Workhorse | Picks up the pace as the waiting queue grows. Useful when incoming volume threatens capacity. | Conversion deteriorates under queue pressure. Queue rules and pressure thresholds need testing. |
| **Nina** | Workhorse | Maintains a consistently quick processing rhythm. Provides a dependable capacity baseline. | Lower peak output than other Workhorses when their special conditions activate. |
| **Brick** | Workhorse | Clears a burst of routine leads through a temporary Speed increase. | Needs visible recovery time afterward. A badly timed burst can leave the floor short of capacity. |

### Closers

| Character name | Archetype | Proposed behavior and strength | Weakness or tradeoff |
| --- | --- | --- | --- |
| **Victoria** | Closer | Particularly effective at converting high-value opportunities. | Very slow interactions; routine calls can occupy her while better opportunities arrive. |
| **Dex** | Closer | Receives a temporary Conversion advantage after nearby teammates make sales. | Weaker when neighboring employees struggle or rarely complete sales. Trigger duration and stacking remain open. |
| **Zero** | Closer | Gains a major Conversion advantage on every third completed call. | Less effective on the intervening calls. The valuable lead may arrive at the wrong point in the sequence. Counting and reset rules need definition. |

### Hustlers

| Character name | Archetype | Proposed behavior and strength | Weakness or tradeoff |
| --- | --- | --- | --- |
| **Zip** | Hustler | Keeps interactions very short, rapidly closing straightforward opportunities. | Ends difficult conversations early, sacrificing chances that a patient seller might convert. |
| **Mox** | Hustler | Builds a Speed streak through consecutive successful routine sales. | A failed sale or demanding interaction resets the streak. A mixed lead stream disrupts the rhythm. |
| **Tess** | Hustler | Uses a practiced checklist to process repeated leads of the same condition increasingly quickly. | Changing conditions removes the advantage. Needs readable lead categories and a limit on the repetition benefit. |

### Coaches

| Character name | Archetype | Proposed behavior and strength | Weakness or tradeoff |
| --- | --- | --- | --- |
| **Ada** | Coach | Gives an adjacent teammate a Conversion benefit after that teammate fails a sale, helping the next attempt. | Weak personal output; contributes little when neighbors rarely fail. The failed lead is not recovered by the buff. |
| **Rook** | Coach | Uses coaching intervals to improve adjacent employees' handling Speed. | Coaching delays Rook's own next interaction. The team must gain enough capacity to cover that opportunity cost. |
| **June** | Coach | Helps adjacent employees recover from explicit burst abilities, such as Brick's proposed cooldown. | Low direct sales and little benefit beside employees without recovery windows. General stress relief would require a separate system decision. |

### Qualifiers

Each ability below is a possible extension to baseline routing, rather than behavior that follows automatically from placing a Qualifier on the floor.

| Character name | Archetype | Proposed behavior and strength | Weakness or tradeoff |
| --- | --- | --- | --- |
| **Sable** | Qualifier | Reviews waiting leads and moves promising high-value opportunities earlier in the queue. Recipient selection could still follow fixed slot priority. | Ordinary leads wait longer, and review consumes time. Reordering the queue requires approval even if employee priority stays fixed. |
| **Patch** | Qualifier | Prepares a lead so its next handler can process it faster. Can free a slow Closer to handle more opportunities. | Requires a second handling stage or handoff, consumes Patch's time, and may cost more than it saves on simple leads. |
| **Switch** | Qualifier | Diverts routine leads toward suitable capacity employees, preserving Closers for better opportunities. | Explicitly changes recipient selection. If preferred handlers are busy, holding or fallback behavior must be defined; valuable capacity could sit idle. |

### Wildcards

| Character name | Archetype | Proposed behavior and strength | Weakness or tradeoff |
| --- | --- | --- | --- |
| **Nyx** | Wildcard | Automatically attempts a premium offer on eligible high-value leads, increasing payout if successful. | Reduced Conversion on those attempts can lose an otherwise achievable sale. Eligibility and payout changes must be explicit. |
| **Jinx** | Wildcard | Builds a Conversion advantage after personal failed calls, then spends it on the next success. | Several leads may be lost before the payoff. The benefit needs a cap and rules that prevent deliberate failure farming. |
| **Echo** | Wildcard | Takes a temporary Speed or Conversion benefit from a neighboring sale, with the benefit determined by that seller's role. | Weak baseline performance and benefits that may arrive at an unhelpful time. Use a small explicit mapping of effects; avoid recursive copying of traits. |

## 6. Team synergy and positional interactions

The test for synergy is whether one employee changes what another can accomplish. A roster of independent revenue multipliers would leave the central design problem unresolved.

| Proposed interaction | Why it could matter | Dependency or risk |
| --- | --- | --- |
| Workhorse absorbs routine demand while a Closer handles valuable leads. | Trades capacity against conversion and makes both roles situationally useful. | Fixed slot priority alone does not guarantee this split. An early Workhorse could take a valuable lead; an early Closer could become occupied with a routine call. |
| Qualifier prepares or directs a lead toward a Closer. | One employee improves the opportunity another receives. | Qualification costs, routing exceptions, and transfers need explicit decisions. |
| Coach supports selected neighbors. | A seat can produce more value through teammates than through personal sales. | Compare the full team's benefit with replacing the Coach with another seller. Test range, stacking, and caps. |
| Fast sellers trigger Dex's Conversion benefit. | Frequent small sales can support a teammate focused on larger opportunities. | Timing and location must be legible; benefits need limits. |
| June reduces Brick's recovery window. | Support changes a burst employee's sustained availability. | Can become mandatory if recovery is too punishing without June. |
| Support and reliable capacity surround a Wildcard. | Teammates can help the floor withstand weak periods and exploit strong ones. | Avoid a single required support pairing or an opaque chain of triggers. |

**Suggested first positional experiment:** Define “neighbor” as an orthogonally adjacent cubicle, excluding diagonals. A center employee can then reach four neighbors, an edge employee three, and a corner employee two. This is a test rule, not confirmed adjacency design.

Separate geometric position from intake priority. Placing a Coach centrally may improve coverage while changing which slot receives calls first. Preserve the established slot ordering when testing positions, and record both effects. A new adjacency system must not silently renumber or reprioritize slots.

Use visible state changes and report attribution to help players recognize assists. Account for a sale's revenue once, even when several teammates contributed. Do not invent separate team revenue for every assist.

## 7. Example nine-person compositions

These are illustrative compositions, not required or optimal builds. Counts describe roles; they do not require duplicate copies of any named character.

| Composition | Nine employees | Strong environment | Vulnerability |
| --- | --- | --- | --- |
| **The Call Factory** | 3 Workhorses + 3 Hustlers + 1 Coach + 1 Qualifier + 1 Closer | High-volume demand, especially plentiful straightforward, low-value leads. | Demanding, high-value leads expose limited conversion capacity. A Qualifier must provide a real benefit to justify its seat. |
| **The Elite Boutique** | 4 Closers + 2 Coaches + 1 Qualifier + 1 Workhorse + 1 Wildcard | Lower-volume, high-value opportunities where conversion and support matter. | Sudden routine-call spikes occupy slow employees and overwhelm the small capacity buffer. |
| **The Casino** | 4 Wildcards + 2 Closers + 1 Coach + 1 Hustler + 1 Workhorse | Conditions that activate its risky combinations can produce exceptional revenue spikes. | Weak periods can coincide, making outcomes unstable and leaving too little dependable throughput. |

The Call Factory could use frequent Hustler sales to support Dex while Workhorses provide steadier capacity. The Elite Boutique tests whether Coaches and qualification make scarce opportunities worth more than simply adding sellers. The Casino tests whether four risky employees create interesting decisions or merely unpredictable results.

The Casino deliberately has no Qualifier, and the Call Factory has no Wildcard. Successful compositions should be able to omit roles. Lead access, exact placement, and the cost of support still determine whether these ideas work.

## 8. Challenge types and counterplay

These are proposed lead environments, not confirmed events, scheduled workday modifiers, or mandatory monthly changes. They could inform later revenue-triggered twists or test scenarios; their activation rules remain open.

| Environment | Proposed conditions | What it challenges | Possible response and information to provide |
| --- | --- | --- | --- |
| **Lead Flood** | Many ordinary leads with short patience timers. | Slow teams and insufficient throughput. Waiting and abandonment require proposed queue rules. | Explore Workhorse capacity and Hustler speed. Preview expected volume and patience before Play. |
| **Whale Season** | Fewer opportunities with high value. Difficulty is a separate condition to specify. | Teams that rely entirely on speed and waste scarce opportunities. | Explore Closers, useful support, and qualification if approved. Preview value, volume, and any expected difficulty separately. |
| **Unpredictable Market** | Erratic arrivals and varying lead quality. | Fragile teams that depend on one narrow condition or uninterrupted streaks. | Explore reliable capacity and adaptable combinations. Communicate the likely range of conditions while preserving uncertainty about exact arrivals. |
| **Burnout Crisis** | Sustained lead pressure. | Potentially tests streak-dependent employees and those vulnerable to stress. Actual burnout effects require an unconfirmed human-factor system. | Explore consistent employees and support. Without stress mechanics, test sustained-load behavior and ability recovery only; do not label a hidden penalty as burnout. |

Where possible, provide meaningful forecasts during Prepare. A forecast can describe a range or tendency without revealing every future lead. Warning signs should give the player a plausible response using currently available tools.

## 9. Relationship to leads and autonomous Play

### Preserve the routing baseline

Fixed slot priority remains the baseline named by the brief. Confirm its exact ordered slots, eligible-employee rules, and fallback behavior before implementing or interpreting an archetype test. Do not quietly substitute best-match routing, random assignment, round robin, or manual assignments.

Under an unchanged slot-priority system, archetypes affect what happens after assignment through handling time, conversion conditions, and teammate triggers. Their labels do not automatically decide which leads reach them. This constraint is part of the design problem.

In particular, Workhorses cannot promise to protect Closers from routine calls until we show how the existing allocation order produces that result or approve an explicit extension. Likewise, a Qualifier needs an actual control action to create economic value; simply giving it low Conversion does not establish the role.

### Keep transfers and qualification explicit

Compare these possible designs separately:

1. **One employee per lead:** The assigned employee retains the lead through completion. Qualifier mechanics would need an explicitly designed intake or preparation action compatible with that constraint.
2. **Qualification before final assignment:** A lead receives a preparation stage, then enters ordinary slot-priority assignment. This adds processing time and a new stage even if recipient priority is preserved.
3. **Transfer after assignment:** An employee can hand a lead to another. This needs rules for eligibility, destination, waiting, transfer cost, retained progress, and failure. Targeted transfer would be a routing extension.

None of these alternatives is selected here. Sable's prioritization and Switch's diversion also require explicit approval; they are not implied by a queue or a Qualifier seat.

Any selected mechanism must run autonomously. Configure any available policy during Prepare; routine execution cannot require the player's approval. Whether policies can change during Play or while paused remains open. Character triggers should communicate their conditions and resolve automatically.

Avoid double counting a prepared or transferred lead as a second arrival or a second sale. Reports should distinguish successful sales from supporting actions so the player can evaluate both direct and indirect contributions.

## 10. Open design questions

1. What is the precise fixed slot-priority order, and what makes an employee eligible for assignment? How does rearranging seats interact with that order?
2. Can leads wait? If so, what determines queue order, capacity, patience, abandonment, and overflow?
3. Must a lead stay with one employee, or can it be prepared or transferred? What time and opportunity costs apply?
4. Which Qualifier actions are compatible with unchanged routing, and which need an approved extension? Could qualification be useful without selecting a destination?
5. Are Workhorse and Hustler recognizably different under real play, beyond their two primary attributes?
6. How do Speed and Conversion map to handling duration and outcomes? Which lead conditions modify them?
7. What does “nearby” mean? When do support effects trigger, how do they stack, and what limits prevent compulsory Coach placement?
8. Which information about leads, traits, risks, and future conditions is visible during Prepare, Play, and Report?
9. How does the report reveal indirect employee value without overstating causation or counting revenue twice?
10. Which counters reset per call, workday, or quarter? In particular, how do Zero, Mox, Tess, and Jinx carry or lose progress?
11. How much Wildcard variability supports planning? Can the player anticipate risk, recover from weak periods, and avoid exploits such as farming failed calls?
12. How do hiring and enhancement costs balance opportunity cost? Are named characters unique, and are repeat hires possible?
13. Will stress, morale, or relationships be added? What benefit would justify their complexity, and how would they interact with existing traits?
14. Can several strong compositions omit an archetype and still adapt as products and revenue milestones change the floor's needs?

## 11. Suggested minimal prototype for testing archetype differentiation

This is a proposed testing sequence. No gameplay implementation is part of this documentation task. Start with a small occupied subset of the nine-seat floor; defer the full 18-character roster.

1. **Make the baseline measurable.** Record the fixed slot order and availability rules, then build individual lead processing with only Speed and Conversion as primary employee attributes. Any queue rule must be selected explicitly. Use a repeatable arrival schedule, known lead conditions, and repeated outcome seeds. Keep lead value distinct from difficulty.
2. **Test capacity roles.** Compare Nina, Zip, and a plain baseline employee across steady simple demand, bursty simple demand, and a mixed lead stream. Give the characters comparable starting attributes in a controlled test to isolate their behaviors. Ask whether their benefits and weaknesses create a real choice. Add Brick's burst and recovery only after this distinction is clear.
3. **Test a seat spent on support.** With three occupied seats, compare two sellers plus Ada against three sellers. Repeat with useful and unhelpful neighbor placements under an explicitly selected adjacency rule. Check team output and whether a player can explain Ada's contribution. Also test Victoria under scarce valuable demand and under routine-call floods.
4. **Test one conditional partnership.** Pair Dex with frequent sellers and then with slow sellers, keeping other conditions comparable. Look for a visible teammate interaction beyond independent stat gains. Use those results before adding more chains of triggers.
5. **Resolve the routing question before testing a Qualifier.** Preserve a baseline with unchanged slot priority. Choose one explicit experimental extension, such as Patch's preparation stage, and compare it with the baseline. Include handling costs and busy-destination behavior. Verify that each lead and sale is accounted for once.
6. **Add one bounded risk.** Test Nyx's premium offer with readable eligibility, Conversion cost, and payout. Compare repeated outcomes and the player's ability to plan around weak results. Defer multiple Wildcards and complex copying behavior.
7. **Expand to nine seats once the roles work.** Compare a complementary roster with a roster of individually stronger employees whose roles or triggers fit poorly. Test the three example compositions across multiple environments. Hold the lead schedule constant within comparisons and document the resource assumptions; hiring costs are not yet designed.

Suggested evidence includes completed interactions, conversion by lead condition, revenue, idle and busy time, and support triggers. Add queue losses, abandonment, recovery time, or transfer counts only when their corresponding experimental systems exist.

Success means a player can explain why a role helped, identify a situation where it would struggle, and propose a different team for different conditions. We should also be able to demonstrate an average but complementary team beating stronger individuals in an appropriate scenario. If raw Speed and Conversion rankings explain every choice, redesign the interactions before expanding content.
