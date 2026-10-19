extends PanelContainer
class_name ReportPanel

signal next_day_requested

@onready var title_label: Label = $Margin/Scroll/Content/Title
@onready var revenue_label: Label = $Margin/Scroll/Content/RevenueLabel
@onready var calls_label: Label = $Margin/Scroll/Content/CallsLabel
@onready var conversion_label: Label = $Margin/Scroll/Content/ConversionLabel
@onready var normal_sales_label: Label = $Margin/Scroll/Content/NormalSalesLabel
@onready var total_sales_label: Label = $Margin/Scroll/Content/TotalSalesLabel
@onready var failed_label: Label = $Margin/Scroll/Content/FailedLabel
@onready var discarded_label: Label = $Margin/Scroll/Content/DiscardedLabel
@onready var recovery_label: Label = $Margin/Scroll/Content/RecoveryLabel
@onready var recovery_revenue_label: Label = $Margin/Scroll/Content/RecoveryRevenueLabel
@onready var recycler_utilization_label: Label = $Margin/Scroll/Content/RecyclerUtilizationLabel
@onready var received_label: Label = $Margin/Scroll/Content/ReceivedLabel
@onready var waiting_label: Label = $Margin/Scroll/Content/WaitingLabel
@onready var unfinished_label: Label = $Margin/Scroll/Content/UnfinishedLabel
@onready var abandoned_label: Label = $Margin/Scroll/Content/AbandonedLabel
@onready var employee_rows: VBoxContainer = $Margin/Scroll/Content/EmployeeRows
@onready var insight_label: Label = $Margin/Scroll/Content/Insight
@onready var next_day_button: Button = $Margin/Scroll/Content/NextDayButton


func _ready() -> void:
	next_day_button.pressed.connect(func() -> void: next_day_requested.emit())


func show_results(day: int, revenue: int, calls: int, normal_sales: int, sales: int, failed: int, discarded: int, recovery_attempts: int, recovered: int, failed_recoveries: int, recovered_revenue: int, received: int, waiting: int, unfinished: int, abandoned: int, workload: Array[Dictionary]) -> void:
	var conversion := 0.0 if calls == 0 else float(normal_sales) / float(calls) * 100.0
	title_label.text = "Day %d Performance" % day
	revenue_label.text = "Revenue  $%s" % _format_number(revenue)
	calls_label.text = "Calls handled  %d" % calls
	conversion_label.text = "Normal conversion  %.0f%%" % conversion
	normal_sales_label.text = "Successful normal conversions  %d" % normal_sales
	total_sales_label.text = "Total successful conversions  %d" % sales
	failed_label.text = "Failed normal interactions  %d" % failed
	discarded_label.text = "Leads discarded  %d" % discarded
	recovery_label.text = "Recycler attempts  %d · recovered  %d · failed  %d" % [
		recovery_attempts, recovered, failed_recoveries
	]
	recovery_revenue_label.text = "Revenue recovered  $%s" % _format_number(recovered_revenue)
	received_label.text = "Incoming calls  %d" % received
	waiting_label.text = "Waiting at close  %d" % waiting
	unfinished_label.text = "Unfinished calls  %d" % unfinished
	abandoned_label.text = "Left while waiting  %d" % abandoned
	insight_label.text = _build_insight(calls, conversion, received, waiting, abandoned)
	var recycler_busy_ticks := 0.0
	var recycler_total_ticks := 0.0
	for row in employee_rows.get_children():
		employee_rows.remove_child(row)
		row.queue_free()
	for employee in workload:
		var busy_ticks := float(employee["busy_ticks"])
		var idle_ticks := float(employee["idle_ticks"])
		if employee.get("archetype", "") == "Recycler":
			recycler_busy_ticks += busy_ticks
			recycler_total_ticks += busy_ticks + idle_ticks
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 13)
		row.text = "Seat %02d · %s · %s\nAssigned %d · Handled %d\nSales %d · $%s\nBusy %.1fs · Idle %.1fs" % [
			int(employee["seat"]) + 1, employee["name"], employee.get("archetype", ""),
			employee["assigned"], employee["handled"],
			employee["sales"], _format_number(int(employee["revenue"])),
			busy_ticks * CallQueueSimulation.TICK_SECONDS,
			idle_ticks * CallQueueSimulation.TICK_SECONDS,
		]
		employee_rows.add_child(row)
	if recycler_total_ticks == 0.0:
		recycler_utilization_label.text = "Recycler utilization  N/A"
	else:
		recycler_utilization_label.text = "Recycler utilization  %.0f%%" % (
			recycler_busy_ticks / recycler_total_ticks * 100.0
		)
	# Each new day opens at the aggregate results, even after scrolling an old report.
	$Margin/Scroll.scroll_vertical = 0


func _build_insight(calls: int, conversion: float, received: int, waiting: int, abandoned: int) -> String:
	if received == 0:
		return "No activity was recorded. Check the incoming lead source before the next day."
	if abandoned > 0:
		return "%d callers left before anyone could answer. Review who received the early calls and how long the team stayed busy." % abandoned
	if calls == 0:
		return "The day ended before any calls finished. Waiting and unfinished calls are shown separately above."
	if waiting > 0:
		return "Demand exceeded available capacity. %d calls were still waiting at close." % waiting
	if conversion < 20.0:
		return "The floor handled demand, but few calls converted. Review the team's completed interactions."
	return "The floor converted demand reliably. Look for idle capacity before increasing lead volume."


func _format_number(value: int) -> String:
	var digits := str(value)
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	return digits + output
