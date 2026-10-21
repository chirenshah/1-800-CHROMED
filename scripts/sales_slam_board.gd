extends Control
class_name SalesSlamBoard
## Placeholder Sales Slam board built only from Controls and solid-color rectangles.
## It replays recorded sales against a goal. It owns a displayed tally and never touches game revenue.

signal sale_impacted(index: int, step: Dictionary)
signal goal_reached
signal goal_broken(step: Dictionary)
signal finished(result: Dictionary)
## The goal-breaking sale is hovering; `seconds` is the real-time windup left before it lands.
signal anticipation_started(step: Dictionary, seconds: float)
signal reveal_started(near_miss: bool)
signal audio_silenced

const CHARCOAL := Color(0.055, 0.063, 0.082)
const BOARD := Color(0.125, 0.14, 0.17)
const NEON_GREEN := Color(0.29, 0.95, 0.5)
const AMBER := Color(0.98, 0.72, 0.25)
const FIRE := Color(1.0, 0.55, 0.1)
const FAILURE := Color(0.62, 0.3, 0.33)
const FRAME_IDLE := Color(0.2, 0.25, 0.33)
const TEXT := Color(0.94, 0.96, 1.0)

var plan := SalesSlamPlan.new()
## Playback multiplier. Tests and the fast toggle raise it; 1.0 is the designed pacing.
var time_scale := 1.0
var fast_scale := 3.0
var running := false
var goal := 0
var total := 0
var demolition_count := 0
var applied_sales := 0
var steps: Array[Dictionary] = []
var displayed_tally := 0.0:
	set(value):
		displayed_tally = value
		_refresh_counter()

var demolished := false
var _fast := false
var _run_id := 0
var _tweens: Array[Tween] = []
var _reached_emitted := false
var _rng := RandomNumberGenerator.new()
var _status: Label
var _banner: Label
var _counter: Label
var _goal_label: Label
var _track: ColorRect
var _fill: ColorRect
var _percent: Label
var _latest: Label
var _sale_number: Label
var _result: Label
var _surface: Control
var _frame: ColorRect
var _panel: ColorRect
var _crack_layer: Control
var _lights: Array[ColorRect] = []
var _fx_layer: Control
var _flash: ColorRect
var _skip_button: Button
var _fast_button: Button
var _built := false
var _buttons_row: HBoxContainer
var _blink: Tween
var _skipped := false
var audio: SalesSlamAudio
## Shake energy 0..1. Displacement scales with trauma squared, so small hits stay subtle.
var _trauma := 0.0
const TRAUMA_DECAY := 1.3
const MAX_SHAKE_PIXELS := 26.0
const MAX_SHAKE_RADIANS := 0.025


func _ready() -> void:
	_build()
	set_process(false)


func _process(delta: float) -> void:
	_trauma = maxf(_trauma - TRAUMA_DECAY * delta * _speed(), 0.0)
	var power := _trauma * _trauma
	_surface.pivot_offset = _surface.size / 2.0
	_surface.position = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * MAX_SHAKE_PIXELS * power
	_surface.rotation = _rng.randf_range(-1.0, 1.0) * MAX_SHAKE_RADIANS * power
	if _trauma <= 0.0:
		_reset_transients()
		set_process(false)


