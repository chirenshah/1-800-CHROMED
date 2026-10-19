# 1-800-CHROMED — Inventory Management System

## Objective

Implement an inventory management system for 1-800-CHROMED that allows players to store, equip, and move augments, items, and salespeople.

The system must integrate with the existing 3×3 sales floor, salesperson character system, augment system, and shop.

**IMPORTANT:** Inspect the existing codebase and relevant Markdown documentation before implementing anything. Reuse existing models, managers, and components wherever possible. Do not create duplicate systems or rewrite existing gameplay mechanics.

## 1. Inventory Types

Implement two separate inventories.

### Item Inventory

- Dimensions: **2 rows × 6 columns**
- Maximum capacity: **12 items**
- Stores augments and other inventory items.
- Each item occupies exactly one slot.
- Identical items do not stack.
- Each item instance must have a unique identifier.
- Equipped augments do not occupy inventory slots.
- Inventory contents persist between workdays.

### Salesperson Inventory

- Dimensions: **1 row × 6 columns**
- Maximum capacity: **6 salespeople**
- Stores inactive salespeople.
- Each salesperson occupies exactly one slot.
- Salespeople retain their stats, archetypes, and equipped augments while stored.
- Newly hired salespeople always enter this inventory.
- Inventory contents persist between workdays.

### Active Sales Floor

The existing sales floor is a **3×3 grid** with nine positions.

- Each position holds a maximum of one salesperson.
- Salespeople can move between the salesperson inventory and active board.
- Salespeople can be repositioned within the board.
- A salesperson must exist either in inventory or on the board, never both.
- Existing positioning and lead assignment mechanics must remain intact.

Maximum total salesperson ownership is 15: nine deployed and six in reserve.

## 2. Drag-and-Drop Interactions

Implement drag-and-drop functionality for inventory management.

### Salesperson Inventory → Active Board

When a player drags a salesperson from inventory onto an empty board position:

1. Validate the destination.
2. Remove the salesperson from inventory.
3. Place the salesperson in the selected board position.
4. Preserve their stats and equipped augments.
5. Update the UI and underlying game state.

If the destination is occupied, support swapping the dragged salesperson with the existing board salesperson, provided the transfer can complete without losing either character.

### Active Board → Salesperson Inventory

When dragging a salesperson from the board into inventory:

1. Check that a valid destination slot is available.
2. Remove the salesperson from the board.
3. Add them to inventory.
4. Preserve all character data and equipment.
5. Update the board and inventory displays.

If inventory is full, reject the transfer unless a valid direct swap is being performed.

### Active Board → Active Board

Allow salespeople to be dragged between positions.

- Empty destination: Move salesperson.
- Occupied destination: Swap the two salespeople.
- Preserve equipped augments and character state.
- Update positioning and lead assignment order appropriately.

### Inventory → Inventory

Allow rearranging items and salespeople within their respective inventories.

- Drag to empty slot: Move.
- Drag to occupied slot: Swap.
- Invalid destination: Cancel without modifying state.

## 3. Augment Equipment Interactions

Augments are stored in the Item Inventory until equipped.

Allow augments to be equipped to salespeople who are either:

- On the Active Board.
- In the Salesperson Inventory.

### Equipping

When an augment is equipped:

1. Validate the salesperson and available augment slot.
2. Remove the augment instance from Item Inventory.
3. Attach it to the salesperson.
4. Apply its existing stat modifiers and effects.
5. Update the UI.

Respect the existing augment-slot system, including the second slot unlocked through individual surgery.

Do not automatically unlock additional augment slots.

### Unequipping

When an augment is unequipped:

1. Check for an available Item Inventory slot.
2. Remove the augment from the salesperson.
3. Return the same augment instance to Item Inventory.
4. Remove its active stat modifiers and effects.
5. Update the UI.

If Item Inventory is full, prevent unequipping.

Do not destroy, duplicate, or reset augments during equipment transfers.

## 4. Shop Integration

Integrate the inventory system with existing purchasing and hiring functionality.

### Purchasing Items

- Purchased items enter the Item Inventory.
- Every purchased item occupies its own slot.
- Duplicate augments must remain separate instances.
- Prevent purchases if Item Inventory is full.
- Do not deduct currency when a purchase fails.

### Hiring Salespeople

- Newly hired salespeople always enter Salesperson Inventory.
- Never automatically deploy a newly hired salesperson.
- Prevent hiring if all six salesperson inventory slots are occupied.
- Do not deduct currency when hiring fails.
- Preserve existing character generation and archetype mechanics.

All transactions must be atomic.

## 5. Data Architecture

Keep inventory state independent of the UI.

Implement or extend the appropriate systems for:

