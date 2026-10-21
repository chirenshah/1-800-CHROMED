# 1-800-CHROMED — Sales Slam Reward Feedback System

## Objective

Implement an end-of-day revenue tally animation called **Sales Slam**.

The purpose of this system is to create satisfying audiovisual feedback that rewards the player for successful sales during the workday.

**IMPORTANT: We do not have finalized graphical or audio assets. Build this system using Godot's native UI elements, procedural animations, placeholder shapes, and temporary sound effects.**

The system must be designed so that finalized art and audio can replace placeholders later without rewriting gameplay logic.

## 1. Gameplay Integration

1-800-CHROMED is a cyberpunk sales-team autobattler.

The player manages salespeople on a 3×3 grid. During the Play phase, salespeople automatically process leads and generate revenue.

The workday lasts approximately 15–30 seconds.

During the workday:
- Revenue accumulates in real time.
- Successful sales provide immediate feedback.
- Each completed sale is recorded with its value and salesperson identifier.

At the end of the workday:
- The Sales Slam sequence begins.
- A dedicated sales board starts at $0.
- Every completed sale is replayed as a visual impact.
- Sales are replayed in ascending order of value.
- The board displays the daily sales goal.
- The player watches the total approach the goal.
- Exceeding the goal triggers a spectacular board demolition.

**The tally animation must never add revenue to the underlying game state a second time.**

## 2. Sales Board UI

Create a placeholder sales board using Godot Control nodes.

Required elements:
- Large revenue counter
- Visible daily sales goal
- Progress bar showing percentage of goal
- Latest sale amount
- Current sale number / total sales
- Visual board surface that can shake, crack, and break
- Status indicator for tallying, goal reached, goal exceeded, and tally complete

Use simple rectangles, labels, lines, and solid colors.

Suggested temporary palette:
- Background: dark charcoal
- Revenue: neon green
- Warning: amber
- Destruction: bright yellow/orange
- Failure: muted red

The UI should remain readable during effects.

## 3. Sales Slam Animation

Each sale should produce an impact animation.

Suggested sequence:

1. Revenue amount appears outside or above the board.
2. Number accelerates toward its impact point.
3. Number collides with the board.
4. Board reacts to the impact.
5. Revenue counter increases by the sale amount.
6. Progress bar advances.
7. Impact particles appear.
8. Impact sound plays.
9. Temporary effects disappear.

Use Godot Tweens for animation.

The animation should be event-driven rather than tightly coupled to the revenue calculation.

## 4. Impact Intensity

Impact intensity must scale with sale value.

Use a tunable nonlinear mapping so large sales feel more powerful while preventing excessive shake or visual clutter.

Example placeholder formula:

`intensity = clamp(sqrt(sale_value / reference_sale_value), 0.1, 1.0)`

Expose reference sale value and intensity parameters for future balancing.

Impact intensity should influence:
- Screen shake magnitude
- Screen shake duration
- Impact sound pitch or volume
- Number scale
- Particle quantity
- Board flash intensity
- Board crack intensity

Do not hardcode sale-value thresholds into animation logic.

## 5. Tally Pacing

The entire sequence should build toward a climax.

Suggested initial timing:
- Small sale: 0.18 seconds
- Medium sale: 0.25 seconds
- Large sale: 0.4 seconds
- Goal-breaking impact: 0.8–1.2 seconds
- Final result reveal: 0.5 seconds

These are tuning placeholders, not fixed design requirements.

Target a total tally duration of approximately 3–6 seconds for a typical workday.

Use dynamic pacing for days with many sales so the sequence does not become excessively long.

Allow the player to skip or accelerate the animation.

Skipping must immediately show the correct final result and must not change revenue.

## 6. Goal Anticipation

The player must always see the sales goal and current tally.

As the tally approaches the goal, increase audiovisual tension.

Suggested thresholds:
- 50%: subtle progress feedback
- 75%: increased glow and sound intensity
- 90%: warning lights and visible board stress
- 100%: goal reached, but no demolition
- Greater than 100%: demolition triggered

