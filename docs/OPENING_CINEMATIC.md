# Opening cinematic

The opening starts like an earnest historical documentary and ends as an employee access screen. Civilization's grand story resolves into a promotion, nine workstations, and a performance problem inherited from someone whose departure HR will not explain.

The sequence is implemented in `scenes/opening.tscn` and `scripts/opening.gd`. Its `OpeningSequence` resource is `data/opening_sequence.tres`, with exported fields declared in `scripts/opening_sequence.gd`. These narrative presentation choices do not add gameplay rules.

## Complete opening script

### Establishing moment

CIVILIZATION / CONTINUITY REPORT

**THE YEAR IS 2189.**

A BRIEF HISTORY OF PROGRESS

### Upward crawl

Humanity did not fall to war.  
It did not fall to machines.  
And it did not fall to the apocalypse.

**It was acquired.**

Over centuries, corporations inherited the responsibilities of governments.

Healthcare became a subscription.  
Human bodies became financial assets.  
And artificial intelligence became management.

Every citizen was promised a better future.

A stronger body.  
A sharper mind.  
A longer life.

**Terms and conditions applied.**

Now, the world's largest corporations manufacture the miracles that keep civilization alive.

**But someone still has to sell them.**

### Corporate boot

HISTORICAL CONTEXT COMPLETE

The following status messages replace each other:

1. Connecting to your better future...
2. Loading independent sales intermediary...
3. Restoring managerial privileges: GRADE C-7
4. Welcome back. This is your first day.

### Company and appointment reveal

WELCOME TO

**1-800-CHROMED**

*Your body. Our business.*

REGIONAL SALES FLOOR MANAGER  
GRADE C-7 / 9 WORKSTATIONS

PREDECESSOR: TERMINATED — PERFORMANCE BELOW EXPECTATIONS  
Clarification request: closed without clarification.

**YOUR QUARTER BEGINS NOW.**

The interface corners read `CONTINUITY ARCHIVE / 2189`, `HISTORY, OPTIMIZED.`, and the current section during the documentary. During authentication they become `CHROMED / EMPLOYEE ACCESS` and `YOUR BODY. OUR BUSINESS.` A small 3×3 symbol appears with the company reveal. The appointment indicates nine available positions, not nine filled seats.

## Scene structure and timing

| Stage | Default time | Presentation |
| --- | ---: | --- |
| Establish | 4.5 seconds | Archive heading, year, and historical subtitle fade in and out. |
| Crawl | 58 seconds | Nine paragraphs scroll upward continuously through a clipped window. |
| Boot | 3.2 seconds | Four corporate status messages and an understated progress bar. |
| Reveal | 9 seconds | Company and motto appear first; appointment, predecessor notice, and quarter directive follow. |
| Exit | 0.65 seconds | Fade to the background color, then load the existing main scene. |

Total default duration is **75.35 seconds**. Each stage has an independent exported duration. The reveal uses normalized timing: appointment fades in at 20–28%, predecessor notice at 38–46%, and the directive at 64–72%. This gives the last line about 2.5 seconds fully visible before exit.

The root scene contains `Establish`, `CrawlWindow` (moving `Text` and an `EdgeFade`), `Boot`, `Reveal`, persistent interface chrome and skip button, and a final fade layer. A small state machine advances these stages with frame delta and carries excess time across boundaries, including slow frames. There are no autoloads, asynchronous timer chains, or changes to the simulation.

## Text animation and visual direction

The intentional implementation is a clean **2D vertical crawl**. It uses Godot Labels and text wrapping rather than true 3D perspective. The text stays the same readable size as it moves; no camera, viewport texture, shader, paid font, or external artwork is required. The background is an original, restrained infrastructure grid with a thin frame and teal registration marks. Ivory narration carries the serious opening; warm amber emphasizes the acquisition and sales punchlines. The corporate reveal uses teal and office-terminal language.

Text starts below the clipped region and exits above it. A native gradient texture softly masks the upper and lower edges. Travel is computed from the measured wrapped text height plus the crawl window height, normalized across `crawl_seconds`. Changing the text automatically changes travel distance; review the duration after substantial copy edits so it remains comfortable to read. Explicit line breaks preserve the three-line rhetorical passages; longer prose wraps to the available width.

