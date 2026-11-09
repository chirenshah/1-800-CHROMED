extends PanelContainer
class_name ReportPanel

signal next_day_requested
signal reward_option_selected(index: int)
signal reward_claim_requested(index: int)
signal reward_install_requested(index: int, employee_id: String, slot_index: int)
signal reward_skip_requested
signal reward_manage_requested

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
@onready var finance_label: Label = $Margin/Scroll/Content/FinanceLabel
@onready var discipline_label: Label = $Margin/Scroll/Content/DisciplineLabel
@onready var termination_label: Label = $Margin/Scroll/Content/TerminationLabel
@onready var next_day_button: Button = $Margin/Scroll/Content/NextDayButton
@onready var reward_status_label: Label = $Margin/Scroll/Content/RewardStatus
@onready var reward_buttons: Array[Button] = [
	$Margin/Scroll/Content/RewardOptions/Reward1,
	$Margin/Scroll/Content/RewardOptions/Reward2,
	$Margin/Scroll/Content/RewardOptions/Reward3,
]
@onready var reward_employee_selector: OptionButton = $Margin/Scroll/Content/RewardTargetRow/RewardEmployee
@onready var reward_slot_selector: OptionButton = $Margin/Scroll/Content/RewardTargetRow/RewardSlot
@onready var reward_claim_button: Button = $Margin/Scroll/Content/RewardClaimButton
@onready var reward_install_button: Button = $Margin/Scroll/Content/RewardInstallButton
@onready var reward_skip_button: Button = $Margin/Scroll/Content/RewardSkipButton
@onready var reward_manage_button: Button = $Margin/Scroll/Content/RewardManageButton

var _reward_pending := false
var _reward_employee_options: Array[Dictionary] = []


