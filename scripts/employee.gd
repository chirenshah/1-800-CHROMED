extends PanelContainer
class_name EmployeeCard

@onready var seat_label: Label = $Margin/Content/Seat
@onready var name_label: Label = $Margin/Content/Name
@onready var role_label: Label = $Margin/Content/Role
@onready var status_label: Label = $Margin/Content/Status
@onready var call_progress: ProgressBar = $Margin/Content/CallProgress

var staffed := false


func setup(seat_number: int, display_name: String, role: String) -> void:
	seat_label.text = "SEAT %02d" % seat_number
	name_label.text = display_name
	role_label.text = role
	staffed = display_name != "Unassigned"
	show_call({}, "PREPARE")


func show_call(call: Dictionary, state: String) -> void:
	call_progress.visible = not call.is_empty()
	tooltip_text = ""
	if not staffed:
		status_label.text = "OPEN SEAT"
		status_label.add_theme_color_override("font_color", Color(0.62, 0.69, 0.8))
	elif call.is_empty():
		status_label.text = "DAY CLOSED" if state == "CLOSED" else "READY"
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

