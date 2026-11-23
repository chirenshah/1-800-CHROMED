# 1-800-CHROMED — Office Background & Desk Row Implementation

## Objective

Implement our new cyberpunk office background and three-row cubicle artwork in the existing Godot project.

This is a visual implementation task. Preserve all existing gameplay logic, employee management, drag-and-drop functionality, lead routing, and phase transitions.

Do not redesign unrelated UI.

## 1. Inspect the existing project

Before implementing anything:

1. Locate the existing sales floor scene and scripts.
2. Identify how the 3×3 employee grid is currently rendered.
3. Identify how employee positions are calculated.
4. Identify how drag-and-drop operates.
5. Identify the existing Prepare and Workday layouts.

Reuse the existing scene structure wherever practical.

Do not create a second, competing sales floor system.

## 2. Import the new assets

Two PNG files will be provided:

- `office_background.png` — 1280×720
- `desk_row.png` — 670×150

Place them in a suitable project directory, such as:

```text
res://assets/sales_floor/
    office_background.png
    desk_row.png
```

Verify the actual image dimensions and transparency before implementation.

The office background is opaque.

The desk row must support alpha transparency.

Use appropriate texture filtering to preserve visual clarity.

## 3. Implement the office background

Display `office_background.png` behind the entire sales floor.

Requirements:

- Match the existing 1280×720 game coordinate system.
- Preserve the image's aspect ratio.
- Do not add scrolling.
- Do not tile or repeat the background.
- Do not add the game's logo or title over the artwork.
- Preserve the empty right-side area reserved for a future sales board.

The background must not intercept mouse interactions with employee slots.

## 4. Implement the sales floor

The sales floor occupies a 700×488 region.

Create a configurable container for the sales floor and its nine employee positions.

The floor contains three horizontal rows of three cubicles.

Use three instances of the same `desk_row.png` asset.

Each desk row should render at approximately 670×150 pixels.

Center the desk rows horizontally within the 700-pixel sales floor.

Initial horizontal offset:

```gdscript
const FLOOR_WIDTH = 700
const FLOOR_HEIGHT = 488

const DESK_ROW_WIDTH = 670
const DESK_ROW_HEIGHT = 150

const DESK_ROW_X = 15
```

These values are initial layout targets. Adjust vertical offsets after testing the assembled scene.

## 5. Rendering hierarchy

The intended visual hierarchy is:

```text
OfficeBackground
    |
SalesFloor
    |
    +-- BackRow
    |     +-- EmployeeSlots 1–3
    |     +-- DeskForeground
    |
    +-- MiddleRow
    |     +-- EmployeeSlots 4–6
    |     +-- DeskForeground
    |
    +-- FrontRow
          +-- EmployeeSlots 7–9
          +-- DeskForeground
```

Render rows from back to front.

Within each row:

1. Render employees and their chairs.
2. Render the desk foreground above them.

The desks should partially obscure the employees' lower bodies.

Do not render employees in front of the desk panels.

Do not add separate rear cubicle walls.

## 6. Character positioning

Each desk row has three employee anchor positions.

Start with approximate horizontal centers:

```gdscript
const EMPLOYEE_X_OFFSETS = [
    112,
    335,
    558
]
```

These are measured relative to the left edge of the desk-row artwork.

They are provisional and must be checked visually.

Position employees so their upper bodies are visible above the desk surfaces.

Do not change employee sprite dimensions or animation frames simply to compensate for incorrect positioning.

Preserve existing employee drag-and-drop behavior.

Empty employee slots should show only the desk and monitor.

## 7. Vertical positioning

All three rows must fit inside the 488-pixel sales floor height.

Begin with a non-overlapping layout using approximately 150 pixels per row, leaving the remaining space for margins.

Then adjust row spacing and overlap to achieve the intended perspective.

Important:

- The back row appears highest on screen.
- The middle row appears below the back row.
- The front row appears lowest.
- Front rows must render over rear rows wherever their artwork overlaps.
- Character sprites must remain visible.
- No part of the cubicle layout should overflow the designated sales floor viewport.

Keep all row positions configurable rather than scattering hardcoded values across multiple scripts.

## 8. Preserve existing gameplay

Do not modify:

- Employee hiring or inventory.
- Employee placement rules.
- Fixed slot priority 1–9.
- Lead routing.
- Sales calculations.
- Augment systems.
- Company cash or revenue.
- Workday progression.
- Prepare, Workday, or Review transitions.

The visual cubicle positions must map directly to the existing logical employee slots.

## 9. Future sales board

The right side of the office background contains an empty framed area.

Leave it empty for now.

Do not implement a new sales board as part of this task.

Do not hardcode revenue or quota values into the background.

Preserve existing scoreboard gameplay logic and avoid breaking any current revenue displays.

## 10. Implementation sequence

Work incrementally:

1. Import both PNG assets.
2. Display the office background.
3. Add one desk row.
4. Position three employee slots behind it.
5. Test employee rendering and drag-and-drop.
6. Add the middle and front rows.
7. Verify all nine employee slots.
8. Check row overlap and perspective.
9. Test Prepare and Workday phases.
10. Confirm that existing gameplay remains functional.

## 11. Acceptance criteria

Implementation is complete when:

- The background displays correctly.
- All three desk rows are visible.
- The sales floor fits within 700×488.
- All nine employee slots align with the desks.
- Employees render behind desk foregrounds.
- Drag-and-drop still works.
- Existing character animations still work.
- The right-side sales-board area remains empty.
- No unwanted scrollbars appear.
- No gameplay systems have been changed.

## 12. Final deliverables

After implementation, provide:

1. A summary of files created or modified.
2. The final desk-row positions.
3. The final employee anchor coordinates.
4. Any assumptions or compromises made.
5. A screenshot of the assembled sales floor if available.

Do not proceed to redesign other UI components without approval.