# 1-800-CHROMED

A cyberpunk call center management game set in 2189. Civilization wasn't destroyed; it was acquired. **Your body. Our business.** Design decisions are recorded in [decisions.md](decisions.md), narrative canon in [docs/WORLD.md](docs/WORLD.md), and the opening's script and implementation in [docs/OPENING_CINEMATIC.md](docs/OPENING_CINEMATIC.md). The intended audience and playtest hypotheses are described in [player-persona.md](player-persona.md).

## Open and run

This project uses **Godot 4.7.2 Standard** and **GDScript**, with the **Compatibility** renderer for 2D/UI development. No Python environment, .NET SDK, add-ons, or export templates are needed to work in the editor.

1. Open Godot and choose **Import** in the Project Manager.
2. Select `project.godot` in this folder, then choose **Import & Edit**.
3. Press **F5** (or the Run Project button) to open the main menu. On a Mac, you may need **Fn + F5**.
4. Press **F8** (or the Stop button) to stop it.

Choose **New Quarter** to watch the roughly 75-second cinematic, then meet Nina on the first-day floor. Click **Skip intro**, or press **Esc**, **Enter**, or **Space** to go straight to that floor. A three-step guide explains Nina's automatic calls, the target, and the shift; **Start First Shift** begins day one before the Store opens. Later days use normal Prepare, Play, and Report views. **Pause** freezes arrivals and call progress. The report separates handled calls from calls still waiting or unfinished at close. **Main Menu** returns from any workday screen; leaving during Play asks for confirmation because the current shift is not saved.

The game autosaves after each completed workday, including its report and pending reward. **Resume** loads that checkpoint; resolving the reward or changing the team updates it. Quitting during a shift returns to the latest checkpoint. **New Quarter** warns when a saved quarter exists; the old save is replaced when the new quarter completes its first day. Settings controls music for the current session.

Background music starts with the opening and continues through the sales floor, including while the workday is paused. Use **Music: On/Off** in the opening or workday to mute or restore it. The starting level is -18 dB; the session control does not save a preference to disk.

After the guided first day, use **Team** during Prepare to select a workstation, hire or assign a colleague, and compare effective Close, Speed, Upsell, Talk, and Stamina. **Upgrades** holds the shop and equipment; **Details** holds character descriptions. Installed augments are permanent; replacing one requires confirmation and destroys the old copy. Moving an already seated colleague swaps the two occupants, or vacates their previous seat if the destination is empty. Assigning a reserve colleague sends the selected seat's occupant to reserve; **Recall** opens the seat. At least one employee is required to start. Assignments, hiring, and inventory changes lock during Play (including pause) and Report, then carry into the next Prepare phase and autosave checkpoint.

The **ITEMS** and **SALESPEOPLE** buttons next to the phase tabs open the 2×6 item inventory and 1×6 salesperson reserve. Drag salespeople between reserve and the board, drag augments onto any owned salesperson to equip, and rearrange either grid. Only Nina is owned at the start; every other candidate, including Zip and Ada, can be hired for $100 into reserve.

Employee details and cards show daily upkeep. Upkeep defaults to **$100 per hired employee per completed workday** (`DEFAULT_DAILY_UPKEEP` in `scripts/employee_roster.gd`); individual values can be overridden with `daily_upkeep` in `data/planning_roster.tres`. Bench employees cost the same as active employees. Prepare shows projected floor/bench upkeep, available cash, debt, and current payroll risk. Cash is the existing $500 department budget and pays for hiring, augments, surgery, and payroll. At report, gross sales pay current upkeep first, then old debt; any unpaid current upkeep carries forward. A missed daily revenue target or unpaid current upkeep issues one shared write-up per day; three write-ups terminate the run. Use the employee **Details** view to fire a selected floor or reserve employee during Prepare; confirm carefully, as the employee cannot return and their installed augments are lost. There is no severance or refund.

The planner offers all **19 employees** from [docs/characters.md](docs/characters.md), with nine available seats. Nina starts in seat 01; seats 02–09 are open and the remaining 18 employees can be hired. Every employee has active persona-based stats: **Speed**, **Conversion**, **Stamina (continuous calling hours)**, **Upsell Chance**, and **Upsell Multiplier**. Augments preserve fractional modified stats internally; only actual probability rolls clamp Conversion/Upsell Chance to 0–100%. The shared handling base is 18 seconds (Zip takes 3.6 seconds per call, Nina 4.5 seconds, Victoria 18 seconds without modifiers); values are prototype balance. Scrap is the Recycler: it takes only leads discarded after failed normal interactions and gets one recovery attempt per lead. Augments now include position/dependency effects, call-progress changes, event cascades, temporary buffs, and daily rewards. A pending reward must be claimed, directly installed, or skipped before the next workday. Prototype fixture values are not finalized content balance. Full save-game persistence and other employee-specific conditional abilities remain future work.

To work directly on gameplay, open `scenes/main.tscn` and press **F6**, set `chromed/opening/enabled` to `false` in Project Settings, or launch with `-- --skip-opening`. To preview only the opening, open `scenes/opening.tscn` and press **F6**. Copy and timing are editable on `data/opening_sequence.tres` in the Inspector.