func _build() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(380, 300)
	_rng.randomize()
	var backdrop := ColorRect.new()
	backdrop.color = CHARCOAL
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface = Control.new()
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = _rect(_surface, FRAME_IDLE)
	_panel = _rect(_surface, BOARD)
	_panel.offset_left = 4
	_panel.offset_top = 4
	_panel.offset_right = -4
	_panel.offset_bottom = -4
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	_surface.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	_status = _label(column, 13, AMBER, "AWAITING TALLY")
	_banner = _label(column, 24, FIRE, "QUOTA DESTROYED")
	_banner.visible = false
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter = _label(column, 48, NEON_GREEN, "$0")
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label = _label(column, 16, TEXT, "GOAL  $0")
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track = ColorRect.new()
	_track.color = Color(0.03, 0.035, 0.045)
	_track.custom_minimum_size = Vector2(0, 24)
	column.add_child(_track)
	_fill = _rect(_track, NEON_GREEN)
	_fill.anchor_right = 0.0
	_percent = Label.new()
	_percent.add_theme_font_size_override("font_size", 13)
	_percent.add_theme_color_override("font_color", Color.WHITE)
	_percent.add_theme_color_override("font_outline_color", Color.BLACK)
	_percent.add_theme_constant_override("outline_size", 4)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_track.add_child(_percent)
	_percent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var info := HBoxContainer.new()
	column.add_child(info)
	_latest = _label(info, 14, TEXT, "LATEST SALE  —")
	_latest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sale_number = _label(info, 14, TEXT, "SALE 0 / 0")
	_result = _label(column, 14, AMBER, "")
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	_fast_button = Button.new()
	_fast_button.text = "×3 SPEED"
	_fast_button.toggle_mode = true
	_fast_button.toggled.connect(set_fast)
	buttons.add_child(_fast_button)
	_skip_button = Button.new()
	_skip_button.text = "SKIP ▶▶"
	_skip_button.pressed.connect(skip)
	buttons.add_child(_skip_button)
	var mute_button := Button.new()
	mute_button.text = "SFX ON"
	mute_button.toggle_mode = true
	mute_button.toggled.connect(_on_mute_toggled.bind(mute_button))
	buttons.add_child(mute_button)
	buttons.visible = false
	_crack_layer = Control.new()
	_crack_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(_crack_layer)
	_crack_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Warning lights sit at the top corners and only blink while the goal is near.
	for corner in [0.0, 1.0]:
		var light := ColorRect.new()
		light.color = FAILURE
		light.custom_minimum_size = Vector2(12, 12)
		light.size = Vector2(12, 12)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.visible = false
		_surface.add_child(light)
		light.anchor_left = corner
		light.anchor_right = corner
		light.offset_left = 8 if corner == 0.0 else -20
		light.offset_right = 20 if corner == 0.0 else -8
		light.offset_top = 8
		light.offset_bottom = 20
		_lights.append(light)
	_fx_layer = Control.new()
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buttons_row = buttons
	audio = SalesSlamAudio.new()
	add_child(audio)
	audio.attach(self)
	_refresh_counter()


func _on_mute_toggled(muted: bool, button: Button) -> void:
	audio.enabled = not muted
	button.text = "SFX OFF" if muted else "SFX ON"
	if muted:
		audio.silence()


