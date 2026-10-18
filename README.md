# 1-800-CHROMED

A cyberpunk call center management game set in 2189. Civilization wasn't destroyed; it was acquired. **Your body. Our business.** Design decisions are recorded in [decisions.md](decisions.md), narrative canon in [docs/WORLD.md](docs/WORLD.md), and the opening's script and implementation in [docs/OPENING_CINEMATIC.md](docs/OPENING_CINEMATIC.md). The intended audience and playtest hypotheses are described in [player-persona.md](player-persona.md).

## Open and run

This project uses **Godot 4.7.2 Standard** and **GDScript**, with the **Compatibility** renderer for 2D/UI development. No Python environment, .NET SDK, add-ons, or export templates are needed to work in the editor.

1. Open Godot and choose **Import** in the Project Manager.
2. Select `project.godot` in this folder, then choose **Import & Edit**.
3. Press **F5** (or the Run Project button) to run the opening cinematic and then the sales floor. On a Mac, you may need **Fn + F5**.
4. Press **F8** (or the Stop button) to stop it.

The opening runs for about 75 seconds. Click **Skip intro**, or press **Esc**, **Enter**, or **Space** to go straight to Prepare after a short fade. Choose **Start Workday** to watch incoming calls wait in the queue and move to staffed seats. **Pause** freezes arrivals and call progress. The report separates handled calls from calls still waiting or unfinished at close.

To work directly on gameplay, open `scenes/main.tscn` and press **F6**, set `chromed/opening/enabled` to `false` in Project Settings, or launch with `-- --skip-opening`. To preview only the opening, open `scenes/opening.tscn` and press **F6**. Copy and timing are editable on `data/opening_sequence.tres` in the Inspector.

The queue demo uses oldest-call-first assignment to the first available occupied seat in ascending seat order (currently seats 01, 02, and 04). Arrival timing, handling durations, and sale outcomes are placeholders shared by all roles. Waiting calls have no patience limit, abandonment, qualification, or transfers. The next preparation phase clears the prototype queue and daily counters; persistence between workdays remains a design question. These are prototype assumptions, rather than a finalized routing or balance model.

Godot was found at `~/Downloads/Godot.app` during setup. To open this project from a terminal in this folder:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --editor --path .
```

If you move Godot into Applications later, use `/Applications/Godot.app/Contents/MacOS/Godot` instead. You can also import this project through the Project Manager regardless of where the app lives.

## Project layout

- `project.godot` — project settings and the default main scene.
- `scenes/opening.tscn` / `scripts/opening.gd` — modular cinematic startup and handoff to Prepare.
- `data/opening_sequence.tres` / `scripts/opening_sequence.gd` — opening copy and exported timing settings.
- `scenes/main.tscn` — existing sales-floor root, also runnable directly during development.
- `scenes/call_queue_panel.tscn` — editable waiting-call sidebar.
- `scripts/call_queue_simulation.gd` — queue and call handling state, separate from presentation.
- `assets/` — source art and other assets.
- `decisions.md` — the game's design decisions and open questions.
- `docs/WORLD.md` — established worldbuilding and optional expansion ideas.
- `docs/OPENING_CINEMATIC.md` — full script, staging, preview, skip, and validation notes.
- `player-persona.md` — the primary player persona, design guidance, and validation questions.

The base viewport is 1280 × 720, with a resizable window, a 960 × 540 minimum, and canvas scaling. The icon remains a placeholder.

## Development

Keep business simulation separate from UI as gameplay is added. The current floor is an autonomous queue prototype; see the design log for remaining gameplay questions. The cinematic runs independently and does not start the workday beneath it.

Godot generates `.godot/` on first import. Git ignores that cache, local editor state, export credentials, and `builds/`. Commit source assets, `.tscn` scenes, `.gd` scripts, and generated `.uid` / `.import` sidecar files alongside their sources.

For a quick check from this folder:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --import --log-file /tmp/call-center-import.log
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --quit-after 2 --log-file /tmp/call-center-run.log
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_call_queue.gd
```

Creating distributable builds will require matching export templates and export presets when target platforms are chosen.

## Godot references

- [Step-by-step guide](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html)
- [Command-line tools](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Choosing a renderer](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Version control](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