func _ready() -> void:
	next_day_button.pressed.connect(func() -> void: next_day_requested.emit())
	for index in reward_buttons.size():
		reward_buttons[index].toggle_mode = true
		reward_buttons[index].pressed.connect(_on_reward_option_pressed.bind(index))
	reward_employee_selector.item_selected.connect(func(_index: int) -> void: _refresh_reward_slots())
	reward_claim_button.pressed.connect(_claim_reward)
	reward_install_button.pressed.connect(_install_reward)
	reward_skip_button.pressed.connect(func() -> void: reward_skip_requested.emit())
	reward_manage_button.pressed.connect(func() -> void: reward_manage_requested.emit())
	_set_reward_controls_visible(false)


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
		var break_ticks := float(employee.get("break_ticks", 0.0))
		if employee.get("archetype", "") == "Recycler":
			recycler_busy_ticks += busy_ticks
			recycler_total_ticks += busy_ticks + idle_ticks + break_ticks
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 13)
		row.text = "Seat %02d · %s · %s\nAssigned %d · Handled %d\nSales %d · $%s\nCalling %.1fs · Break %.1fs (%d) · Idle %.1fs" % [
			int(employee["seat"]) + 1, employee["name"], employee.get("archetype", ""),
			employee["assigned"], employee["handled"],
			employee["sales"], _format_number(int(employee["revenue"])),
			busy_ticks * CallQueueSimulation.TICK_SECONDS,
			break_ticks * CallQueueSimulation.TICK_SECONDS, int(employee.get("breaks_taken", 0)),
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


func show_financial_results(finance: Dictionary) -> void:
	var reasons: Array = finance.get("failure_reasons", [])
	var reason_text := "None"
	if reasons.has("revenue_goal_missed") and reasons.has("current_upkeep_unpaid"):
		reason_text = "Revenue goal missed; current-day payroll unpaid"
	elif reasons.has("revenue_goal_missed"):
		reason_text = "Revenue goal missed"
	elif reasons.has("current_upkeep_unpaid"):
		reason_text = "Current-day payroll unpaid"
	var payroll_result := "Covered" if finance.get("payroll_met", false) else "SHORT $%s" % _format_number(int(finance.get("current_upkeep_shortfall", 0)))
	var goal_result := "Met" if finance.get("goal_met", false) else "Missed"
	var augment_cash_net := int(finance.get("augment_cash_effect_net", 0))
	var augment_cash_text := ("+" if augment_cash_net >= 0 else "-") \
		+ "$" + _format_number(absi(augment_cash_net))
	finance_label.text = "DAILY SALES  $%s · CREDITED TO CASH  +$%s\nCASH FLOW  Opening $%s · Augment effects %s · Before payroll $%s\nUPKEEP  $%s (Floor $%s · Bench $%s) · Paid $%s\nDEBT  $%s brought forward → $%s remaining\nENDING CASH  $%s\nRevenue goal: %s · Payroll: %s" % [
		_format_number(int(finance.get("gross_revenue", 0))),
		_format_number(int(finance.get("sales_cash_credited", 0))),
		_format_number(int(finance.get("day_opening_cash", finance.get("opening_cash", 0)))),
		augment_cash_text,
		_format_number(int(finance.get("cash_before_payroll", 0))),
		_format_number(int(finance.get("current_upkeep", 0))),
		_format_number(int(finance.get("active_upkeep", 0))),
		_format_number(int(finance.get("bench_upkeep", 0))),
		_format_number(int(finance.get("paid_current_upkeep", 0))),
		_format_number(int(finance.get("debt_brought_forward", 0))),
		_format_number(int(finance.get("debt_remaining", 0))),
		_format_number(int(finance.get("ending_cash", 0))),
		goal_result, payroll_result,
	]
	discipline_label.text = "Write-up today: %s · Total: %d / %d\nReasons: %s" % [
		"YES" if finance.get("writeup_issued", false) else "NO",
		int(finance.get("total_writeups", 0)), FinancialLedger.WRITEUPS_TO_TERMINATE, reason_text,
	]
	var terminated := bool(finance.get("terminated", false))
	termination_label.visible = terminated
	if terminated:
		termination_label.text = "EMPLOYMENT TERMINATED\nThree cumulative write-ups. This report preserves today's failure reasons."
	next_day_button.visible = not terminated
	next_day_button.disabled = terminated or _reward_pending


func show_reward(reward: Dictionary, employee_options: Array[Dictionary], inventory_full: bool) -> void:
	_reward_pending = not reward.is_empty()
	_reward_employee_options = employee_options.duplicate(true)
	_set_reward_controls_visible(_reward_pending)
	if not _reward_pending:
		reward_status_label.text = "No pending reward."
		next_day_button.disabled = false
		return
	var choices: Array = reward.get("choices", [])
	var selected_index := int(reward.get("selected_index", 0))
	for index in reward_buttons.size():
		var button := reward_buttons[index]
		button.visible = index < choices.size()
		button.disabled = index >= choices.size()
		button.button_pressed = index == selected_index
		if index >= choices.size():
			continue
		var augment := AugmentManager.CATALOG.profile(str(choices[index]))
		button.text = "%s · %s\n%s" % [
			augment.get("name", choices[index]), augment.get("rarity", "Common"), _reward_effect_text(augment)
		]
	reward_status_label.text = "Choose one of %d augments. Unchosen options are forfeited." % choices.size()
	reward_employee_selector.clear()
	for index in _reward_employee_options.size():
		var employee: Dictionary = _reward_employee_options[index]
		reward_employee_selector.add_item(str(employee.get("name", employee["id"])))
		reward_employee_selector.set_item_metadata(index, employee["id"])
	if not _reward_employee_options.is_empty():
		reward_employee_selector.select(0)
	_refresh_reward_slots()
	reward_claim_button.disabled = inventory_full
	reward_claim_button.tooltip_text = "Inventory is full; install directly or manage the team to free a slot." if inventory_full else "Add the selected augment to the shared item inventory."
	reward_skip_button.disabled = false
	reward_manage_button.disabled = false
	reward_install_button.disabled = reward_slot_selector.item_count == 0
	next_day_button.disabled = true


func show_reward_resolved() -> void:
	_reward_pending = false
	_set_reward_controls_visible(false)
	reward_status_label.text = "Daily reward resolved."
	next_day_button.disabled = false


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


func _set_reward_controls_visible(show_controls: bool) -> void:
	$Margin/Scroll/Content/RewardOptions.visible = show_controls
	$Margin/Scroll/Content/RewardTargetRow.visible = show_controls
	reward_claim_button.visible = show_controls
	reward_install_button.visible = show_controls
	reward_skip_button.visible = show_controls
	reward_manage_button.visible = show_controls


func _refresh_reward_slots() -> void:
	reward_slot_selector.clear()
	if reward_employee_selector.selected < 0:
		reward_install_button.disabled = true
		return
	var employee_id: String = reward_employee_selector.get_item_metadata(reward_employee_selector.selected)
	for employee: Dictionary in _reward_employee_options:
		if employee.get("id", "") != employee_id:
			continue
		var loadout: Array = employee.get("equipment", [])
		var slot_limit := int(employee.get("slot_limit", 1))
		for slot_index in slot_limit:
			var label := "Slot %d · Empty" % (slot_index + 1)
			if slot_index < loadout.size():
				var old_augment := AugmentManager.CATALOG.profile(str(loadout[slot_index].get("augment_id", "")))
				label = "Slot %d · Replace %s (destroyed)" % [slot_index + 1, old_augment.get("name", "augment")]
			var option_index := reward_slot_selector.item_count
			reward_slot_selector.add_item(label)
			reward_slot_selector.set_item_metadata(option_index, slot_index)
		break
	if reward_slot_selector.item_count > 0:
		reward_slot_selector.select(0)
	reward_install_button.disabled = not _reward_pending or reward_slot_selector.item_count == 0


func _claim_reward() -> void:
	var index := _selected_reward_index()
	if index >= 0:
		reward_claim_requested.emit(index)


func _on_reward_option_pressed(index: int) -> void:
	for button_index in reward_buttons.size():
		reward_buttons[button_index].set_pressed_no_signal(button_index == index)
	reward_option_selected.emit(index)


func _install_reward() -> void:
	var reward_index := _selected_reward_index()
	if reward_index < 0 or reward_employee_selector.selected < 0 or reward_slot_selector.selected < 0:
		return
	reward_install_requested.emit(
		reward_index,
		str(reward_employee_selector.get_item_metadata(reward_employee_selector.selected)),
		int(reward_slot_selector.get_item_metadata(reward_slot_selector.selected))
	)


func _selected_reward_index() -> int:
	for index in reward_buttons.size():
		if reward_buttons[index].visible and reward_buttons[index].button_pressed:
			return index
	return -1


func _reward_effect_text(augment: Dictionary) -> String:
	if augment.has("stat") and augment.has("bonus"):
		return "+%d pp %s" % [int(augment["bonus"]), str(augment["stat"]).capitalize()]
	return str(augment.get("description", "Rule-changing effect"))


func _format_number(value: int) -> String:
	var digits := str(value)
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	return digits + output
