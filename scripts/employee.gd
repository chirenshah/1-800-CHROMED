extends PanelContainer
class_name EmployeeCard

signal seat_selected(seat: int)
signal dropped(data: Dictionary, target_kind: String, target_index: int)

@onready var seat_label: Label = $Margin/Content/Seat
@onready var name_label: Label = $Margin/Content/Name
@onready var role_label: Label = $Margin/Content/Role
@onready var stats_label: Label = $Margin/Content/Stats
@onready var status_label: Label = $Margin/Content/Status
@onready var call_progress: ProgressBar = $Margin/Content/CallProgress

var staffed := false
var seat_number := 0
var employee_id := ""
var planning_enabled := false
var selected := false
var drop_validator := Callable()
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _empty_style: StyleBoxFlat
var _selected_empty_style: StyleBoxFlat
var _displayed_call_id := -1
var _assignment_tween: Tween


func _ready() -> void:
	_normal_style = get_theme_stylebox("panel").duplicate()
	_normal_style.bg_color = Color(0.07, 0.10, 0.15, 0.82)
	_selected_style = _normal_style.duplicate()
	_selected_style.border_color = Color(0.29, 0.94, 0.82)
	_selected_style.set_border_width_all(2)
	_empty_style = _normal_style.duplicate()
	_empty_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_empty_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	_empty_style.set_border_width_all(0)
	_selected_empty_style = _empty_style.duplicate()
	_selected_empty_style.border_color = Color(0.29, 0.94, 0.82)
	_selected_empty_style.set_border_width_all(2)
	status_label.z_index = 1
	call_progress.z_index = 1
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)


func configure(number: int, employee: Dictionary, loadout: Array[String] = [], effective_stats: Dictionary = {}) -> void:
	seat_number = number
	employee_id = employee.get("id", "")
	staffed = not employee_id.is_empty()
	seat_label.text = "SEAT %02d" % number
	name_label.text = employee.get("name", "+ Add rep")
	role_label.text = employee.get("archetype", "")
	seat_label.visible = staffed
	name_label.visible = staffed
	role_label.visible = staffed
	name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1) if staffed else Color(0.62, 0.73, 0.79))
	if staffed:
		var stats := effective_stats
		if stats.is_empty():
			stats = FloorPlan.CATALOG.modified_stats(employee_id, loadout)
		var speed := float(stats.get("speed", 0.0))
		var talk_time := INF if speed <= 0.0 else EmployeeRoster.BASE_HANDLING_SECONDS / speed
		stats_label.text = "%.0f%% close · SPD %.2f\n%s/call · Upsell %.1f%%\n%.0fh stamina · $%d/day" % [
			float(stats.get("conversion", employee.get("conversion", 0.0))), speed,
			"Paused" if speed <= 0.0 else EmployeeRoster.format_game_duration(talk_time),
			float(stats.get("upsell_chance", employee.get("upsell_chance", 0.0))),
			float(employee.get("stamina_hours", EmployeeRoster.DEFAULT_STAMINA_HOURS)),
			FloorPlan.CATALOG.daily_upkeep(employee_id),
		]
		if not loadout.is_empty():
			stats_label.text += " · ◆%d" % loadout.size()
	else:
		stats_label.text = ""
	stats_label.visible = staffed
	_refresh_style()


func set_planning_state(editable: bool, is_selected: bool) -> void:
	planning_enabled = editable
	selected = is_selected and editable
	focus_mode = Control.FOCUS_ALL if editable else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if editable else Control.CURSOR_ARROW
	_refresh_style()


