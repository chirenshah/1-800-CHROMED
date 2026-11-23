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
@onready var finance_summary: Label = $Margin/Scroll/Content/FinanceSummary
@onready var finance_rows: GridContainer = $Margin/Scroll/Content/FinanceRows
@onready var finance_closing: Label = $Margin/Scroll/Content/FinanceClosing
@onready var finance_details: Label = $Margin/Scroll/Content/FinanceDetails
@onready var outcome_label: Label = $Margin/Scroll/Content/OutcomeLabel
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


func show_results(day: int, revenue: int, calls: int, normal_sales: int, sales: int, failed: int, discarded: int, recovery_attempts: int, recovered: int, failed_recoveries: int, recovered_revenue: int, received: int, waiting: int, unfinished: int, abandoned: int, workload: Array[Dictionary], rep_pay: Dictionary = {}, goal: int = 0) -> void:
	var conversion := 0.0 if calls == 0 else float(normal_sales) / float(calls) * 100.0
	title_label.text = "Day %d Results" % day
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
	insight_label.text = _build_insight(revenue, goal, calls, conversion, received, waiting, unfinished, abandoned)
	var recycler_busy_ticks := 0.0
	var recycler_total_ticks := 0.0
	for row in employee_rows.get_children():
		employee_rows.remove_child(row)
		row.queue_free()
	var rows := workload.duplicate()
	var seen := {}
	for employee in workload:
		seen[employee.get("employee_id", "")] = true
	for employee_id in rep_pay:
		if not seen.has(employee_id):
			rows.append({"employee_id": employee_id, "name": rep_pay[employee_id]["name"], "seat": -1})
	for employee in rows:
		var busy_ticks := float(employee.get("busy_ticks", 0))
		var idle_ticks := float(employee.get("idle_ticks", 0))
		var break_ticks := float(employee.get("break_ticks", 0.0))
		if employee.get("archetype", "") == "Recycler":
			recycler_busy_ticks += busy_ticks
			recycler_total_ticks += busy_ticks + idle_ticks + break_ticks
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 13)
		var seat := int(employee.get("seat", -1))
		var location := "Seat %02d" % (seat + 1) if seat >= 0 else "Reserve"
		var handled := int(employee.get("handled", 0))
		var closed := int(employee.get("sales", 0))
		row.text = "%s · %s · %s\nAssigned %d · Handled %d\nSales %d · $%s · Conversion %s" % [
			location, employee["name"], employee.get("archetype", "Sales rep"),
			employee.get("assigned", 0), handled, closed, _format_number(int(employee.get("revenue", 0))),
			"%.0f%%" % (100.0 * closed / handled) if handled > 0 else "—",
		]
		if seat >= 0:
			row.text += "\nCalling %.1fs · Break %.1fs (%d) · Idle %.1fs" % [
				busy_ticks * CallQueueSimulation.TICK_SECONDS,
				break_ticks * CallQueueSimulation.TICK_SECONDS, int(employee.get("breaks_taken", 0)),
				idle_ticks * CallQueueSimulation.TICK_SECONDS,
			]
		var stats: Dictionary = employee.get("shift_stats", {})
		if not stats.is_empty():
			row.text += "\nSpeed %.1f · Close chance %.0f%% · Upsell %.0f%% · Stamina %.1fh" % [
				stats.get("speed", 0), stats.get("conversion", 0),
				stats.get("upsell_chance", 0), FloorPlan.CATALOG.stamina_hours(employee["employee_id"]),
			]
		var pay: Dictionary = rep_pay.get(employee.get("employee_id", ""), {})
		if not pay.is_empty():
			row.text += "\nBase $%s · Commission $%s · Paid $%s / $%s expected" % [
				_format_number(int(pay["base_salary"])), _format_number(int(pay["commission"])),
				_format_number(int(pay["paid"])), _format_number(int(pay["expectation"])),
			]
		employee_rows.add_child(row)
	if recycler_total_ticks == 0.0:
		recycler_utilization_label.text = "Recycler utilization  N/A"
	else:
		recycler_utilization_label.text = "Recycler utilization  %.0f%%" % (
			recycler_busy_ticks / recycler_total_ticks * 100.0
		)
	# Start each report at the cash summary.
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
	var augment_cash_net := int(finance.get("augment_cash_effect_net", 0))
	var augment_cash_text := ("+" if augment_cash_net >= 0 else "-") \
		+ "$" + _format_number(absi(augment_cash_net))
	finance_label.text = "DAILY SALES  $%s / GOAL $%s · SURPLUS TO CASH  +$%s\nCASH FLOW  Opening $%s · Augment effects %s · Before payroll $%s\nUPKEEP  $%s (Floor $%s · Bench $%s) · Paid $%s\nDEBT  $%s brought forward → $%s remaining\nENDING CASH  $%s\nRevenue goal: %s · Payroll: %s" % [
		_format_number(int(finance.get("gross_revenue", 0))),
		_format_number(int(finance.get("sales_goal", 0))),
		_format_number(int(finance.get("sales_cash_credited", 0))),
		_format_number(int(finance.get("day_opening_cash", finance.get("opening_cash", 0)))),
		augment_cash_text,
		_format_number(int(finance.get("cash_before_payroll", 0))),
		_format_number(int(finance.get("current_upkeep", 0))),
		_format_number(int(finance.get("base_payroll", finance.get("current_upkeep", 0)))),
		_format_number(int(finance.get("commission", 0))),
		_format_number(int(finance.get("debt_brought_forward", 0))),
		_format_number(int(finance.get("debt_remaining", 0))),
	]
	var payroll_result := "covered" if finance.get("payroll_met", false) else "short $%s" % _format_number(int(finance.get("current_upkeep_shortfall", 0)))
	var goal_result := "met" if finance.get("goal_met", false) else "missed"
	outcome_label.text = "Sales goal %s  ·  Payroll %s" % [goal_result, payroll_result]
	if finance.has("leads_purchased"):
		outcome_label.text += "\n%s  ·  %d leads purchased" % [
			finance["lead_source_name"], finance["leads_purchased"],
		]
	for departure: Dictionary in finance.get("departures", []):
		outcome_label.text += "\n%s quit after receiving $%s against an earnings expectation of $%s." % [
			departure["name"], _format_number(int(departure["paid"])),
			_format_number(int(departure["expectation"])),
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


func _add_finance_row(label_text: String, value_text: String) -> void:
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.86))
	finance_rows.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	finance_rows.add_child(value_label)


func _signed_cash(amount: int) -> String:
	return ("+" if amount >= 0 else "-") + "$" + _format_number(absi(amount))


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


func _build_insight(revenue: int, goal: int, calls: int, conversion: float, received: int, waiting: int, unfinished: int, abandoned: int) -> String:
	if received == 0:
		return "No calls arrived. Review the lead order in Marketing before the next shift."
	if abandoned > 0:
		return "%d callers left before an answer. Review seat capacity and call handling time before buying more leads." % abandoned
	if calls == 0:
		return "No calls finished. Check the unfinished calls and team speed before the next shift."
	if waiting > 0:
		return "%d calls were still waiting at close. Review team capacity before increasing the lead order." % waiting
	if unfinished > 0:
		return "%d calls were still in progress at close. Review handling time and shift timing." % unfinished
	if conversion < 20.0:
		return "Only %.0f%% of handled calls became normal sales. Compare close chance and lead source before the next shift." % conversion
	if goal > 0 and revenue < goal:
		return "$%s short of the goal. Review lead quantity, close chance, and sale value before changing the team." % _format_number(goal - revenue)
	return "Goal met. Compare each rep's results below to see which choices helped this shift."


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