The layout scales from the project's 1280×720 base and adapts when the window resizes. Body text is 30 logical pixels at the base size and at least 22 at the 960×540 minimum. Nonmoving labels scale with the viewport and remain separate from the skip control. Wider/taller windows center the composition. The crawl keeps its normalized progress when resized. The very small administrative text is secondary; the company, appointment, and core narrative remain prominent.

The staging borrows only the general ideas of dramatic text, upward motion, and a final reveal. All copy, interface marks, colors, and graphics belong to this presentation; no franchise logos, branded imagery, music, or effects are included.

## Transition and gameplay boundary

`project.godot` launches the opening. The scene's exported `next_scene` defaults to `res://scenes/main.tscn`, the existing root containing `workday.tscn`. That destination starts in **Prepare**, with the existing nine positions and three staffed prototype seats. The intro never instantiates a hidden workday or starts its timer. Prepare → Play → Report, queue behavior, revenue calculations, pause, and day progression retain their existing implementation. Only the floor's header text gains the CHROMED name and Grade C-7.

Both natural completion and skip use the same guarded, deferred scene replacement, so repeated input cannot launch multiple floors. The destination is loaded after the short fade. There is currently no main menu, so adding one later requires changing only the exported destination path.

## Skip and development controls

Skip is available from the first frame in every stage:

- Click or tap **Skip intro**.
- Press **Esc**, **Enter**, or **Space** using Godot's existing `ui_cancel` / `ui_accept` actions. Their default gamepad accept/cancel bindings work too.
- The button receives initial focus and has a visible focus border for keyboard/gamepad navigation.

Skip bypasses the remaining narrative and reveal, keeping only the 0.65-second exit fade. The triggering input is consumed before scene replacement. Intro state is local to the scene; the global pause state is not changed.

The intro plays on every normal project launch. No saved “seen intro” flag is introduced. For development, use any of these:

1. Open `scenes/main.tscn` and press **F6** to run the existing floor directly.
2. Set **Chromed → Opening → Enabled** to `false` in Project Settings (enable Advanced Settings if needed), or edit `opening/enabled=false` under `[chromed]` in `project.godot`.
3. Clear **Enabled** on the opening root in the Inspector.
4. Pass a user argument after the command-line separator:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --path . -- --skip-opening
```

To preview the full sequence, enable both settings, open `scenes/opening.tscn`, and press **F6**, or press **F5** to use the project's default startup. Select `data/opening_sequence.tres` in Godot's FileSystem dock to edit all copy and durations in the Inspector. No script rewrite is necessary for copy/timing edits. The authored stage nodes can also be selected in the scene tree; text and responsive positions are populated at runtime.

## Future music and sound

The current sequence is intentionally silent and does not depend on audio resources. A future original or appropriately licensed score could start with a restrained documentary drone, lose its grandeur at “Terms and conditions applied,” and resolve to a small office login chime. Quiet relay ticks or an understated connection sound could accompany authentication. Keep speech/text intelligible, respect future volume controls, and stop any cinematic-only audio on skip and scene exit. These are optional directions, not asset or implementation commitments.

## Validation and assumptions

Godot **4.7.2 Standard**, GDScript and the Compatibility renderer are the existing project baseline. No autoloads or menu were present. The company's primary cybernetics business and the player's title are narrative canon; the appointment screen does not select new products, staffing rules, budgets, progression rules, or a failure condition. The existing multi-company gameplay direction's relationship to CHROMED contracts remains open in `decisions.md`.

The headless opening test covers stage progression, long frames, initial layout, resizing, keyboard skip, button skip at every stage, repeated skip, both enable settings, natural completion, and a fresh Prepare destination. The same test can render visual snapshots; the existing queue suite verifies gameplay behavior separately:

```sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --editor --import --quit
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_opening.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . --script res://tests/test_call_queue.gd
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --path . --script res://tests/test_opening.gd -- --capture
```

Rendered checks sample establishment, crawl, boot, and reveal at 1280×720, 960×540, and 1280×1024. Captures go to `/tmp/chromed-opening-*.png`. Actual touch and physical gamepad hardware have not been exercised; the button and standard input-action paths are tested. Distributable export testing remains dependent on future export presets/templates.

Implementation reference: [Godot Control and UI input](https://docs.godotengine.org/en/stable/classes/class_control.html).
