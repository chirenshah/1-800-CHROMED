extends PanelContainer
class_name CallQueuePanel

const MAX_VISIBLE_CALLS := 6
const CYAN := Color(0.29, 0.94, 0.82)
const AMBER := Color(0.98, 0.72, 0.25)
const MUTED := Color(0.62, 0.69, 0.8)

@onready var state_label: Label = $Margin/Content/Header/State
@onready var waiting_label: Label = $Margin/Content/Waiting/Count
@onready var on_call_label: Label = $Margin/Content/Metrics/OnCall/Value
@onready var handled_label: Label = $Margin/Content/Metrics/Handled/Value
@onready var received_label: Label = $Margin/Content/Metrics/Received/Value
@onready var rows: VBoxContainer = $Margin/Content/QueueScroll/QueueContent/Rows
@onready var empty_label: Label = $Margin/Content/QueueScroll/QueueContent/EmptyState
@onready var more_label: Label = $Margin/Content/MoreWaiting
@onready var dispatch_label: Label = $Margin/Content/LastDispatch
@onready var abandoned_label: Label = $Margin/Content/Abandoned


func update_queue(waiting_calls: Array[Dictionary], active_count: int, handled_count: int, received_count: int, state: String, last_dispatch: String, abandoned_count: int, elapsed_ticks: int) -> void:
	waiting_label.text = _format_number(waiting_calls.size())
	on_call_label.text = _format_number(active_count)
	handled_label.text = _format_number(handled_count)
	received_label.text = _format_number(received_count)
	abandoned_label.text = "Left while waiting  %d" % abandoned_count
	state_label.text = {"PREPARE": "READY", "LIVE": "LIVE", "PAUSED": "PAUSED", "CLOSED": "CLOSED"}.get(state, state)
	state_label.add_theme_color_override("font_color", CYAN if state == "LIVE" else (AMBER if state == "PAUSED" else MUTED))

	for index in range(MAX_VISIBLE_CALLS):
		var row := rows.get_child(index) as PanelContainer
		row.visible = index < waiting_calls.size()
		if row.visible:
			var call: Dictionary = waiting_calls[index]
			var call_label := row.get_node("Margin/Content/CallId") as Label
			var value_label := row.get_node("Margin/Content/Value") as Label
			call_label.text = "Call #%03d" % call["id"]
			var time_left := maxi(0, int(call["patience_ticks"]) - elapsed_ticks + int(call["arrived_tick"]))
			call_label.tooltip_text = "%s · Leaves after %.1fs more waiting" % [call_label.text, time_left * CallQueueSimulation.TICK_SECONDS]
			call_label.add_theme_color_override("font_color", AMBER if time_left <= 2 else Color(0.94, 0.96, 1))
			value_label.text = "$%s" % _format_number(int(call["value"]))
			value_label.tooltip_text = value_label.text

	rows.visible = not waiting_calls.is_empty()
	empty_label.visible = waiting_calls.is_empty()
	match state:
		"PREPARE":
			empty_label.text = "Calls arrive when the workday starts."
		"PAUSED":
			empty_label.text = "No calls waiting. Resume the workday to keep calls moving."
		"CLOSED":
			empty_label.text = "No calls waiting. The workday is complete."
		_:
			empty_label.text = "Queue clear. New calls will appear here."

	var remaining := maxi(0, waiting_calls.size() - MAX_VISIBLE_CALLS)
	more_label.visible = remaining > 0
	more_label.text = "+ %s more waiting" % _format_number(remaining)
	dispatch_label.text = last_dispatch if not last_dispatch.strip_edges().is_empty() else "No calls assigned yet."
	dispatch_label.tooltip_text = dispatch_label.text


func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + output