func set_compact(compact: bool, card_height: float = -1.0) -> void:
	var default_height := 104.0 if compact else 116.0
	custom_minimum_size = Vector2(134, card_height if card_height > 0.0 else default_height)
	name_label.add_theme_font_size_override("font_size", 12 if compact else 18)
	seat_label.add_theme_font_size_override("font_size", 8 if compact else 11)
	role_label.add_theme_font_size_override("font_size", 9 if compact else 13)
	status_label.add_theme_font_size_override("font_size", 8 if compact else 12)
	stats_label.add_theme_font_size_override("font_size", 8 if compact else 11)
	$Margin/Content.add_theme_constant_override("separation", 0 if compact else 4)
	for edge in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + edge, 4 if compact else 10)


func _refresh_style() -> void:
	if _normal_style == null:
		return
	var style := _normal_style if staffed else _empty_style
	if selected or (planning_enabled and has_focus()):
		style = _selected_style if staffed else _selected_empty_style
	add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not planning_enabled or not staffed:
		return null
	var preview := Label.new()
	preview.text = name_label.text
	preview.add_theme_color_override("font_color", Color(0.29, 0.94, 0.82))
	set_drag_preview(preview)
	return {"type": "person", "kind": InventoryManager.BOARD, "index": seat_number - 1}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid: bool = planning_enabled and data is Dictionary and drop_validator.is_valid() \
		and drop_validator.call(data, InventoryManager.BOARD, seat_number - 1)
	if _normal_style != null:
		var feedback := _normal_style.duplicate()
		feedback.border_color = Color(0.29, 0.94, 0.82) if valid else Color(0.95, 0.3, 0.38)
		feedback.set_border_width_all(2)
		add_theme_stylebox_override("panel", feedback)
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_refresh_style()
	dropped.emit(data, InventoryManager.BOARD, seat_number - 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		_refresh_style()


func _gui_input(event: InputEvent) -> void:
	if not planning_enabled:
		return
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if clicked or event.is_action_pressed("ui_accept"):
		grab_focus()
		accept_event()
		seat_selected.emit(seat_number - 1)


func show_call(lead: Dictionary, state: String, completed: Dictionary = {}, break_remaining: float = 0.0) -> void:
	var call_id := int(lead.get("id", -1))
	if call_id != _displayed_call_id:
		if _assignment_tween != null:
			_assignment_tween.kill()
		modulate = Color.WHITE
		if call_id != -1 and state == "LIVE":
			# Cosmetic arrival pulse. Busy/available always comes from the model.
			modulate = Color(0.65, 1.0, 0.9)
			_assignment_tween = create_tween()
			_assignment_tween.tween_property(self, "modulate", Color.WHITE, 0.25)
		_displayed_call_id = call_id
	call_progress.visible = not lead.is_empty()
	status_label.visible = staffed and state != "PREPARE"
	tooltip_text = "Select this workstation to plan its assignment. Intake priority stays with the seat." if state == "PREPARE" else ""
	if not staffed:
		status_label.text = "OPEN SEAT"
		status_label.add_theme_color_override("font_color", Color(0.62, 0.69, 0.8))
	elif lead.is_empty():
		status_label.text = "DAY CLOSED" if state == "CLOSED" else "READY"
		if break_remaining > 0.0 and state in ["LIVE", "PAUSED"]:
			status_label.text = "BREAK · %.1fs left" % break_remaining
		elif not completed.is_empty() and state in ["LIVE", "PAUSED"]:
			status_label.text = "DONE #%03d · READY" % completed["id"]
		status_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.25))
	else:
		var prefix := "RECYCLING" if lead.get("recovery", false) else "ON CALL"
		if state == "PAUSED":
			prefix = "PAUSED"
		elif state == "CLOSED":
			prefix = "UNFINISHED"
		status_label.text = "%s #%03d" % [prefix, lead["id"]]
		status_label.add_theme_color_override("font_color",
			Color(0.29, 0.94, 0.82) if state == "LIVE" else Color(0.98, 0.72, 0.25))
		call_progress.max_value = 1.0
		call_progress.value = float(lead.get("progress", 0.0))
		tooltip_text = "Call #%03d · Potential sale $%d" % [lead["id"], lead["value"]]
