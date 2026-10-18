extends PanelContainer
class_name EmployeeCard

@onready var seat_label: Label = $Margin/Content/Seat
@onready var name_label: Label = $Margin/Content/Name
@onready var role_label: Label = $Margin/Content/Role
@onready var status_label: Label = $Margin/Content/Status


func setup(seat_number: int, display_name: String, role: String) -> void:
	seat_label.text = "SEAT %02d" % seat_number
	name_label.text = display_name
	role_label.text = role
	set_working(false)


func set_working(is_working: bool) -> void:
	status_label.text = "ON CALL" if is_working else "READY"
	status_label.modulate = Color(0.29, 0.94, 0.82) if is_working else Color(0.98, 0.72, 0.25)

