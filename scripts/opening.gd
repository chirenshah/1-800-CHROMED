extends Control
## Self-contained startup scene. No workday exists until the handoff completes.

enum Stage { ESTABLISH, CRAWL, BOOT, REVEAL, EXIT }

const BACKGROUND := Color(0.018, 0.027, 0.043)
const INK := Color(0.9, 0.94, 0.96)
const TEAL := Color(0.38, 0.89, 0.8)
const MUTED := Color(0.48, 0.62, 0.67)
const AMBER := Color(1.0, 0.76, 0.46)

@export var sequence: OpeningSequence
@export_file("*.tscn") var next_scene := "res://scenes/main.tscn"
@export var enabled := true

@onready var establish: Control = $Establish
@onready var crawl_window: Control = $CrawlWindow
@onready var crawl_text: Control = $CrawlWindow/Text
@onready var boot: Control = $Boot
@onready var boot_status: Label = $Boot/Status
@onready var boot_progress: ProgressBar = $Boot/Progress
@onready var reveal: Control = $Reveal
@onready var appointment: Label = $Reveal/Appointment
@onready var predecessor: Label = $Reveal/Predecessor
@onready var directive: Label = $Reveal/Directive
@onready var archive_label: Label = $Chrome/ArchiveLabel
@onready var section_label: Label = $Chrome/SectionLabel
@onready var footer_label: Label = $Chrome/FooterLabel
@onready var skip_button: Button = $Chrome/SkipButton
@onready var music_button: Button = $Chrome/MusicButton
@onready var fade: ColorRect = $Fade

var stage: Stage = Stage.ESTABLISH
var stage_elapsed := 0.0
var crawl_height := 0.0
var paragraphs: Array[Label] = []
var _handoff_requested := false


func _ready() -> void:
	if sequence == null:
		push_error("Opening requires an OpeningSequence resource.")
		_handoff.call_deferred()
		return
	_populate_copy()
	skip_button.pressed.connect(skip)
	resized.connect(_layout)
	_layout()
	_set_stage(Stage.ESTABLISH)
	skip_button.grab_focus()
	if not enabled or not ProjectSettings.get_setting("chromed/opening/enabled", true) \
			or OS.get_cmdline_user_args().has("--skip-opening"):
		_handoff.call_deferred()