These thresholds must be configurable.

The board should develop visual signs of strain as the player approaches quota.

However, these effects must not imply that the player has already exceeded the goal.

## 7. Board Demolition

The board is destroyed **only when cumulative tally revenue exceeds the daily sales goal**.

The sale that crosses the threshold triggers the demolition.

Required effects:
- Strong impact animation
- Board fracture
- Large screen shake
- Procedural debris
- Bright flash
- Distinctive demolition sound
- "QUOTA DESTROYED" announcement

Demolition intensity should also scale with the value of the goal-breaking sale.

The demolition must trigger only once per workday.

If additional sales remain, continue tallying them against the damaged board.

The final revenue amount must remain readable.

If revenue equals the goal exactly, the board remains intact.

## 8. Failure and Near-Miss Feedback

If the player finishes below the sales goal:
- The board remains intact.
- The final sale produces its normal impact.
- The tally stops.
- The shortfall is displayed.
- Audio resolves without a victory payoff.

For close misses, optionally show a large crack and a brief dramatic pause.

Do not trigger the full demolition.

## 9. Audio Architecture

Build an audio feedback controller that responds to Sales Slam events.

Audio categories:
- Small sale impact
- Medium sale impact
- Large sale impact
- Tension buildup
- Goal reached
- Board demolition
- Failure / near miss
- Final tally reveal

If usable audio assets are unavailable, use generated placeholder tones or clearly labeled temporary sounds.

Audio playback must not be required for the animation logic to function.

Provide independent volume controls for feedback effects.

## 10. Suggested Architecture

Use a modular, signal-driven structure.

Suggested components:

**SalesSlamController**
- Receives completed sales data
- Sorts sales by value
- Controls sequence timing
- Tracks displayed tally
- Determines when quota is exceeded
- Emits presentation events

**SalesBoardUI**
- Displays revenue, goal, and progress
- Handles board flashes and visual state

**SalesImpactFX**
- Handles number impacts
- Controls shake and particles
- Scales effects based on impact intensity

**SalesBoardDestructionFX**
- Handles cracking and demolition
- Uses placeholder procedural graphics

**SalesSlamAudio**
- Plays sounds in response to events
- Supports temporary audio assets

Use Godot signals to communicate between components.

Keep game-state revenue separate from the animated displayed tally.

## 11. Testing Requirements

Create a standalone test scene where the developer can trigger the Sales Slam sequence without playing a full workday.

Include test scenarios for:
- No sales
- One sale
- Multiple small sales
- One very large sale
- Revenue below quota
- Revenue exactly equal to quota
- Revenue barely exceeding quota
- Revenue greatly exceeding quota
- A near miss
- Many simultaneous or closely spaced sales
- Skipping midway through the sequence

Verify that the final tally always matches the underlying recorded revenue.

Verify that board demolition occurs exactly once and only when revenue exceeds quota.

## 12. Implementation Guidelines

- Inspect the existing Godot project architecture before implementing.
- Reuse existing sales events, phase transitions, and revenue data.
- Avoid duplicating game-state calculations.
- Do not introduce finalized art dependencies.
- Use native Godot 4.x systems where possible.
- Keep animation timing and effect intensity configurable.
- Respect pause and phase-transition behavior.
- Make the system easy to replace with finalized assets later.
- Avoid unnecessary external dependencies.

## 13. Definition of Done

The prototype is complete when:

- A workday can finish and launch the Sales Slam sequence.
- Sales visibly slam into the board in ascending value order.
- Larger sales produce stronger impacts.
- The revenue counter and progress bar update correctly.
- The player can anticipate the goal being reached.
- Exceeding quota destroys the board.
- Failing quota leaves the board intact.
- The sequence has functioning placeholder audio feedback.
- The animation can be skipped safely.
- All effects work without finalized graphical assets.

**Design priority: Game feel over visual polish.**

We want the player to anticipate the final sale hitting the board and experience a satisfying payoff when they beat quota.

Every sale deserves an impact. Beating quota deserves destruction.