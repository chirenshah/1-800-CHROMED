extends PanelContainer
class_name EmployeeCard

signal seat_selected(seat: int)

@onready var seat_label: Label = $Margin/Content/Seat
@onready var name_label: Label = $Margin/Content/Name
@onready var role_label: Label = $Margin/Content/Role
@onready var status_label: Label = $Margin/Content/Status
@onready var call_progress: ProgressBar = $Margin/Content/CallProgress

var staffed := false
var seat_number := 0
var employee_id := ""
var planning_enabled := false
var selected := false
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _empty_style: StyleBoxFlat
var _displayed_call_id := -1
var _assignment_tween: Tween


func _ready() -> void:
	_normal_style = get_theme_stylebox("panel").duplicate()
	_selected_style = _normal_style.duplicate()
	_selected_style.border_color = Color(0.29, 0.94, 0.82)
	_selected_style.set_border_width_all(2)
	_empty_style = _normal_style.duplicate()
	_empty_style.bg_color = Color(0.035, 0.05, 0.08)
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)


func configure(number: int, employee: Dictionary) -> void:
	seat_number = number
	employee_id = employee.get("id", "")
	seat_label.text = "SEAT %02d  /  INTAKE %02d" % [number, number]
	name_label.text = employee.get("name", "Unassigned")
	role_label.text = employee.get("archetype", "Open workstation")
	staffed = not employee_id.is_empty()
	_refresh_style()


func set_planning_state(editable: bool, is_selected: bool) -> void:
	planning_enabled = editable
	selected = is_selected and editable
	focus_mode = Control.FOCUS_ALL if editable else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if editable else Control.CURSOR_ARROW
	_refresh_style()


func set_compact(compact: bool) -> void:
	custom_minimum_size = Vector2(134, 86 if compact else 112)
	name_label.add_theme_font_size_override("font_size", 16 if compact else 18)
	seat_label.add_theme_font_size_override("font_size", 10 if compact else 11)
	role_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	status_label.add_theme_font_size_override("font_size", 10 if compact else 12)
	$Margin/Content.add_theme_constant_override("separation", 1 if compact else 4)
	for edge in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + edge, 6 if compact else 10)


func _refresh_style() -> void:
	if _normal_style == null:
		return
	var style := _normal_style if staffed else _empty_style
	if selected or (planning_enabled and has_focus()):
		style = _selected_style
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if not planning_enabled:
		return
	var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if clicked or event.is_action_pressed("ui_accept"):
		grab_focus()
		accept_event()
		seat_selected.emit(seat_number - 1)


func show_call(call: Dictionary, state: String, completed: Dictionary = {}) -> void:
	var call_id := int(call.get("id", -1))
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
	call_progress.visible = not call.is_empty()
	tooltip_text = "Select this workstation to plan its assignment. Intake priority stays with the seat." if state == "PREPARE" else ""
	if not staffed:
		status_label.text = "OPEN SEAT"
		status_label.add_theme_color_override("font_color", Color(0.62, 0.69, 0.8))
	elif call.is_empty():
		status_label.text = "DAY CLOSED" if state == "CLOSED" else "READY"
		if not completed.is_empty() and state in ["LIVE", "PAUSED"]:
			status_label.text = "DONE #%03d · READY" % completed["id"]
		status_label.add_theme_color_override("font_color", Color(0.98, 0.72, 0.25))
	else:
		var prefix := "ON CALL"
		if state == "PAUSED":
			prefix = "PAUSED"
		elif state == "CLOSED":
			prefix = "UNFINISHED"
		status_label.text = "%s #%03d" % [prefix, call["id"]]
		status_label.add_theme_color_override("font_color",
			Color(0.29, 0.94, 0.82) if state == "LIVE" else Color(0.98, 0.72, 0.25))
		call_progress.max_value = call["duration"]
		call_progress.value = int(call["duration"]) - int(call["remaining"])
		tooltip_text = "Call #%03d · Potential sale $%d" % [call["id"], call["value"]]