func _populate_copy() -> void:
	$Establish/Heading.text = sequence.archive_heading
	$Establish/Year.text = sequence.year_title
	$Establish/Footer.text = sequence.archive_footer
	$Boot/Heading.text = sequence.boot_heading
	$Reveal/Welcome.text = sequence.welcome
	$Reveal/Company.text = sequence.company_title
	$Reveal/Motto.text = sequence.motto
	appointment.text = sequence.appointment
	predecessor.text = sequence.predecessor_notice
	directive.text = sequence.directive
	for index in sequence.crawl_paragraphs.size():
		var label := Label.new()
		label.name = "Paragraph%02d" % index
		label.text = sequence.crawl_paragraphs[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crawl_text.add_child(label)
		paragraphs.append(label)


func _layout() -> void:
	if not is_node_ready() or sequence == null:
		return
	var unit := minf(size.x / 1280.0, size.y / 720.0)
	var width := minf(size.x - 112.0 * unit, 1080.0 * unit)
	var left := (size.x - width) / 2.0
	for panel: Control in [establish, boot, reveal]:
		panel.position = Vector2(left, size.y * 0.17)
		panel.size = Vector2(width, size.y * 0.68)
	_place_label($Establish/Heading, 34, 18, width, unit, TEAL)
	_place_label($Establish/Year, 110, 64, width, unit, INK)
	_place_label($Establish/Footer, 218, 17, width, unit, MUTED)
	_place_label($Boot/Heading, 110, 20, width, unit, TEAL)
	_place_label(boot_status, 170, 23, width, unit, INK)
	boot_progress.position = Vector2(width * 0.25, 235.0 * unit)
	boot_progress.size = Vector2(width * 0.5, 3.0 * unit)
	_place_label($Reveal/Welcome, 0, 17, width, unit, TEAL)
	_place_label($Reveal/Company, 32, 82, width, unit, INK)
	_place_label($Reveal/Motto, 140, 28, width, unit, TEAL)
	_place_label(appointment, 214, 19, width, unit, INK)
	_place_label(predecessor, 292, 14, width, unit, MUTED)
	_place_label(directive, 370, 24, width, unit, AMBER)

	var crawl_width := minf(width, 880.0 * unit)
	crawl_window.position = Vector2((size.x - crawl_width) / 2.0, size.y * 0.14)
	crawl_window.size = Vector2(crawl_width, size.y * 0.69)
	crawl_height = 0.0
	for index in paragraphs.size():
		var label := paragraphs[index]
		label.add_theme_font_size_override("font_size", maxi(22, roundi(30.0 * unit)))
		label.add_theme_constant_override("line_spacing", roundi(10.0 * unit))
		label.add_theme_color_override("font_color", AMBER if sequence.accent_paragraphs.has(index) else INK)
		label.position = Vector2(0, crawl_height)
		# Reset height after width/font changes; wrapped text reports its own minimum.
		label.size = Vector2(crawl_width, 0)
		label.size.y = label.get_minimum_size().y
		crawl_height += label.size.y + 42.0 * unit
	crawl_height = maxf(0.0, crawl_height - 42.0 * unit)
	crawl_text.size = Vector2(crawl_width, crawl_height)

	archive_label.position = Vector2(40, 28) * unit
	archive_label.size = Vector2(width * 0.5, 24.0 * unit)
	section_label.position = Vector2(size.x - width * 0.5 - 40.0 * unit, 28.0 * unit)
	section_label.size = Vector2(width * 0.5, 24.0 * unit)
	footer_label.position = Vector2(40.0 * unit, size.y - 58.0 * unit)
	footer_label.size = Vector2(width * 0.5, 24.0 * unit)
	for label in [archive_label, section_label, footer_label]:
		label.add_theme_font_size_override("font_size", maxi(12, roundi(13.0 * unit)))
		label.add_theme_color_override("font_color", MUTED)
	skip_button.add_theme_font_size_override("font_size", maxi(13, roundi(14.0 * unit)))
	skip_button.size = Vector2(244.0 * unit, 44.0 * unit)
	skip_button.position = Vector2(size.x - skip_button.size.x - 40.0 * unit, size.y - skip_button.size.y - 24.0 * unit)
	music_button.custom_minimum_size = Vector2(128, 36) * unit
	music_button.size = Vector2(160, 44) * unit
	music_button.position = skip_button.position - Vector2(176.0 * unit, 0)
	music_button.add_theme_font_size_override("font_size", maxi(13, roundi(14.0 * unit)))
	_apply_stage()
	queue_redraw()


func _place_label(label: Label, y: float, font_size: int, width: float, unit: float, color: Color) -> void:
	label.position = Vector2(0, y * unit)
	label.add_theme_font_size_override("font_size", maxi(12, roundi(font_size * unit)))
	label.add_theme_color_override("font_color", color)
	label.size = Vector2(width, 0)
	label.size.y = label.get_minimum_size().y


func _process(delta: float) -> void:
	if _handoff_requested or sequence == null:
		return
	stage_elapsed += delta
	# Carry excess time through stage boundaries, including slow frames.
	while stage_elapsed >= _duration():
		var remainder := stage_elapsed - _duration()
		if stage == Stage.EXIT:
			_handoff()
			return
		_set_stage((stage + 1) as Stage)
		stage_elapsed = remainder
	_apply_stage()


func _duration() -> float:
	match stage:
		Stage.ESTABLISH: return maxf(0.1, sequence.establish_seconds)
		Stage.CRAWL: return maxf(0.1, sequence.crawl_seconds)
		Stage.BOOT: return maxf(0.1, sequence.boot_seconds)
		Stage.REVEAL: return maxf(0.1, sequence.reveal_seconds)
	return maxf(0.1, sequence.fade_seconds)


func _set_stage(next_stage: Stage) -> void:
	stage = next_stage
	stage_elapsed = 0.0
	if stage != Stage.EXIT:
		establish.visible = stage == Stage.ESTABLISH
		crawl_window.visible = stage == Stage.CRAWL
		boot.visible = stage == Stage.BOOT
		reveal.visible = stage == Stage.REVEAL
	section_label.text = ["01 / CONTEXT", "02 / PROGRESS", "03 / AUTHENTICATION", "04 / APPOINTMENT", "SESSION OPEN"][stage]
	archive_label.text = "CHROMED / EMPLOYEE ACCESS" if stage >= Stage.BOOT else "CONTINUITY ARCHIVE / 2189"
	footer_label.text = "YOUR BODY. OUR BUSINESS." if stage >= Stage.BOOT else "HISTORY, OPTIMIZED."
	_apply_stage()
	queue_redraw()


func _apply_stage() -> void:
	var progress := clampf(stage_elapsed / _duration(), 0.0, 1.0)
	match stage:
		Stage.ESTABLISH:
			establish.modulate.a = _envelope(progress, 0.2, 0.2)
		Stage.CRAWL:
			crawl_text.position.y = lerpf(crawl_window.size.y, -crawl_height, progress)
		Stage.BOOT:
			boot.modulate.a = _envelope(progress, 0.1, 0.1)
			boot_progress.value = progress * 100.0
			if not sequence.boot_messages.is_empty():
				boot_status.text = sequence.boot_messages[mini(floori(progress * sequence.boot_messages.size()), sequence.boot_messages.size() - 1)]
		Stage.REVEAL:
			reveal.modulate.a = smoothstep(0.0, 0.12, progress)
			appointment.modulate.a = smoothstep(0.2, 0.28, progress)
			predecessor.modulate.a = smoothstep(0.38, 0.46, progress)
			directive.modulate.a = smoothstep(0.64, 0.72, progress)
		Stage.EXIT:
			fade.color.a = progress


func _envelope(progress: float, fade_in: float, fade_out: float) -> float:
	return smoothstep(0.0, fade_in, progress) * (1.0 - smoothstep(1.0 - fade_out, 1.0, progress))


func _input(event: InputEvent) -> void:
	# Accept activates the focused music control; Escape still skips from anywhere.
	if event.is_action_pressed("ui_accept") and music_button.has_focus():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		skip()


func skip() -> void:
	if stage == Stage.EXIT or _handoff_requested:
		return
	# Keep the current picture under the short fade. Skip bypasses every later beat.
	_set_stage(Stage.EXIT)


func _handoff() -> void:
	if _handoff_requested:
		return
	_handoff_requested = true
	set_process(false)
	set_process_input(false)
	skip_button.disabled = true
	# Defer replacement out of input/signal callbacks. The destination starts fresh.
	_commit_handoff.call_deferred()


func _commit_handoff() -> void:
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("Opening could not load %s (error %d)." % [next_scene, error])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var unit := minf(size.x / 1280.0, size.y / 720.0)
	var grid := 80.0 * unit
	if grid <= 0.0:
		return
	# An austere infrastructure schematic, not a starfield. No external assets.
	for column in range(1, ceili(size.x / grid)):
		draw_line(Vector2(column * grid, 70.0 * unit), Vector2(column * grid, size.y - 82.0 * unit), Color(0.1, 0.21, 0.25, 0.15))
	for row in range(1, ceili(size.y / grid)):
		draw_line(Vector2(40.0 * unit, row * grid), Vector2(size.x - 40.0 * unit, row * grid), Color(0.1, 0.21, 0.25, 0.15))
	var border := Rect2(Vector2(24, 72) * unit, size - Vector2(48, 154) * unit)
	draw_rect(border, Color(0.18, 0.32, 0.36, 0.35), false, 1.0)
	draw_line(border.position, border.position + Vector2(72, 0) * unit, TEAL, 2.0)
	draw_line(border.end - Vector2(72, 0) * unit, border.end, TEAL, 2.0)
	if stage == Stage.REVEAL:
		# The grand reveal resolves to nine very ordinary workstations.
		var origin := Vector2(size.x - 70.0 * unit, 94.0 * unit)
		for seat in range(9):
			var cell := origin + Vector2((seat % 3) * 11, (seat / 3) * 11) * unit
			draw_rect(Rect2(cell, Vector2(6, 6) * unit), Color(TEAL, 0.65))
