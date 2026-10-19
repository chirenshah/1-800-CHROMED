# 1-800-CHROMED — Implement Daily Lead Discard Pile & Recycler Archetype

## Objective

Implement a **Daily Lead Discard Pile** mechanic in 1-800-CHROMED, our cyberpunk sales-team autobattler, along with a new employee archetype called **The Recycler**.

The discard pile stores leads that have been worked by a sales representative but did not convert into a sale.

The Recycler is a specialized employee who works exclusively from this discard pile, attempting to recover failed sales opportunities.

Together, these mechanics create a second source of revenue and enable new team-building strategies.

**Important:** Implement the discard pile lifecycle and Recycler archetype now. Do not invent additional recovery abilities, character archetypes, or unapproved mechanics.

## 1. Existing Game Context

1-800-CHROMED uses three primary phases:

1. **Prepare:** Players configure their sales team, positioning, augments, and purchases.
2. **Play:** The sales floor operates autonomously, processing incoming leads and generating revenue.
3. **Report/Review:** Players inspect performance and prepare for the next workday.

Each workday consists of a short autonomous simulation.

The sales floor contains a 3×3 grid with nine possible employee positions.

Employees process leads through timed sales interactions.

The primary employee attributes include:

- **Speed:** Determines interaction duration.
- **Conversion:** Determines the baseline chance of converting a lead.
- **Upsell Chance:** Determines the chance of triggering an upsell on a successful sale.
- **Upsell Multiplier:** Determines the multiplier applied to an upsell.

Lead assignment uses fixed slot priority (1–9), skipping employees who are busy.

The incoming lead queue uses FIFO processing, with leads potentially abandoning the queue when their patience expires.

Preserve these existing systems and their current implementation.

## 2. Core Mechanic: Lead Discard Pile

Introduce a separate collection named `lead_discard_pile`.

This collection stores leads that have completed a normal sales interaction without converting.

### Lead Lifecycle

```text
INCOMING LEAD
      |
      v
INCOMING QUEUE
      |
      v
NORMAL SALES REP
      |
      v
TIMED SALES INTERACTION
      |
      +---- SUCCESS ----> REVENUE EARNED
      |
      +---- FAILURE
              |
              v
       LEAD DISCARD PILE
              |
              v
           RECYCLER
              |
              v
      RECOVERY INTERACTION
              |
              +---- SUCCESS ----> REVENUE EARNED
              |
              +---- FAILURE ----> PERMANENTLY REMOVED
```

A lead must complete an actual sales interaction before it can enter the discard pile.

A discarded lead may receive one Recycler recovery attempt.

Leads abandoned while waiting in the incoming queue do not enter the discard pile.

## 3. Confirmed Discard Pile Rules

### Rule 1: Failed normal sales enter the discard pile

When a normal sales representative completes an interaction and fails to convert the lead:

- Mark the interaction as unsuccessful.
- Remove the lead from the active interaction.
- Add the lead to `lead_discard_pile`.
- Make the employee available for their next interaction.

The failed lead must not automatically return to the incoming queue.

### Rule 2: Successful sales do not enter the discard pile

When a lead converts:

- Apply the existing revenue calculation.
- Preserve existing upsell mechanics.
- Record the successful sale normally.
- Remove the lead from active processing.

Do not add successful leads to the discard pile.

### Rule 3: Abandoned leads do not enter the discard pile

If a lead expires while waiting in the incoming queue:

- Preserve the existing abandonment behavior.
- Record the lead as abandoned.
- Do not add the lead to the discard pile.

Abandonment and failed conversion are separate outcomes.

### Rule 4: The discard pile resets every workday

Every workday begins with an empty discard pile.

During Play, unsuccessful normal sales interactions accumulate leads in the pile.

At the end of the workday:

- Record relevant statistics.
- Clear the discard pile.
- Ensure discarded leads do not carry over to the next workday.

The discard pile does not persist between workdays or across the quarter.

### Rule 5: Discarded leads remain available during Play

The discard pile is accessible to Recyclers during the active workday.

Future gameplay systems may also interact with discarded leads, including:

- Character abilities
- Cybernetic augments
- Artifacts

Do not implement additional discard interactions as part of this task.

## 4. New Character Archetype: The Recycler

### Archetype Overview

