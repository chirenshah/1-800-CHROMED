# 1-800-CHROMED

A management game built in Godot, with the working title **Cyberpunk Call Center**. Design decisions are recorded in [decisions.md](decisions.md). The intended audience and playtest hypotheses are described in [player-persona.md](player-persona.md).

## Open and run

This project uses **Godot 4.7.2 Standard** and **GDScript**, with the **Compatibility** renderer for 2D/UI development. No Python environment, .NET SDK, add-ons, or export templates are needed to work in the editor.

1. Open Godot and choose **Import** in the Project Manager.
2. Select `project.godot` in this folder, then choose **Import & Edit**.
3. Press **F5** (or the Run Project button) to run the starter scene. On a Mac, you may need **Fn + F5**.
4. Press **F8** (or the Stop button) to stop it.

The starter displays a title screen. Gameplay and simulation are not implemented yet.

Godot was found at `~/Downloads/Godot.app` during setup. To open this project from a terminal in this folder:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --editor --path .
```

If you move Godot into Applications later, use `/Applications/Godot.app/Contents/MacOS/Godot` instead. You can also import this project through the Project Manager regardless of where the app lives.

## Project layout

- `project.godot` — project settings and the default main scene.
- `scenes/main.tscn` — starter UI, editable in Godot's 2D workspace.
- `scripts/main.gd` — attached GDScript entry point for UI behavior.
- `assets/` — source art and other assets.
- `decisions.md` — the game's design decisions and open questions.
- `player-persona.md` — the primary player persona, design guidance, and validation questions.

The base viewport is 1280 × 720, with a resizable window and canvas scaling. The project name and icon are placeholders.

## Development

Keep business simulation separate from UI as gameplay is added. A useful first exercise is one desk, incoming leads, automatic sales, a revenue label, and pause/resume; see the design log for the proposed learning sequence.

Godot generates `.godot/` on first import. Git ignores that cache, local editor state, export credentials, and `builds/`. Commit source assets, `.tscn` scenes, `.gd` scripts, and generated `.uid` / `.import` sidecar files alongside their sources.

For a quick check from this folder:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --import --log-file /tmp/call-center-import.log
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --quit-after 2 --log-file /tmp/call-center-run.log
```

Creating distributable builds will require matching export templates and export presets when target platforms are chosen.

## Godot references

- [Step-by-step guide](https://docs.godotengine.org/en/stable/getting_started/step_by_step/index.html)
- [Command-line tools](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)
- [Choosing a renderer](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Version control](https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html)
