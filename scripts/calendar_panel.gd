extends PanelContainer
class_name CalendarPanel

const MONTHS_PER_QUARTER := 3
const WORKDAYS_PER_MONTH := 20
const DAYS_PER_ROW := 5

const CYAN := Color(0.29, 0.94, 0.82)
const MUTED := Color(0.62, 0.73, 0.79)
const COMPLETED_COLOR := Color(0.35, 0.48, 0.52)
const FUTURE_COLOR := Color(0.16, 0.21, 0.29)
const CURRENT_COLOR := Color(0.98, 0.72, 0.25)

var current_day := 1
var display_month := 1
var _current_month := 1
var _month_title: Label
var _previous_button: Button
var _next_button: Button
var _day_labels: Array[Label] = []
var _status_labels: Array[Label] = []
var _day_panels: Array[PanelContainer] = []
var _boss_label: Label
var _challenge_label: Label


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.067, 0.106)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.16, 0.21, 0.29)
	add_theme_stylebox_override("panel", panel_style)
	_build()
	resized.connect(_update_layout)
	_update_layout()
	set_current_day(current_day)


func set_current_day(day: int) -> void:
	var bounded_day := clampi(day, 1, MONTHS_PER_QUARTER * WORKDAYS_PER_MONTH)
	var day_changed := bounded_day != current_day
	current_day = bounded_day
	var current_month := floori(float(current_day - 1) / WORKDAYS_PER_MONTH) + 1
	if day_changed or current_month != _current_month:
		display_month = current_month
		_current_month = current_month
	_render_month()


func show_day(day: int) -> void:
	set_current_day(day)


func previous_month() -> void:
	display_month = maxi(1, display_month - 1)
	_render_month()


func next_month() -> void:
	display_month = mini(MONTHS_PER_QUARTER, display_month + 1)
	_render_month()


func _build() -> void:
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	_previous_button = Button.new()
	_previous_button.text = "<"
	_previous_button.custom_minimum_size = Vector2(42, 38)
	_previous_button.tooltip_text = "Previous month"
	_previous_button.pressed.connect(previous_month)
	header.add_child(_previous_button)
	_month_title = Label.new()
	_month_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_month_title.add_theme_font_size_override("font_size", 22)
	_month_title.add_theme_color_override("font_color", CYAN)
	_month_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_month_title)
	var quarter_label := Label.new()
	quarter_label.text = "60-WORKDAY QUARTER"
	quarter_label.add_theme_font_size_override("font_size", 12)
	quarter_label.add_theme_color_override("font_color", MUTED)
	quarter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(quarter_label)
	_next_button = Button.new()
	_next_button.text = ">"
	_next_button.custom_minimum_size = Vector2(42, 38)
	_next_button.tooltip_text = "Next month"
	_next_button.pressed.connect(next_month)
	header.add_child(_next_button)

	var grid := GridContainer.new()
	grid.columns = DAYS_PER_ROW
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for day_index in WORKDAYS_PER_MONTH:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(0, 60)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var cell_style := StyleBoxFlat.new()
		cell_style.bg_color = Color(0.035, 0.05, 0.08)
		cell_style.set_border_width_all(1)
		cell_style.border_color = FUTURE_COLOR
		cell_style.set_corner_radius_all(6)
		cell.add_theme_stylebox_override("panel", cell_style)
		grid.add_child(cell)
		_day_panels.append(cell)
		var cell_margin := MarginContainer.new()
		for edge in ["left", "right", "top", "bottom"]:
			cell_margin.add_theme_constant_override("margin_" + edge, 8)
		cell.add_child(cell_margin)
		var cell_content := VBoxContainer.new()
		cell_content.add_theme_constant_override("separation", 3)
		cell_margin.add_child(cell_content)
		var day_label := Label.new()
		day_label.add_theme_font_size_override("font_size", 14)
		cell_content.add_child(day_label)
		_day_labels.append(day_label)
		var status_label := Label.new()
		status_label.add_theme_font_size_override("font_size", 10)
		status_label.add_theme_color_override("font_color", MUTED)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell_content.add_child(status_label)
		_status_labels.append(status_label)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	content.add_child(details)
	_boss_label = Label.new()
	_boss_label.add_theme_color_override("font_color", CURRENT_COLOR)
	_boss_label.add_theme_font_size_override("font_size", 12)
	details.add_child(_boss_label)
	_challenge_label = Label.new()
	_challenge_label.text = "CHALLENGES & MODIFIERS · Coming soon; none are active."
	_challenge_label.add_theme_color_override("font_color", MUTED)
	_challenge_label.add_theme_font_size_override("font_size", 11)
	details.add_child(_challenge_label)


func _render_month() -> void:
	if _month_title == null:
		return
	var first_day := (display_month - 1) * WORKDAYS_PER_MONTH + 1
	var last_day := first_day + WORKDAYS_PER_MONTH - 1
	_month_title.text = "MONTH %d  ·  DAYS %02d–%02d" % [display_month, first_day, last_day]
	_previous_button.disabled = display_month <= 1
	_next_button.disabled = display_month >= MONTHS_PER_QUARTER
	for index in WORKDAYS_PER_MONTH:
		var global_day := first_day + index
		var day_label := _day_labels[index]
		var status_label := _status_labels[index]
		var style: StyleBoxFlat = (
			_day_panels[index].get_theme_stylebox("panel") as StyleBoxFlat
		).duplicate() as StyleBoxFlat
		day_label.text = "DAY %02d" % (index + 1)
		day_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1))
		status_label.add_theme_color_override("font_color", MUTED)
		if global_day < current_day:
			status_label.text = "COMPLETED"
			style.border_color = COMPLETED_COLOR
			style.bg_color = Color(0.055, 0.085, 0.11)
		elif global_day == current_day:
			status_label.text = "CURRENT WORKDAY"
			status_label.add_theme_color_override("font_color", CURRENT_COLOR)
			day_label.add_theme_color_override("font_color", CURRENT_COLOR)
			style.border_color = CURRENT_COLOR
			style.bg_color = Color(0.14, 0.11, 0.065)
		else:
			status_label.text = "UPCOMING"
			status_label.add_theme_color_override("font_color", MUTED)
			style.border_color = FUTURE_COLOR
			style.bg_color = Color(0.035, 0.05, 0.08)
		if index == WORKDAYS_PER_MONTH - 1:
			var boss := "QUARTER FINAL BOSS · TBD" if display_month == MONTHS_PER_QUARTER \
				else "MONTHLY BOSS · TBD"
			if global_day == current_day:
				status_label.text = "CURRENT · " + boss
			elif global_day < current_day:
				status_label.text = "COMPLETED · " + boss
			else:
				status_label.text = boss
			status_label.add_theme_color_override(
				"font_color", CURRENT_COLOR if global_day == current_day else CYAN
			)
			if global_day != current_day:
				style.border_color = CYAN
		_day_panels[index].add_theme_stylebox_override("panel", style)
	if display_month == MONTHS_PER_QUARTER:
		_boss_label.text = "QUARTERLY FINAL BOSS · Day 60 placeholder"
	else:
		_boss_label.text = "MONTHLY BOSS · Day %d placeholder" % last_day


func _update_layout() -> void:
	if _day_panels.is_empty():
		return
	var compact := size.y < 420.0
	var cell_height := maxf(42.0, (size.y - 141.0) / 4.0)
	_month_title.add_theme_font_size_override("font_size", 18 if compact else 22)
	for cell in _day_panels:
		cell.custom_minimum_size.y = cell_height