**Name:** Recycler

**Role:** Failed Lead Recovery

**Primary Function:** Convert previously failed sales opportunities into revenue.

**Strength:** Generates additional revenue from leads that normal sales representatives failed to convert.

**Weakness:** Cannot process incoming leads. Becomes idle when the discard pile is empty.

The Recycler occupies one of the nine available employee slots on the 3×3 sales floor.

The Recycler is a full employee archetype, not an augment or artifact.

### Character Stats

The Recycler uses the same stat system as every other sales representative.

| Attribute | Behavior |
|---|---|
| Speed | Determines how quickly the Recycler processes a discarded lead. |
| Conversion | Determines the probability of converting the discarded lead. |
| Upsell Chance | Determines the chance of an upsell on a successful recovery. |
| Upsell Multiplier | Determines the value multiplier applied when an upsell occurs. |

Use existing stat calculations and formulas.

Do not introduce Recycler-specific stat formulas or arbitrary conversion penalties.

The Recycler should support existing augments, stat modifiers, and other applicable employee systems.

## 5. Recycler Lead Assignment Rules

### Normal Sales Representatives

Normal sales representatives receive leads from the incoming lead queue.

They do not automatically process leads from the discard pile.

### Recyclers

Recyclers receive leads exclusively from the discard pile.

A Recycler must never receive a lead directly from the incoming queue.

When a Recycler is available:

1. Check whether the discard pile contains an available lead.
2. If a lead exists, assign it to the Recycler.
3. Remove the lead from the discard pile immediately.
4. Begin a normal timed sales interaction.
5. Resolve the interaction using the Recycler's existing stats.

If the discard pile is empty, the Recycler remains idle.

### Multiple Recyclers

Multiple Recyclers may occupy the sales floor.

When multiple Recyclers are available, use the existing fixed slot priority (1–9) to determine assignment order.

Each Recycler can process only one lead at a time, unless another existing mechanic explicitly modifies that behavior.

A discarded lead cannot be assigned to multiple Recyclers simultaneously.

## 6. Recycler Sales Outcomes

A Recycler interaction has two possible outcomes.

### Successful Recovery

When the Recycler successfully converts a discarded lead:

- Apply the normal revenue calculation.
- Apply existing upsell mechanics.
- Record a successful conversion.
- Attribute the sale to the Recycler.
- Remove the lead permanently from active processing.

The recovered lead does not return to the discard pile.

### Failed Recovery

When the Recycler fails to convert a discarded lead:

- Record the unsuccessful recovery interaction.
- Permanently remove the lead from the workday.
- Do not return it to the discard pile.
- Do not return it to the incoming queue.
- Make the Recycler available for another lead.

**Confirmed rule: Every discarded lead receives a maximum of one Recycler recovery attempt.**

A failed recovery permanently removes that lead from the current workday, regardless of how many Recyclers are on the floor.

## 7. Data Model

Reuse the existing lead data model wherever possible.

Do not create a separate lead type solely for discarded leads unless the current architecture requires it.

A discarded lead should retain its existing relevant information, such as:

- Unique lead identifier
- Lead value
- Lead type or characteristics, if applicable
- Original source, if tracked
- Other existing lead properties

Do not invent new lead attributes.

Use the existing lead object or a suitable representation that preserves its identity and data.

### Suggested Interface

The exact implementation should follow the current project architecture.

Conceptually, the system should support:

```gdscript
var lead_discard_pile: Array = []

func discard_lead(lead):
    lead_discard_pile.append(lead)

func get_discard_count() -> int:
    return lead_discard_pile.size()

func take_discarded_lead():
    if lead_discard_pile.is_empty():
        return null
    return lead_discard_pile.pop_front()

func clear_discard_pile():
    lead_discard_pile.clear()
```

This is illustrative pseudocode, not a required implementation.

Avoid duplicating leads or adding the same lead to multiple active collections.

The lead should be removed from the discard pile as soon as a Recycler claims it, not when the recovery interaction finishes.

## 8. Workday Integration

### Prepare Phase

- The discard pile should be empty before a new workday begins.
- Recyclers can be hired, positioned, and augmented like other employees.
- Recyclers occupy normal employee slots.
- Existing roster, positioning, shop, and augment functionality should remain unchanged.

