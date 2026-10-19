# 1-800-CHROMED — Sample Character Augments

## Objective

This document defines the implemented basic augment system for 1-800-CHROMED, a cyberpunk call-center autobattler.

Players purchase augments during the **Prepare / Shop phase** and equip them onto sales representatives to improve their performance during automated sales calls.

For this initial implementation, augments should only modify existing character stats. Do not introduce new stats or complex gameplay mechanics.

## Augment Rules

- Every character starts with **1 augment slot**.
- Characters can unlock a **second augment slot** through individual surgery.
- Surgery costs **$300** and is a permanent upgrade to that character.
- Each augment modifies exactly **one character stat**.
- Augments are purchased using the department budget.
- Augments can be equipped, unequipped, and transferred between characters during Prepare.
- Augment effects apply automatically during Play.
- Augments cannot be changed during an active workday.
- All augment stat bonuses are additive to the character's base stat.
- Augment prices are fixed for this initial implementation.
- Do not implement augment synergies, upgrades, or negative side effects yet.

## Sample Augments

| ID      | Name                 | Stat Modified | Effect | Price | Rarity    |
| ------- | -------------------- | ------------- | ------ | ----- | --------- |
| AUG_001 | Silver Tongue™       | Conversion    | +10%   | $100  | Common    |
| AUG_002 | Neural Overclock     | Speed         | +15%   | $125  | Common    |
| AUG_003 | Corporate Charm Chip | Conversion    | +15%   | $175  | Uncommon  |
| AUG_004 | Synaptic Accelerator | Speed         | +25%   | $225  | Rare      |
| AUG_005 | Persuasion Matrix    | Conversion    | +25%   | $300  | Rare      |
| AUG_006 | Quantum Dialer       | Speed         | +40%   | $450  | Legendary |

**Important:** `Conversion` and `Speed` are conceptual labels. Claude should map these to the existing character stat identifiers in the project rather than creating duplicate stats.

## Stat Behavior

### Conversion

Improves a character's probability of successfully closing a sale.

Example:

- Base conversion chance: 40%
- Equipped Silver Tongue: +10 percentage points
- Final conversion chance: 50%

Use percentage-point bonuses for conversion, not multiplicative percentage increases.

Clamp the final conversion probability to the valid range supported by the existing game.

### Speed

Improves how quickly a character completes sales interactions.

Example:

- Base call duration: 5 seconds
- Equipped Neural Overclock: +15% speed
- Effective call duration: `5 / 1.15 = 4.35 seconds`

Apply speed bonuses to the existing call-duration calculation rather than introducing a separate timing system.

Speed bonuses stack additively as percentage increases to processing speed: two equipped +15% Speed augments produce a 1.30× speed rate, so the original duration is divided by 1.30. They do not change the character's authored 1–5 baseline Speed.

## Shop Behavior

During the Prepare phase:

1. Display three randomly selected augments available for purchase.
2. Display each augment's name, stat bonus, rarity, and price.
3. Allow purchases when the player has sufficient budget.
4. Deduct the purchase price from the department budget.
5. Add purchased augments to the player's inventory.
6. Allow the player to equip augments onto characters with available slots.
7. Recalculate character stats when equipment changes.

Purchased augments should persist between workdays.

The initial department budget is **$500**. Workday revenue is added to that budget when the day closes. The shop rolls three distinct offers at the start of each Prepare phase; an offer can be purchased once that day. Inventory, equipment, surgery, and budget persist between workdays in the current game session.

## Implementation Requirements

- Inspect the existing character stat system before implementing augments.
- Reuse existing stats and simulation calculations.
- Define augments as data rather than hardcoding their effects individually.
- Ensure that equipped augment bonuses are applied exactly once.
- Avoid permanently modifying base character stats when equipping augments.
- Preserve existing character behavior when no augments are equipped.
- Keep the augment system extensible for future abilities and synergies.
- Do not modify unrelated game systems.

## Acceptance Criteria

- [x] Augments appear in the Prepare-phase shop.
- [x] Each augment displays its price, stat bonus, and rarity.
- [x] Players can purchase augments with available budget.
- [x] Characters can equip augments within their slot limits.
- [x] Equipping an augment modifies the correct existing character stat.
- [x] Unequipping restores the character's original effective stat.
- [x] Surgery unlocks a second character slot for $300.
- [x] Two-slot characters can receive bonuses from two augments.
- [x] Bonuses affect actual automated sales outcomes.
- [x] Augments persist correctly between workdays.
- [x] Existing gameplay continues working without equipped augments.

## Scope

Implement only the six sample augments and their single-stat effects.

Do not implement augment combinations, special triggered abilities, employee recovery periods, or additional augment categories in this iteration.
