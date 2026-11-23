extends PanelContainer
class_name HRPanel
## Planning department view. Employment and compensation state belongs to Workday.

signal hire_requested(employee_id: String)
signal fire_requested(employee_id: String)
signal commission_changed(employee_id: String, rate_percent: float)

const TEXT := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.57, 0.67, 0.76)
const ACCENT := Color(0.35, 0.88, 0.75)
const WARNING := Color(1.0, 0.72, 0.28)

var cash_label: Label
var feedback_label: Label
var team_list: VBoxContainer
var candidate_list: VBoxContainer
var _employees: Array[Dictionary] = []
var _pay_labels: Dictionary = {}
var _cash := 0
var _editable := true
var _feedback := ""


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _panel_style(Color(0.17, 0.33, 0.40), Color(0.035, 0.052, 0.082)))
	_build()
	_refresh()


func show_state(employees: Array[Dictionary], cash: int, editable := true, feedback := "") -> void:
	_employees = employees.duplicate(true)
	_cash = cash
	_editable = editable
	_feedback = feedback
	if is_node_ready():
		_refresh()


func update_commission_estimate(employee_id: String, estimate: int) -> void:
	if not _pay_labels.has(employee_id):
		return
	var summary: Dictionary = _pay_labels[employee_id]
	_format_pay_summary(summary["label"], summary["base"], estimate, summary["expectation"])


func _format_pay_summary(label: Label, base: int, estimate: int, expectation: int) -> void:
	label.text = "BASE $%d / SHIFT   ·   EST. COMMISSION $%d   ·   EXPECTS $%d TOTAL" % [base, estimate, expectation]
	if base + estimate < expectation:
		label.text += "   ·   BELOW EXPECTATION"


func _build() -> void:
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := _label("HUMAN RESOURCES", 22, ACCENT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	cash_label = _label("", 17, WARNING)
	header.add_child(cash_label)
	var description := _label("Set commission before the shift. Reps earn commission on closed sales and quit if their shift pay falls below their expectation.", 12, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	team_list = _add_list(tabs, "Team")
	candidate_list = _add_list(tabs, "Recruitment")
	feedback_label = _label("", 12, MUTED)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(feedback_label)


func _add_list(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


func _refresh() -> void:
	cash_label.text = "COMPANY CASH  $%d" % _cash
	feedback_label.text = _feedback
	_pay_labels.clear()
	for list: VBoxContainer in [team_list, candidate_list]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	var owned_count := 0
	var candidate_count := 0
	for employee in _employees:
		if bool(employee.get("owned", false)):
			_add_employee(team_list, employee, true)
			owned_count += 1
		elif not bool(employee.get("unavailable", false)):
			_add_employee(candidate_list, employee, false)
			candidate_count += 1
	if owned_count == 0:
		team_list.add_child(_label("No employed reps. Open Recruitment to hire a salesperson.", 14, MUTED))
	if candidate_count == 0:
		candidate_list.add_child(_label("No candidates are available.", 14, MUTED))


func _add_employee(parent: VBoxContainer, employee: Dictionary, owned: bool) -> void:
	var employee_id := str(employee.get("id", ""))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.21, 0.40, 0.45), Color(0.045, 0.065, 0.10)))
	parent.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	card.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var name_label := _label("%s · %s" % [employee.get("name", employee_id), employee.get("archetype", "Salesperson")], 16, TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)
	var action := Button.new()
	action.custom_minimum_size = Vector2(105, 32)
	header.add_child(action)
	if owned:
		action.text = "FIRE REP"
		action.disabled = not _editable
		action.pressed.connect(func() -> void: fire_requested.emit(employee_id))
	else:
		var hiring_cost := int(employee.get("hiring_cost", 100))
		action.text = "HIRE · $%d" % hiring_cost
		action.disabled = not _editable or _cash < hiring_cost or not bool(employee.get("can_hire", true))
		action.pressed.connect(func() -> void: hire_requested.emit(employee_id))
	var base_salary := int(employee.get("base_salary", 0))
	var estimated_commission := int(employee.get("estimated_commission", 0))
	var expectation := int(employee.get("earnings_expectation", base_salary))
	var pay := _label("", 12, WARNING)
	_format_pay_summary(pay, base_salary, estimated_commission, expectation)
	if owned:
		_pay_labels[employee_id] = {"label": pay, "base": base_salary, "expectation": expectation}
	pay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pay.tooltip_text = "Estimated commission depends on the planned leads, seat order, and sales performance. Actual commission is earned only on closed sales."
	content.add_child(pay)
	var terms := HBoxContainer.new()
	terms.add_theme_constant_override("separation", 10)
	content.add_child(terms)
	terms.add_child(_label("COMMISSION", 11, MUTED))
	var commission := SpinBox.new()
	commission.min_value = 0.0
	commission.max_value = 100.0
	commission.step = 1.0
	commission.suffix = "%"
	commission.value = float(employee.get("commission_rate", 10.0))
	commission.editable = owned and _editable
	commission.custom_minimum_size = Vector2(100, 30)
	commission.value_changed.connect(func(value: float) -> void: commission_changed.emit(employee_id, value))
	terms.add_child(commission)
	var assignment := "ON FLOOR" if bool(employee.get("seated", false)) else "IN RESERVE"
	if not owned:
		assignment = "JOINS RESERVE"
	var experience := int(employee.get("experience", 0))
	terms.add_child(_label("%s · %d SHIFTS EXPERIENCE" % [assignment, experience], 11, MUTED))
	if owned and employee.has("last_earnings"):
		var last_earnings := int(employee["last_earnings"])
		var last_pay := _label("LAST SHIFT PAY $%d / EXPECTED $%d" % [last_earnings, int(employee.get("last_expectation", expectation))], 11, MUTED)
		content.add_child(last_pay)
	if not str(employee.get("status", "")).is_empty():
		var status := _label(str(employee["status"]), 11, MUTED)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(status)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(border: Color, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(4)
	style.set_content_margin_all(9)
	return style