### Play Phase

Normal sales representatives process incoming leads.

When a normal sales interaction resolves:

```text
IF sale succeeds:
    Apply revenue
    Record successful sale

ELSE:
    Record failed interaction
    Move lead to discard pile
```

Available Recyclers automatically retrieve leads from the discard pile.

When a Recycler interaction resolves:

```text
IF recovery succeeds:
    Apply revenue
    Apply existing upsell mechanics
    Record successful recovery

ELSE:
    Record failed recovery
    Permanently remove lead
```

Continue the autonomous simulation normally.

The presence of discarded leads must not block incoming lead processing.

### Report / Review Phase

The report should distinguish:

- Total leads received
- Successful normal conversions
- Failed normal sales interactions
- Abandoned leads
- Total leads discarded during the workday
- Recycler attempts
- Successful Recycler recoveries
- Failed Recycler recoveries
- Revenue recovered by Recyclers
- Recycler utilization, if supported

Recovered sales count toward total workday revenue.

If existing reporting already tracks some of these values, reuse those statistics.

Because the discard pile resets, preserve historical discard and recovery counts in the workday report before clearing the collection.

Do not assume the live discard pile count is equivalent to the historical number of failed interactions.

Avoid double-counting leads when reporting original failures and Recycler recovery attempts.

## 9. UI Requirements

Add a minimal indicator showing the current discard pile count during Play.

Example:

```text
┌───────────────────────────────┐
│ INCOMING QUEUE:         8     │
│ LEAD DISCARD PILE:      12    │
│ TOTAL REVENUE:          $8,450│
└───────────────────────────────┘
```

The indicator should update when:

- A failed normal sale enters the discard pile.
- A Recycler retrieves a discarded lead.
- The discard pile is cleared.

Ensure the Recycler is visually identifiable as a distinct archetype.

Suggested elements:

- Recycler archetype label
- Recycling icon or visual indicator
- Normal employee stat display
- Existing busy/idle state indicators
- Sales animations when a discarded lead converts

Use the existing game's UI style.

Do not create a new screen or elaborate discard management interface.

If the project already has an appropriate statistics panel, integrate the count there.

## 10. Strategic Identity and Team Synergies

The Recycler represents a distinct tactical role.

Unlike a Closer, who specializes in converting incoming opportunities, the Recycler generates value by recovering opportunities that other employees failed to convert.

This creates new team composition strategies.

### Example Synergy: Hustler + Recycler

1. Hustlers process incoming leads quickly.
2. Some interactions fail.
3. Failed leads enter the discard pile.
4. The Recycler processes those leads.
5. Successful recoveries generate additional revenue.

This creates a team that can prioritize speed and recover some of the revenue lost through lower conversion.

### Strategic Tradeoff

A Recycler uses one of nine available employee slots.

That slot could otherwise contain a normal sales representative.

A team with very high conversion may produce too few discarded leads to keep a Recycler productive.

A team with frequent failed conversions may generate enough discarded leads to justify one or more Recyclers.

The Recycler should be situationally valuable rather than universally optimal.

## 11. Important Gameplay Constraints

The discard pile and Recycler system must not:

- Change existing conversion probabilities.
- Change interaction durations.
- Change lead assignment priority.
- Automatically retry failed sales without a Recycler.
- Allow Recyclers to process incoming leads.
- Allow normal sales reps to automatically process discarded leads.
- Allow unlimited Recycler recovery attempts.
- Return failed Recycler leads to the discard pile.
- Affect employee availability beyond normal interaction behavior.
- Persist discarded leads between workdays.
- Change existing upsell calculations.
- Cause abandoned leads to be treated as failed sales.
- Introduce new Recycler-specific stats.

Keep the implementation narrowly scoped.

## 12. Future Design Possibilities — Not Implemented

The discard pile may eventually support additional team-building synergies.

Potential examples:

**Second Chance Implant:** Gives an employee an additional opportunity to interact with discarded leads.

**Failure Analyst:** Gains a benefit when leads enter the discard pile.

**Discard Consumer:** Removes discarded leads to trigger an effect.

These are exploratory examples, not confirmed character or augment designs.

Do not implement them now.

Future mechanics must respect the confirmed Recycler recovery rules unless explicitly changed by a later design decision.