func _rect(parent: Control, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _label(parent: Control, font_size: int, color: Color, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# --- Public API ------------------------------------------------------------

func set_fast(enabled: bool) -> void:
	_fast = enabled
	if _fast_button != null and _fast_button.button_pressed != enabled:
		_fast_button.set_pressed_no_signal(enabled)


func displayed_total() -> int:
	return roundi(displayed_tally)


## Replays `sales` ({value, employee_id}) against `goal_amount`. The recorded total is the source of truth.
func play(sales: Array, goal_amount: int) -> void:
	_build()
	stop()
	_run_id += 1
	_skipped = false
	goal = maxi(goal_amount, 0)
	total = plan.total(sales)
	steps = plan.build(sales, goal)
	demolished = false
	demolition_count = 0
	applied_sales = 0
	_reached_emitted = false
	displayed_tally = 0.0
	_goal_label.text = "GOAL  $%s" % _format(goal)
	_banner.visible = false
	_result.text = ""
	_latest.text = "LATEST SALE  —"
	_sale_number.text = "SALE 0 / %d" % steps.size()
	_clear_fx()
	_clear_cracks()
	_apply_stage(SalesSlamPlan.Stage.IDLE)
	_set_status("TALLYING", AMBER)
	running = true
	_buttons_row.visible = true
	if steps.is_empty():
		_finalize(true)
		return
	_begin_step(0, _run_id)


## Jumps to the correct final state immediately. Revenue is untouched.
func skip() -> void:
	if running:
		_skipped = true
		audio_silenced.emit()
		_finalize(true)


## Abandons any playback without emitting `finished` (phase changes, next day).
func stop() -> void:
	running = false
	_run_id += 1
	_kill_tweens()
	if _built:
		_clear_fx()
		_buttons_row.visible = false
		audio_silenced.emit()


# --- Sequence --------------------------------------------------------------

func _speed() -> float:
	return time_scale * (fast_scale if _fast else 1.0)


func _tween() -> Tween:
	var tween := create_tween()
	tween.set_speed_scale(_speed())
	_tweens.append(tween)
	return tween


func _kill_tweens() -> void:
	for tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	_blink = null


func _begin_step(index: int, run_id: int) -> void:
	if run_id != _run_id or not running:
		return
	if index >= steps.size():
		_reveal_final(run_id)
		return
	var step := steps[index]
	_latest.text = "LATEST SALE  $%s" % _format(int(step["value"]))
	_sale_number.text = "SALE %d / %d" % [index + 1, steps.size()]
	var heat: float = step["intensity"]
	var number := Label.new()
	number.text = "+$%s" % _format(int(step["value"]))
	number.add_theme_font_size_override("font_size", roundi(20.0 + 30.0 * heat))
	number.add_theme_color_override("font_color", FIRE if step["breaks_goal"] else NEON_GREEN)
	number.add_theme_color_override("font_outline_color", Color.BLACK)
	number.add_theme_constant_override("outline_size", 6)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(number)
	var number_size := number.get_combined_minimum_size()
	var target := _counter_center() - number_size / 2.0
	var start := Vector2(target.x + _rng.randf_range(-70.0, 70.0), -number_size.y - 30.0)
	number.position = start
	var duration: float = step["duration"]
	var windup: float = step["windup"]
	var fly := duration * (0.55 if step["breaks_goal"] else 0.65)
	var tween := _tween()
	if windup > 0.0:
		# Anticipation: the final blow hangs above the board, growing and rumbling, before it drops.
		var hover := target + Vector2(0.0, -number_size.y - 40.0)
		number.pivot_offset = number_size / 2.0
		_apply_stage(SalesSlamPlan.Stage.STRAINED)
		_set_status("BRACE FOR IMPACT", FIRE)
		anticipation_started.emit(step, windup / _speed())
		var rise := _tween()
		rise.tween_property(number, "position", hover, windup).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var growth := _tween()
		growth.tween_method(_windup_step.bind(number), 0.0, 1.0, windup)
		tween.tween_interval(windup)
	tween.tween_property(number, "position", target, fly).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_callback(_impact.bind(index, number, run_id))
	tween.tween_interval(maxf(duration - fly, 0.0))
	tween.tween_callback(_begin_step.bind(index + 1, run_id))


func _windup_step(progress: float, number: Label) -> void:
	number.scale = Vector2.ONE * (1.0 + 0.5 * progress)
	_add_trauma(0.0, 0.1 + 0.3 * progress)


func _impact(index: int, number: Label, run_id: int) -> void:
	if run_id != _run_id or not running:
		return
	number.queue_free()
	var step := steps[index]
	var heat: float = step["intensity"]
	applied_sales = index + 1
	var count := _tween()
	count.tween_property(self, "displayed_tally", float(step["tally_after"]), minf(0.14 + 0.1 * heat, float(step["duration"]) * 0.8))
	_apply_stage(step["stage"])
	_add_trauma(0.12 + 0.4 * heat)
	_flash_board(0.06 + 0.3 * heat, 0.12 + 0.2 * heat, NEON_GREEN)
	_particles(3 + roundi(heat * 12.0), heat, NEON_GREEN)
	_pop(_counter, 1.0 + 0.2 * heat)
	if step["stage"] >= SalesSlamPlan.Stage.STRAINED and step["stage"] < SalesSlamPlan.Stage.EXCEEDED:
		_add_crack(_crack_origin(), 40.0 + 60.0 * heat, 1.0 + heat, Color(AMBER, 0.45))
	if int(step["tally_after"]) >= goal and not _reached_emitted:
		_reached_emitted = true
		goal_reached.emit()
		_set_status("GOAL REACHED", NEON_GREEN)
	if step["breaks_goal"]:
		_demolish(step, true)
	sale_impacted.emit(index, step)


func _reveal_final(run_id: int) -> void:
	var tween := _tween()
	var near_miss := plan.is_near_miss(total, goal)
	reveal_started.emit(near_miss)
	if near_miss:
		# A held breath before showing that the goal slipped away.
		_set_status("...", AMBER)
		tween.tween_interval(plan.near_miss_pause_seconds)
	tween.tween_callback(_pop.bind(_counter, 1.3, plan.final_reveal_seconds))
	tween.tween_interval(plan.final_reveal_seconds)
	tween.tween_callback(func() -> void:
		if run_id == _run_id and running:
			_finalize(false))


## Skipping clears in-flight effects; a natural finish lets debris and sparks fall out on their own.
func _finalize(skipped: bool) -> void:
	_kill_tweens()
	if skipped:
		_clear_fx()
	else:
		_reset_transients()
	running = false
	_buttons_row.visible = false
	applied_sales = steps.size()
	displayed_tally = float(total)
	var final_stage := plan.stage_for(total, goal)
	_apply_stage(final_stage)
	if not steps.is_empty():
		var last: Dictionary = steps[steps.size() - 1]
		_latest.text = "LATEST SALE  $%s" % _format(int(last["value"]))
	_sale_number.text = "SALE %d / %d" % [steps.size(), steps.size()]
	var outcome := plan.outcome(total, goal)
	if outcome == SalesSlamPlan.Outcome.EXCEEDED:
		# Skipping past the crossing sale still shows the broken board, exactly once.
		for step in steps:
			if step["breaks_goal"]:
				_demolish(step, false)
		_set_status("TALLY COMPLETE", NEON_GREEN)
		_result.text = "Quota beaten by $%s" % _format(total - goal)
		_result.add_theme_color_override("font_color", FIRE)
	elif outcome == SalesSlamPlan.Outcome.REACHED:
		_set_status("TALLY COMPLETE", NEON_GREEN)
		_result.text = "Goal reached exactly. The board holds."
		_result.add_theme_color_override("font_color", NEON_GREEN)
	else:
		_set_status("TALLY COMPLETE", FAILURE)
		_result.text = "$%s short of the goal." % _format(goal - total)
		if plan.is_near_miss(total, goal):
			_result.text += " So close."
			_add_crack(_crack_origin(), 110.0, 3.0, Color(FAILURE, 0.8))
		_result.add_theme_color_override("font_color", FAILURE)
	finished.emit({
		"total": total, "goal": goal, "outcome": outcome, "sales": steps.size(),
		"demolitions": demolition_count, "shortfall": maxi(goal - total, 0), "skipped": _skipped,
	})


# --- Visual state ----------------------------------------------------------

func _refresh_counter() -> void:
	if _counter == null:
		return
	var shown := roundi(displayed_tally)
	_counter.text = "$%s" % _format(shown)
	var ratio := 1.0 if goal <= 0 and shown > 0 else (0.0 if goal <= 0 else float(shown) / float(goal))
	_fill.anchor_right = clampf(ratio, 0.0, 1.0)
	_fill.offset_right = 0
	_percent.text = "%d%% OF GOAL" % roundi(ratio * 100.0)


func _apply_stage(stage: int) -> void:
	var frame_color := FRAME_IDLE
	var fill_color := NEON_GREEN
	match stage:
		SalesSlamPlan.Stage.WARM:
			frame_color = Color(0.2, 0.45, 0.35)
		SalesSlamPlan.Stage.HOT:
			frame_color = Color(0.25, 0.7, 0.45)
			fill_color = Color(0.5, 1.0, 0.65)
		SalesSlamPlan.Stage.STRAINED:
			frame_color = AMBER
			fill_color = AMBER
		SalesSlamPlan.Stage.REACHED:
			frame_color = Color(0.7, 1.0, 0.85)
			fill_color = Color(0.7, 1.0, 0.85)
		SalesSlamPlan.Stage.EXCEEDED:
			frame_color = FIRE
			fill_color = FIRE
	_frame.color = frame_color
	_fill.color = fill_color
	_panel.color = BOARD.darkened(0.35) if demolished else BOARD
	var warn := stage == SalesSlamPlan.Stage.STRAINED or stage == SalesSlamPlan.Stage.REACHED
	for light in _lights:
		light.visible = warn
		light.modulate.a = 1.0
	if warn and not _lights.is_empty() and running and _blink == null:
		_blink = _tween().set_loops()
		_blink.tween_callback(_toggle_lights)
		_blink.tween_interval(0.25)
	elif not warn and _blink != null:
		_blink.kill()
		_blink = null


func _toggle_lights() -> void:
	for light in _lights:
		light.color = AMBER if light.color != AMBER else FAILURE


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _counter_center() -> Vector2:
	return _counter.global_position - global_position + _counter.size / 2.0


func _crack_origin() -> Vector2:
	var span := _crack_layer.size if _crack_layer.size.x > 0.0 else Vector2(380, 300)
	return Vector2(span.x * _rng.randf_range(0.2, 0.8), span.y * _rng.randf_range(0.25, 0.75))


# --- Effects ---------------------------------------------------------------

func _add_trauma(amount: float, at_least := 0.0) -> void:
	_trauma = maxf(minf(_trauma + amount, 1.0), at_least)
	set_process(true)


func _flash_board(alpha: float, seconds: float, color: Color) -> void:
	_flash.color = Color(color, alpha)
	var tween := _tween()
	tween.tween_property(_flash, "color:a", 0.0, seconds)


func _pop(control: Control, scale_to: float, seconds: float = 0.18) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2.ONE * scale_to
	var tween := _tween()
	tween.tween_property(control, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _particles(count: int, heat: float, color: Color) -> void:
	var origin := _counter_center()
	for _spark in count:
		var spark := ColorRect.new()
		spark.color = color
		spark.size = Vector2(6, 6)
		spark.position = origin
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx_layer.add_child(spark)
		var angle := _rng.randf() * TAU
		var reach := _rng.randf_range(0.4, 1.0) * (30.0 + 90.0 * heat)
		var tween := spark.create_tween()
		tween.set_speed_scale(_speed())
		tween.set_parallel()
		tween.tween_property(spark, "position", origin + Vector2(cos(angle), sin(angle)) * reach, 0.35)
		tween.tween_property(spark, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(spark.queue_free)


func _add_crack(origin: Vector2, length: float, thickness: float, color: Color, angle := -1.0) -> void:
	var crack := ColorRect.new()
	crack.color = color
	crack.size = Vector2(length, thickness)
	crack.pivot_offset = Vector2(0.0, thickness / 2.0)
	crack.position = origin - crack.pivot_offset
	crack.rotation = _rng.randf() * TAU if angle < 0.0 else angle
	crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crack_layer.add_child(crack)


func _demolish(step: Dictionary, animated: bool) -> void:
	if demolished:
		return
	demolished = true
	demolition_count += 1
	var heat: float = step["intensity"]
	_banner.visible = true
	_panel.color = BOARD.darkened(0.35)
	var origin := _counter_center()
	var cracks := 6 + roundi(heat * 6.0)
	for crack_index in cracks:
		_add_crack(origin, _rng.randf_range(70.0, 150.0 + 120.0 * heat), 2.0 + heat * 2.0,
			Color(FIRE, 0.9) if crack_index % 2 == 0 else Color(0.02, 0.02, 0.03, 0.9),
			TAU * float(crack_index) / float(cracks) + _rng.randf_range(-0.2, 0.2))
	_set_status("GOAL EXCEEDED", FIRE)
	_frame.color = FIRE
	_fill.color = FIRE
	if animated:
		_flash_board(0.6 + 0.35 * heat, 0.4 + 0.3 * heat, Color(1.0, 0.9, 0.5))
		_add_trauma(1.0)
		_pop(_banner, 1.8, 0.5)
		_debris(18 + roundi(heat * 20.0), heat)
		_particles(20 + roundi(heat * 20.0), 1.0, FIRE)
	goal_broken.emit(step)


func _debris(count: int, heat: float) -> void:
	var span := _fx_layer.size if _fx_layer.size.x > 0.0 else Vector2(380, 300)
	for _chunk in count:
		var piece := ColorRect.new()
		var side := _rng.randf_range(8.0, 14.0 + 12.0 * heat)
		piece.size = Vector2(side, side * _rng.randf_range(0.4, 1.0))
		piece.color = FIRE if _rng.randf() < 0.35 else BOARD.lightened(_rng.randf_range(0.0, 0.2))
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var start := Vector2(span.x * _rng.randf_range(0.1, 0.9), span.y * _rng.randf_range(0.2, 0.7))
		piece.position = start
		_fx_layer.add_child(piece)
		var velocity := Vector2(_rng.randf_range(-220.0, 220.0), _rng.randf_range(-380.0, -80.0))
		var spin := _rng.randf_range(-6.0, 6.0)
		var fall := _rng.randf_range(0.9, 1.4)
		var tween := piece.create_tween()
		tween.set_speed_scale(_speed())
		tween.tween_method(_debris_step.bind(piece, start, velocity, spin, fall), 0.0, fall, fall)
		tween.tween_callback(piece.queue_free)


func _debris_step(t: float, piece: ColorRect, start: Vector2, velocity: Vector2, spin: float, fall: float) -> void:
	piece.position = start + velocity * t + Vector2(0.0, 520.0) * t * t * 0.5
	piece.rotation = spin * t
	piece.modulate.a = clampf(1.0 - (t - fall * 0.6) / (fall * 0.4), 0.0, 1.0)


## Resets effects that offset or tint the board. Cracks are scenery and stay.
func _reset_transients() -> void:
	_trauma = 0.0
	_surface.position = Vector2.ZERO
	_surface.rotation = 0.0
	_flash.color.a = 0.0
	_counter.scale = Vector2.ONE
	_banner.scale = Vector2.ONE


func _clear_fx() -> void:
	for child in _fx_layer.get_children():
		child.queue_free()
	_reset_transients()


func _clear_cracks() -> void:
	for crack in _crack_layer.get_children():
		crack.queue_free()


func _format(value: int) -> String:
	var digits := str(absi(value))
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + output
