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
@onready var rows: HBoxContainer = $Margin/Content/QueueScroll/QueueContent/Rows
@onready var empty_label: Label = $Margin/Content/QueueScroll/QueueContent/EmptyState
@onready var more_label: Label = $Margin/Content/MoreWaiting
@onready var dispatch_label: Label = $Margin/Content/LastDispatch
@onready var abandoned_label: Label = $Margin/Content/Abandoned
@onready var discard_label: Label = $Margin/Content/DiscardPile
@onready var order_caption: Label = $Margin/Content/OrderCaption


func _ready() -> void:
	var content := $Margin/Content as HBoxContainer
	var summary := VBoxContainer.new()
	summary.custom_minimum_size.x = 280
	summary.add_theme_constant_override("separation", 3)
	var queue_column := VBoxContainer.new()
	queue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_column.add_theme_constant_override("separation", 4)
	var summary_nodes: Array[Control] = [
		state_label.get_parent() as Control,
		waiting_label.get_parent() as Control,
		on_call_label.get_parent().get_parent() as Control,
		$Margin/Content/Divider as Control,
		abandoned_label,
		discard_label,
		dispatch_label,
	]
	for node in summary_nodes:
		node.get_parent().remove_child(node)
		summary.add_child(node)
	var queue_nodes: Array[Control] = [
		$Margin/Content/OrderCaption as Control,
		$Margin/Content/QueueScroll as Control,
		more_label,
	]
	for node in queue_nodes:
		node.get_parent().remove_child(node)
		queue_column.add_child(node)
	content.add_child(summary)
	content.add_child(queue_column)
	var summary_labels: Array[Label] = [abandoned_label, discard_label, dispatch_label]
	for label in summary_labels:
		label.add_theme_font_size_override("font_size", 10)
		label.clip_text = true
	waiting_label.add_theme_font_size_override("font_size", 26)
	for child: Node in rows.get_children():
		var row := child as PanelContainer
		row.custom_minimum_size = Vector2(86, 58)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var margin := row.get_node("Margin") as MarginContainer
		margin.add_theme_constant_override("margin_left", 7)
		margin.add_theme_constant_override("margin_right", 7)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
	var scroll := rows.get_parent().get_parent() as ScrollContainer
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resized.connect(_update_layout)
	call_deferred("_update_layout")


func _update_layout() -> void:
	if rows == null:
		return
	var compact := size.y < 150.0
	var summary := state_label.get_parent().get_parent() as VBoxContainer
	summary.add_theme_constant_override("separation", 0 if compact else 3)
	var queue_column := rows.get_parent().get_parent().get_parent() as VBoxContainer
	queue_column.add_theme_constant_override("separation", 2 if compact else 4)
	var panel_margin := $Margin as MarginContainer
	panel_margin.add_theme_constant_override("margin_top", 4 if compact else 6)
	panel_margin.add_theme_constant_override("margin_bottom", 4 if compact else 6)
	var title_label := state_label.get_parent().get_node("Title") as Label
	title_label.add_theme_font_size_override("font_size", 12 if compact else 14)
	state_label.add_theme_font_size_override("font_size", 9 if compact else 11)
	waiting_label.add_theme_font_size_override("font_size", 20 if compact else 26)
	(waiting_label.get_parent().get_node("Caption") as Label).add_theme_font_size_override(
		"font_size", 10 if compact else 14
	)
	var metric_labels: Array[Label] = [on_call_label, handled_label, received_label]
	for value_label in metric_labels:
		value_label.add_theme_font_size_override("font_size", 15 if compact else 20)
		(value_label.get_parent().get_node("Caption") as Label).add_theme_font_size_override(
			"font_size", 9 if compact else 10
		)
	var activity_labels: Array[Label] = [abandoned_label, discard_label, dispatch_label]
	for label in activity_labels:
		label.add_theme_font_size_override("font_size", 9 if compact else 10)
	order_caption.add_theme_font_size_override("font_size", 9 if compact else 11)
	empty_label.add_theme_font_size_override("font_size", 11 if compact else 14)
	var scroll := rows.get_parent().get_parent() as ScrollContainer
	scroll.custom_minimum_size.y = 48 if compact else 68
	for child: Node in rows.get_children():
		var row := child as PanelContainer
		row.custom_minimum_size.y = 46 if compact else 58


func update_queue(waiting_calls: Array[Dictionary], active_count: int, handled_count: int, received_count: int, state: String, last_dispatch: String, abandoned_count: int, discarded_count: int, elapsed_ticks: float) -> void:
	waiting_label.text = _format_number(waiting_calls.size())
	on_call_label.text = _format_number(active_count)
	handled_label.text = _format_number(handled_count)
	received_label.text = _format_number(received_count)
	abandoned_label.text = "Left while waiting  %d" % abandoned_count
	discard_label.text = "Lead discard pile  %d" % discarded_count
	state_label.text = {"PREPARE": "READY", "LIVE": "LIVE", "PAUSED": "PAUSED", "CLOSED": "CLOSED"}.get(state, state)
	state_label.add_theme_color_override("font_color", CYAN if state == "LIVE" else (AMBER if state == "PAUSED" else MUTED))

	for index in range(MAX_VISIBLE_CALLS):
		var row := rows.get_child(index) as PanelContainer
		row.visible = index < waiting_calls.size()
		if row.visible:
			var lead: Dictionary = waiting_calls[index]
			var call_label := row.get_node("Margin/Content/CallId") as Label
			var value_label := row.get_node("Margin/Content/Value") as Label
			call_label.text = "Call #%03d" % lead["id"]
			var time_left := maxf(0.0, float(lead["patience_ticks"]) - elapsed_ticks + float(lead["arrived_tick"]))
			call_label.tooltip_text = "%s · Leaves after %.1fs more waiting" % [call_label.text, time_left * CallQueueSimulation.TICK_SECONDS]
			call_label.add_theme_color_override("font_color", AMBER if time_left <= 2 else Color(0.94, 0.96, 1))
			value_label.text = "$%s" % _format_number(int(lead["value"]))
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
