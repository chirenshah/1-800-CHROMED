# Player persona: The thoughtful manager

Last updated: October 17, 2026

**Project:** 1-800-CHROMED / Cyberpunk Call Center  
**Status:** Working audience hypothesis to validate through playtests.

This persona describes who we intend to build for. It draws on the current game concept and comparable games. Confirmed mechanics and open decisions remain in [decisions.md](decisions.md); the recommendations here guide design discussions.

## Who we are building for

**A PC management and strategy player who enjoys assembling a complementary team, understanding its performance, and making changes that improve the business.**

Their central motivation, expressed as an illustrative player statement:

> “I want to discover what this team could do, work out what is holding it back, and see my decisions make a difference.”

They enjoy hiring, comparing abilities, finding useful combinations, and deciding where limited resources will help most. They like watching an autonomous operation when its behavior gives them something useful to learn. They appreciate time to pause and think.

They are willing to read statistics when those statistics help answer a decision. They should be able to learn the game without professional sales or management knowledge. Age, gender, occupation, and income are not part of this initial targeting hypothesis.

## What they want to feel

- **Clever:** An overlooked employee becomes valuable in the right team.
- **Responsible:** The floor succeeds or struggles for reasons connected to their choices.
- **Attached:** Employees become recognizable people with strengths, limitations, and memorable contributions.
- **Curious:** A new customer need or business problem gives them a fresh combination to explore.
- **Capable:** Reports help them understand a setback and identify a plausible next move.

The main satisfaction is: **“I understood the problem, changed my approach, and built a better team.”**

## How the workday should serve them

| Phase | The player's question | Experience to aim for |
| --- | --- | --- |
| Prepare | “What should I change, and why?” | Compare understandable options and make a meaningful choice about the team, available enhancements, or lead sources. |
| Play | “Is my plan working?” | Watch employees operate independently, notice useful signals, and pause to inspect what is happening. |
| Report | “What explains the result?” | Recognize important contributions and bottlenecks, then form a plan for the next workday. |

The exact preparation controls, report contents, and actions available while paused still need design. This persona gives us questions those systems should help the player answer.

## A moment worth building toward

Illustrative scenario; the employee roles and reporting details below are proposals:

The player hires an inexpensive employee whose individual sales numbers look weak. After a disappointing workday, they notice that their strongest closer spends too much time handling poorly matched leads. They try the new employee in a qualification role and observe the effect on the closer's results.

The report provides enough evidence to evaluate whether that change helped. The player starts to value the new employee for their contribution to the team. When a later revenue milestone changes customer needs, they have a reason to rethink the setup.

This is the intended “Moneyball for a call center” discovery: an employee's value depends on the situation and the people around them.

## Design guidance

These are recommendations to test with the primary persona.

| Player need | Design implication |
| --- | --- |
| Meaningful team composition | Give employees different ways to contribute. Test whether several combinations can succeed. |
| Understandable consequences | Explain enough of the outcome for the player to connect a decision with its likely effect. Help them distinguish a recurring weakness from an unlucky result. |
| Thoughtful planning | Preserve autonomous routine work and a usable pause. Put the player's attention on consequential management choices. |
| Interesting investment | Explore cybernetic enhancements with situational benefits and costs. Make their expected effects understandable before purchase. |
| Reasons to adapt | Let growth introduce new demands that reward reconsidering the team. Give the player a fair opportunity to understand those demands. |
| A manageable learning curve | Introduce a small set of useful information first, then add complexity as the player learns. |
| A floor worth observing | Use readable employee states and visual feedback to connect the office artwork with the simulation. |

The nine-seat floor should help the player understand the whole team. Each employee needs enough visibility for the player to recognize their role and contribution.

## What would frustrate this player

- Outcomes they cannot explain well enough to act on.
- One obvious best employee, enhancement, or team composition in every situation.
- Repetitive manual lead assignment or approvals required to keep the floor operating.
- Long periods of watching activity without learning anything or making progress toward a useful decision.
- Reports full of numbers that do not help explain performance.
- Workplace jargon introduced without a clear explanation.
- Difficulty increases that feel arbitrary or leave no plausible way to respond.

## Audience priorities and comparisons

**Primary:** Players motivated by team composition, management decisions, and improving an autonomous operation.

**Secondary:** Players drawn to business growth, distinctive employee personalities, cyberpunk settings, or workplace humor. These interests may help attract them; playtests should establish whether they also enjoy the core management loop.

Useful places to look for comparable interests:

- [Teamfight Manager](https://store.steampowered.com/app/1372810/Teamfight_Manager/): choosing complementary team members and strategies, with smart combinations compensating for individual weaknesses.
- [Software Inc.](https://store.steampowered.com/app/362620/Software_Inc/): company management, employee development, and improving an operation.
- [Two Point Hospital](https://store.steampowered.com/app/535930/Two_Point_Hospital/): staff traits, operational bottlenecks, and characterful management.

These comparisons support the audience hypothesis. They do not establish audience overlap or demand for this game.

## A positioning statement to test

**Build a crew of misfit salespeople, augment their abilities, and guide a cyberpunk call center through a 60-workday quarter.**

Show the player a concrete decision and its consequence: a useful hire, a surprising combination, or an enhancement that changes how the team handles customers. Use the office art to make those people and decisions inviting and readable.

## How we will validate the persona

Recruit an initial small group of players who can describe enjoying team composition or business management in games. Include players with no sales background.

Observe whether they can:

1. Explain why they chose an employee or enhancement.
2. Identify something useful while watching the autonomous floor.
3. Use a report to propose a specific change for the next day.
4. Recognize an employee's contribution beyond their individual revenue.
5. Remain interested when a new demand makes them reconsider their team.

Ask what felt satisfying, confusing, or tedious, and what they would try next. Pay particular attention to whether the game supports an experiment they want to run.

Revise this document when observed behavior challenges the hypothesis. Exact session length, preferred information depth, tolerance for randomness, and desired business complexity remain questions for testing.

## Using this persona during development

When considering a feature, ask:

> “How does this help the player make, observe, or understand a meaningful management decision?”

Features can also earn their place by making employees memorable, improving readability, or strengthening the setting. For the first playable version, prioritize a complete decision-and-feedback loop that this player wants to repeat.
