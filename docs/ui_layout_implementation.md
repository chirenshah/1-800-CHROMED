# 1-800-CHROMED — UI Layout Implementation

## Objective

Implement the updated screen layout for 1-800-CHROMED.

The game uses a reference resolution of **1280 × 720 (16:9)**.

We want a consistent screen structure that supports our three gameplay phases:

1. Prepare
2. Workday
3. Review

**For this implementation, focus on the Prepare and Workday layouts. Do not implement the panel transition animations yet.**

Preserve existing gameplay systems, simulation logic, and UI functionality wherever possible.

---

## 1. Overall Screen Layout

Divide the screen into three horizontal regions:

| Region | Position | Width | Height | Screen Height % |
|---|---|---|---|---|
| Header | Top | 1280 px | 72 px | 10.0% |
| Main Workspace | Middle | 1280 px | 488 px | 67.8% |
| Bottom Panel | Bottom | 1280 px | 160 px | 22.2% |
| **Total** | | **1280 px** | **720 px** | **100%** |

The main workspace is divided vertically into:

| Region | Width | Height | Screen Width % |
|---|---|---|---|
| Main Content | 1120 px | 488 px | 87.5% |
| Right Sidebar | 160 px | 488 px | 12.5% |

The bottom panel is divided into two equal-width sections during Prepare.

Use these dimensions as the reference layout. The interface should scale proportionally at other 16:9 resolutions.

Do not introduce scrollbars into the primary screen layout.

## 2. Header — 1280 × 72

The header remains visible during both Prepare and Workday.

It should display the existing game information, including:

- Company / game identity
- Current month and workday
- Company cash
- Daily revenue goal
- Current write-ups

Reuse existing data bindings and gameplay values.

Do not create duplicate financial counters or separate sources of truth.

The header should maintain a consistent position and size across phases.

## 3. Prepare Phase — Main Content

**Dimensions: 1120 × 488**

This is the primary workspace for managing the company.

It contains three selectable views:

### Sales Floor

Displays the existing 3×3 sales floor.

Players should be able to perform their existing management actions, including positioning employees and equipping augments.

Preserve existing drag-and-drop functionality.

The Sales Floor should fit within the 1120 × 488 content region without overlapping the sidebar or bottom inventory.

### Store

Displays the existing Store interface.

The Store currently needs room for:

- Four randomly generated Common, Uncommon, or Rare augment offers
- One Epic or Legendary augment offer
- Two salesperson recruitment offers
- Reroll button costing $100

Preserve the existing shop logic, purchase functionality, and reroll behavior.

The Store must fit within the main content region.

### Calendar

Create a Calendar view as the game's progression interface.

The game has a 60-workday quarter consisting of three 20-workday months.

The Calendar should provide space to display:

- Completed workdays
- Current workday
- Upcoming workdays
- Future challenges and modifiers
- Monthly boss encounters
- Quarterly end boss

For now, use a month-at-a-time calendar layout as a starting point, with navigation between months.

The Calendar is a progression interface, not a real-world date picker.

Do not implement new progression mechanics or generate new challenges as part of this UI task.

Use existing progression data where available and placeholders where necessary.

## 4. Prepare Phase — Right Sidebar

**Dimensions: 160 × 488**

Position the navigation menu on the right side of the main workspace.

Arrange the following buttons vertically, in this order:

1. Sales Floor
2. Store
3. Calendar

Place a visually distinct **BEGIN WORKDAY** button at the bottom of the sidebar.

The Begin Workday button is a gameplay action, not a navigation tab.

### Navigation behavior

- Clicking Sales Floor displays the Sales Floor in the main content area.
- Clicking Store displays the Store.
- Clicking Calendar displays the Calendar.
- The currently selected view should be visually highlighted.
- Switching views must not reset inventory, purchases, employee positions, or other gameplay state.

The Store should be the default selected view when entering the Prepare phase.

### Begin Workday behavior

Pressing Begin Workday should invoke the existing phase-advance functionality.

Before beginning the Workday:

- Use existing validation rules.
- Commit the current team configuration.
- Disable preparation-only interactions.
- Ensure the Sales Floor is the displayed main view.

Do not introduce additional confirmation dialogs unless existing gameplay requires them.

## 5. Prepare Phase — Persistent Bottom Inventory

**Dimensions: 1280 × 160**

The inventory must remain visible at the bottom of the screen throughout the entire Prepare phase.

It must remain visible while switching between Sales Floor, Store, and Calendar.

Divide it into two side-by-side sections.

### Left: Reserve Employees

**Dimensions: 640 × 160**

Display the reserve employee inventory.

Capacity: **6 employees**

Layout: **1 row × 6 columns**

Requirements:

- Each employee occupies an individual slot.
- Display existing employee portraits or placeholders.
- Preserve employee selection and drag-and-drop functionality.
- Allow employees to move between reserve inventory and active Sales Floor positions using existing rules.
- Newly hired employees go into the reserve inventory.

### Right: Augments & Items

**Dimensions: 640 × 160**

Display the existing item and augment inventory.

Capacity: **12 slots**

Layout: **2 rows × 6 columns**

Requirements:

- Each augment or item occupies its own slot.
- Preserve existing item and augment interactions.
- Allow augments to be equipped onto employees using existing rules.
- Newly purchased augments and items appear in this inventory.
- Preserve inventory capacity restrictions.

Both inventory sections should have clear headings and visually distinct slot boundaries.