## 13. Edge Cases

Handle the following:

1. A workday with zero failed normal sales leaves the discard pile empty.
2. Multiple employees can fail interactions during the same simulation interval.
3. Each failed normal lead enters the discard pile exactly once.
4. Successful leads never enter the discard pile.
5. Queue abandonment never adds to the discard pile.
6. A Recycler remains idle if no discarded leads exist.
7. Multiple Recyclers cannot claim the same discarded lead.
8. A Recycler's failed attempt permanently removes the lead.
9. A lead cannot receive more than one Recycler recovery attempt.
10. Ending a workday clears all remaining discarded leads.
11. Starting another workday does not restore previous discarded leads.
12. The report retains accurate historical statistics after the pile is cleared.
13. Existing sales and revenue mechanics continue working.
14. Recovered sales count toward total revenue goals.
15. If the workday ends during a Recycler interaction, follow the existing unfinished-interaction handling rules without awarding an unearned sale.

## 14. Documentation

Update `decisions.md` to record the following confirmed principles:

### Daily Lead Discard Pile

- Leads that complete a normal sales interaction without converting enter a discard pile.
- Converted leads do not enter the discard pile.
- Leads abandoned before being worked do not enter the discard pile.
- The discard pile is available during the current workday.
- The discard pile resets at the end of every workday.
- Future character abilities, augments, and artifacts may interact with discarded leads.

### Recycler Archetype

- The Recycler is a confirmed employee archetype.
- Recyclers exclusively process leads from the discard pile.
- Recyclers cannot process incoming leads.
- Recyclers use the same four stat types as normal employees.
- Recyclers occupy standard sales-floor slots.
- Multiple Recyclers use existing slot priority.
- Successful Recycler conversions generate normal revenue.
- Failed Recycler conversions permanently remove the lead.
- Each lead can receive a maximum of one Recycler recovery attempt.

Update `characters.md` to include the Recycler archetype definition, its tactical role, stats, strengths, weaknesses, and relationship to the discard pile.

Preserve all existing decisions and avoid duplicating the full mechanic across documents.

## 15. Acceptance Criteria

The implementation is complete when:

- [x] Failed normal sales correctly add leads to the discard pile.
- [x] Successful sales bypass the discard pile.
- [x] Abandoned leads bypass the discard pile.
- [x] The discard pile is tracked independently of the incoming queue.
- [x] Recycler exists as a selectable employee archetype.
- [x] Recycler occupies a normal sales-floor slot.
- [x] Recycler uses the existing four stat types.
- [x] Recycler cannot receive incoming leads.
- [x] Recycler automatically receives discarded leads.
- [x] Recycler remains idle when the discard pile is empty.
- [x] Discarded leads are removed from the pile when assigned.
- [x] Multiple Recyclers cannot process the same lead.
- [x] Successful Recycler sales generate normal revenue and upsells.
- [x] Failed Recycler sales permanently remove the lead.
- [x] A lead cannot receive more than one Recycler recovery attempt.
- [x] Existing augments function on Recyclers where applicable.
- [x] The live discard count is visible during Play.
- [x] The discard pile resets every workday.
- [x] Daily reporting preserves discard and recovery statistics.
- [x] Existing sales, routing, revenue, and upsell systems remain functional.
- [x] `decisions.md` reflects the new confirmed mechanics.
- [x] `characters.md` includes the Recycler archetype.
- [ ] Relevant tests pass.

## 16. Implementation Instructions

Before changing code:

1. Inspect the existing lead model, sales interaction resolution, workday lifecycle, character architecture, and reporting systems.
2. Identify where unsuccessful interactions currently resolve.
3. Reuse existing architecture rather than introducing unnecessary systems.
4. Implement the discard pile and Recycler using the smallest clean changes possible.
5. Ensure lead routing distinguishes incoming-queue employees from discard-pile employees.
6. Add or update tests where appropriate.
7. Update `decisions.md` and `characters.md`.

After implementation, summarize:

- Files modified
- How the discard pile is stored
- Where failed leads enter the pile
- How Recycler lead assignment works
- How successful and failed recoveries resolve
- When the pile resets
- How the UI displays the count
- Tests performed
- Any unresolved implementation questions

Do not implement speculative gameplay mechanics without approval.