The queue prototype routes incoming calls FIFO to the first available normal representative in fixed row-major priority, seats 1–9, skipping empty, busy, and Recycler seats. Recyclers use the same priority to take discarded leads; normal representatives never take discards. A failed normal interaction enters the daily discard pile, while success earns revenue and queue abandonment remains separate. A Recycler claims each discarded lead immediately for at most one timed recovery attempt; recovered sales use the normal revenue and upsell rules and count toward total revenue. The live pile count appears during Play, and the report separates normal and recovery outcomes, recovered revenue, and Recycler utilization. Prepare moves are available only before Play; the lineup locks through Play, including pause, and Report. Calls arrive individually after a uniformly random delay of **0.75–1.5 seconds**, including the first call after opening. Each arrival draws a fresh delay; arrivals are not restricted to tick boundaries. The workday Timer advances one simulation clock to the next arrival, completion, patience deadline, or tick boundary. At a shared deadline, the model completes active calls, abandons expired waiting leads, receives the arrival, then dispatches FIFO and eligible Recycler recoveries. Default tuning is 0.75 simulation seconds per tick, a 36-second workday representing 12 in-game hours, and six seconds of waiting patience. One in-game hour is three real seconds; the header clock shows in-game hours and minutes during the shift. Stamina drains only while on a call; an exhausted rep finishes the call, then takes a one-in-game-hour break before receiving another lead. Breaks restore full stamina. Natural call progress is Speed/18 per second; speed changes affect only subsequent progress, and speed zero pauses natural progress. Direct augment progress changes aggregate before clamping, and committed calls cannot reopen. Deterministic event waves preserve independent root chains and permit full cascades without a chain-depth cap. Abandonment wins at the exact deadline even if a seat opens then; active calls never abandon. Employee-specific assigned/handled calls, calling/break/idle time, sales, and revenue are tracked alongside aggregate abandonment and recovery totals. Arrival, conversion, and upsell use separate random generators. Resetting a day copies the prepared lineup and clears daily metrics, queue state, random streams, and temporary effects; the session lineup persists. Pause freezes simulation time. These values are prototype tuning; employee-specific conditional traits and advanced matching remain future work.

Godot was found at `~/Downloads/Godot.app` during setup. To open this project from a terminal in this folder:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --editor --path .
```

If you move Godot into Applications later, use `/Applications/Godot.app/Contents/MacOS/Godot` instead. You can also import this project through the Project Manager regardless of where the app lives.

## Project layout

- `project.godot` — project settings and the default main scene.
- `scenes/main_menu.tscn` / `scripts/main_menu.gd` — startup, New Quarter, Resume, and music settings.
- `scenes/opening.tscn` / `scripts/opening.gd` — new-quarter cinematic and handoff to the guided first day.
- `scripts/run_save.gd` — validated, versioned autosave and one-time Resume handoff.
- `scenes/music_player.tscn` / `scripts/music_player.gd` — looping background music, registered as a runtime autoload.
- `scenes/music_button.tscn` / `scripts/music_button.gd` — reusable Music: On/Off control used by the opening and workday.
- `data/opening_sequence.tres` / `scripts/opening_sequence.gd` — opening copy and exported timing settings.
- `scenes/main.tscn` — existing sales-floor root, also runnable directly during development.
- `scenes/call_queue_panel.tscn` — editable waiting-call sidebar.
- `scripts/call_queue_simulation.gd` — queue and call handling state, separate from presentation.
- `scripts/lead_assignment.gd` — small pure helper for finding the next available seat in fixed row-major priority.
- `scenes/planning_panel.tscn` / `scripts/planning_panel.gd` — Prepare roster inspector and assignment controls.
- `scripts/floor_plan.gd` — seating, moves, and swaps.
- `scripts/inventory_manager.gd`, `inventory_panel.gd`, `inventory_slot.gd` — item/reserve state and the drag-and-drop inventory UI.
- `scripts/financial_ledger.gd` — idempotent daily upkeep settlement, carried debt, write-ups and termination state.
- `data/planning_roster.tres` / `scripts/employee_roster.gd` — all 19 employee records, active Speed/Conversion/Upsell values, Recycler role classification, and shared stat interpretation, editable as a native Godot resource in the Inspector.
- `tests/test_financial_gameplay.gd` — payroll settlement, debt carry, write-ups, termination, employee firing and augment lifecycle.
- `tests/test_lead_assignment.gd` — routing, abandonment deadlines, repeatability, and employee attribution coverage.
- `tests/test_employee_stats.gd` — all persona baselines, handling deadlines, conversion probabilities, and seeded sale outcomes.
- `assets/` — source art and other assets.
- `assets/MUSIC_CREDITS.md` — music asset attribution and source license listing.
- `decisions.md` — the game's design decisions and open questions.
- `docs/WORLD.md` — established worldbuilding and optional expansion ideas.
- `docs/OPENING_CINEMATIC.md` — full script, staging, preview, skip, and validation notes.
- `player-persona.md` — the primary player persona, design guidance, and validation questions.

The base viewport is 1280 × 720, with a resizable window, a 960 × 540 minimum, and canvas scaling. The icon remains a placeholder.

## Development

Keep business simulation separate from UI as gameplay is added. The current floor is an autonomous queue prototype with fixed row-major routing and per-employee daily metrics; see the design log for remaining gameplay questions. The cinematic runs independently and does not start the workday beneath it.

Godot generates `.godot/` on first import. Git ignores that cache, local editor state, export credentials, and `builds/`. Commit source assets, `.tscn` scenes, `.gd` scripts, and generated `.uid` / `.import` sidecar files alongside their sources.

For a quick check from this folder:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --import --log-file /tmp/call-center-import.log
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --quit-after 2 --log-file /tmp/call-center-run.log
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_planning.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_call_queue.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_music.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_lead_assignment.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_employee_stats.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_sales_slam.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_financial_gameplay.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_quarter_flow.gd
```

Open `scenes/sales_slam_test.tscn` and press F6 to try the Sales Slam scenarios (no sales, one big sale, exactly equal, barely over, near miss, skip midway, and more).

Creating distributable builds will require matching export templates and export presets when target platforms are chosen.

## Godot references

- [Step-by-step guide](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html)
- [Command-line tools](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Choosing a renderer](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Version control](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