Use the full available panel area while allowing for reasonable internal padding and spacing.

## 6. Workday Phase — Main Content

**Dimensions: 1120 × 488**

The Workday uses the same Sales Floor content region as Prepare.

The existing 3×3 sales floor remains in the same position and scale.

During Workday:

- Employee positioning is locked.
- Augment management is disabled.
- Store interactions are unavailable.
- The sales simulation runs autonomously.
- Employee animations and lead activity remain visible.

Do not enlarge or reposition the Sales Floor merely because the phase changes.

Maintain consistent artwork positioning between Prepare and Workday.

## 7. Workday Phase — Right Scoreboard

**Dimensions: 160 × 488**

During Workday, the right navigation sidebar is replaced by the live revenue scoreboard.

The scoreboard occupies the exact same region as the Prepare navigation.

The scoreboard should support:

- Current workday revenue
- Daily revenue goal
- Progress toward the revenue goal
- Existing sales feedback and scoreboard behavior

Revenue must update from the existing simulation state.

Preserve the previously established scoreboard behavior: sales accumulate during the workday, and the end-of-day tally will eventually support dramatic sale impacts and destruction of the scoreboard only when the revenue goal is exceeded.

**Do not implement new scoreboard destruction or impact animations yet.**

For now, prioritize making the scoreboard fit correctly within the 160 × 488 region.

Do not change the sidebar width to accommodate future effects.

## 8. Workday Phase — Bottom Lead Queue

**Dimensions: 1280 × 160**

During Workday, the bottom inventory is replaced by the Lead Queue interface.

The Lead Queue occupies the same region as the Prepare inventory.

It should display the existing incoming lead queue and relevant lead activity information.

Requirements:

- Display leads waiting to be assigned.
- Preserve existing FIFO queue behavior.
- Reflect lead assignment and expiration using existing simulation state.
- Do not change lead-processing mechanics.
- Do not introduce manual lead assignment.

Use the available 1280 × 160 region for the queue interface.

The exact lead-card presentation can be refined later.

## 9. Phase-Specific Layout Summary

| Region | Prepare | Workday |
|---|---|---|
| Header | Company information | Company information |
| Main Content | Sales Floor / Store / Calendar | Active Sales Floor |
| Right Sidebar | Navigation + Begin Workday | Revenue Scoreboard |
| Bottom Panel | Employees + Augments | Lead Queue |

The header and overall region dimensions remain consistent.

Only the content and available interactions change between phases.

## 10. Future Transition Animation Requirements

We will implement transitions in a separate task.

For now, structure the UI so the following animations can be added later.

### Right Sidebar

When Begin Workday is pressed, the Prepare navigation menu will eventually **slide horizontally to the right**, off-screen.

This will reveal the scoreboard behind it.

### Bottom Inventory

The Prepare inventory will eventually **slide vertically downward**, off-screen.

This will reveal the Lead Queue underneath it.

### Important

Do not implement these animations yet.

However, structure the panels so they can be layered and animated independently without requiring a major UI refactor.

The scoreboard and Lead Queue should already exist in their intended screen regions.

## 11. Technical Implementation Guidance

- Use the project's existing UI framework and architecture.
- Preserve existing gameplay systems and state management.
- Separate UI presentation from simulation logic.
- Keep layout dimensions centralized as constants or configurable values.
- Avoid hardcoded positions scattered across multiple files.
- Use clipping or appropriate containers to prevent UI elements from rendering outside their intended regions.
- Keep the entire interface within the 1280 × 720 reference viewport.
- Avoid vertical and horizontal scrollbars in the main game interface.
- Preserve existing drag-and-drop interactions.
- Ensure buttons and inventory slots remain large enough for reliable mouse interaction.
- Keep the existing visual theme consistent with the game's cyberpunk corporate aesthetic.

Do not redesign existing art assets as part of this task.

## 12. Acceptance Criteria

The implementation is complete when:

- [ ] The layout fits within 1280 × 720 without unwanted scrolling.
- [ ] The header occupies the top 72 px.
- [ ] The main workspace occupies 488 px vertically.
- [ ] The right sidebar occupies 160 px horizontally.
- [ ] Sales Floor, Store, and Calendar are accessible from the right sidebar.
- [ ] Begin Workday is positioned at the bottom of the right sidebar.
- [ ] The Store is the default Prepare view.
- [ ] Reserve Employees are visible in the bottom-left panel.
- [ ] Augments & Items are visible in the bottom-right panel.
- [ ] The inventory remains visible across all Prepare views.
- [ ] Employee and augment inventory capacities remain unchanged.
- [ ] Workday displays the Sales Floor in the same main content region.
- [ ] Workday displays the Scoreboard in the right sidebar region.
- [ ] Workday displays the Lead Queue in the bottom panel region.
- [ ] Existing gameplay and drag-and-drop functionality are preserved.
- [ ] No new panel animations have been implemented.

## Implementation Priority

1. Establish the screen regions and dimensions.
2. Implement the Prepare navigation sidebar.
3. Position the persistent bottom inventory.
4. Integrate existing Sales Floor and Store views.
5. Add the Calendar view.
6. Implement the Workday panel arrangement.
7. Verify existing functionality and layout at 1280 × 720.

**Do not expand the scope into new gameplay mechanics, progression systems, or transition animations.**

Once this layout is working, we will handle the Prepare-to-Workday animations separately.