- Item inventory storage.
- Salesperson inventory storage.
- Active board occupancy.
- Augment equipment.
- Shop transactions.
- Inventory persistence.

Use the project's existing architecture and naming conventions.

Each salesperson should have a persistent unique ID.

Each item instance should also have a unique ID, even if multiple instances reference the same item definition.

Do not create separate copies of salesperson data when moving characters between inventory and board.

A transfer must update the authoritative game state rather than maintaining disconnected UI copies.

## 6. UI Requirements

Create a functional inventory interface that can be integrated into the existing game.

### Item Inventory UI

Display a 2×6 grid containing:

- Item icons.
- Empty slots.
- Hover information or tooltips.
- Visual feedback for valid and invalid drop targets.

### Salesperson Inventory UI

Display a 1×6 grid containing:

- Salesperson portraits or existing character sprites.
- Empty slots.
- Character names or identifying information.
- Equipped augment indicators.
- Drag-and-drop support.

### Board Integration

Support dragging salespeople between inventory and the existing 3×3 sales floor.

Do not replace or redesign the existing sales floor.

### Visual Design

Follow the existing cyberpunk visual style.

Reuse existing sprites, components, colors, and UI conventions wherever possible.

Provide clear visual feedback when inventory is full or a transfer is invalid.

## 7. Prepare Phase Integration

Inventory management should be available during the Prepare phase.

Players should be able to:

- Deploy salespeople.
- Recall salespeople.
- Rearrange the active board.
- Equip and unequip augments.
- Rearrange inventory contents.

Prevent roster, positioning, and equipment changes during the autonomous Play phase.

**Important:** Do not tightly couple inventory logic to the current Prepare phase layout.

We may redesign the Prepare phase later. Inventory management should remain functional without requiring changes to its underlying data model.

## 8. Persistence

Inventory and equipment state must persist between workdays.

Preserve:

- Item inventory contents and slot positions.
- Salesperson inventory contents and slot positions.
- Active board assignments.
- Salesperson stats and archetypes.
- Equipped augments.
- Augment slot unlocks.
- Unique instance IDs.

Integrate with the existing save/state management approach where available.

## 9. Error Handling

Ensure the following cases are handled safely:

- Item inventory full.
- Salesperson inventory full.
- Active board full.
- Invalid drag destination.
- Attempting to equip an augment with no available equipment slot.
- Attempting to unequip when item inventory is full.
- Attempting to hire when salesperson inventory is full.
- Attempting to purchase when item inventory is full.
- Attempting to move or equip the same instance twice.
- Canceling a drag operation.

Invalid operations must leave the original state unchanged.

## 10. Testing and Acceptance Criteria

Verify the following:

- [ ] Item Inventory displays exactly 12 slots in a 2×6 layout.
- [ ] Salesperson Inventory displays exactly six slots in a 1×6 layout.
- [ ] Active Board remains 3×3.
- [ ] Newly hired salespeople enter inventory.
- [ ] Newly purchased augments enter item inventory.
- [ ] Identical augments occupy separate slots.
- [ ] Salespeople can move between inventory and board.
- [ ] Salespeople can swap board positions.
- [ ] Inventory contents can be rearranged.
- [ ] Augments can be equipped to active and inactive salespeople.
- [ ] Equipped augments stay attached when salespeople move.
- [ ] Unequipped augments return to Item Inventory.
- [ ] Full inventories prevent invalid transactions.
- [ ] No items or salespeople are duplicated or lost.
- [ ] Inventory and board state persist between workdays.
- [ ] Existing lead assignment and sales simulation continue functioning.
- [ ] Inventory interactions are disabled during Play.

## 11. Implementation Constraints

- Use the existing game engine, programming language, and project conventions.
- Prefer extending existing systems rather than replacing them.
- Keep business logic separate from visual components.
- Avoid introducing unnecessary dependencies.
- Do not modify existing salesperson stats, archetype definitions, augment effects, or lead-processing formulas unless required for integration.
- Do not introduce inventory upgrades, item stacking, selling, firing, or discarding mechanics at this time.
- Do not redesign the Prepare phase.

## 12. Deliverables

1. Implement the inventory data structures and management logic.
2. Implement the inventory UI.
3. Implement drag-and-drop between inventories and the active board.
4. Integrate equipment and shop transactions.
5. Add appropriate tests.
6. Update existing project documentation, including `decisions.md`, to reflect confirmed inventory rules.
7. Provide a summary of changed files and any outstanding issues.

Before implementing, inspect the current project structure and briefly identify the existing systems that will be reused.

**Goal:** Deliver a functional inventory management foundation that works with our existing game while allowing us to redesign the Prepare phase later without rewriting inventory logic.