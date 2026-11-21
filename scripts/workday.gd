extends Control

enum Phase { PREPARE, PLAY, REPORT, REWARD_MANAGEMENT, TERMINATED }
enum PrepareView { STORE, FLOOR, ROSTER, HR, MARKETING }
@export_enum("End-of-day snapshot (prototype):end_of_day_snapshot")
var payroll_sampling_policy: String = "end_of_day_snapshot"

const EMPLOYEE_SCENE := preload("res://scenes/employee.tscn")
const DAY_TICKS := 48 # Twelve game hours at three real seconds per hour.
const BASE_SCORE_TARGET := 1000
const SCORE_TARGET_STEP := 250
const DEFAULT_COMMISSION_RATE := 10
const EXPERIENCE_PAY_INTERVAL := 3
const EXPERIENCE_PAY_INCREASE := 5
const AUGMENT_PAY_INCREASE := 15
const COMMISSION_FORECAST_SAMPLES := 6

@onready var prepare_tab: Button = $PageMargin/Page/Tabs/PrepareTab
@onready var play_tab: Button = $PageMargin/Page/Tabs/PlayTab
@onready var report_tab: Button = $PageMargin/Page/Tabs/ReportTab
@onready var store_view_tab: Button = $PageMargin/Page/Tabs/StoreViewTab
@onready var floor_view_tab: Button = $PageMargin/Page/Tabs/FloorViewTab
@onready var roster_view_tab: Button = $PageMargin/Page/Tabs/RosterViewTab
@onready var items_button: Button = $PageMargin/Page/Tabs/ItemsButton
@onready var people_button: Button = $PageMargin/Page/Tabs/PeopleButton
@onready var inventory_panel: InventoryPanel = $PageMargin/Page/InventoryPanel
@onready var phase_label: Label = $PageMargin/Page/Tabs/PhaseLabel
@onready var day_label: Label = $PageMargin/Page/Header/DayLabel
@onready var shift_clock: Label = $PageMargin/Page/Header/ShiftClock
@onready var main_menu_button: Button = $PageMargin/Page/Header/MainMenuButton
@onready var floor_grid: GridContainer = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorScroll/FloorGrid
@onready var revenue_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/RevenueLabel
@onready var target_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/TargetLabel
@onready var status_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/StatusLabel
@onready var pause_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PauseButton
@onready var speed_selector: OptionButton = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/SpeedSelector
@onready var primary_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PrimaryButton
@onready var report_panel: ReportPanel = $PageMargin/Page/Body/ReportPanel
@onready var slam_board: SalesSlamBoard = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/SalesSlamBoard
@onready var results_overview: VBoxContainer = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/ResultsOverview
@onready var queue_panel: CallQueuePanel = $PageMargin/Page/Body/CallQueuePanel
@onready var planning_panel: PlanningPanel = $PageMargin/Page/Body/PlanningPanel
@onready var store_panel: StorePanel = $PageMargin/Page/Body/StorePanel
@onready var floor_title: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/FloorTitle
@onready var planning_guide: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/PlanningGuide
@onready var day_timer: Timer = $DayTimer
@onready var hr_panel: HRPanel = $PageMargin/Page/Body/HRPanel
@onready var marketing_panel: MarketingPanel = $PageMargin/Page/Body/MarketingPanel
@onready var department_nav: HBoxContainer = $PageMargin/Page/DepartmentNav
@onready var hr_tab: Button = $PageMargin/Page/DepartmentNav/HRTab
@onready var marketing_tab: Button = $PageMargin/Page/DepartmentNav/MarketingTab
@onready var department_start: Button = $PageMargin/Page/DepartmentNav/StartShift

var phase := Phase.PREPARE
var prepare_view := PrepareView.STORE
var day := 1
var paused := false
var play_speed := 1.0
var _resume_speed := 1.0
var _pending_event_seconds := 0.0
var _scheduled_remaining_seconds := 0.0
var employee_cards: Array[EmployeeCard] = []
var staffed_seats: Array[int] = []
var call_queue := CallQueueSimulation.new()
var inventory := InventoryManager.new()
var floor_plan := inventory.floor_plan
var augment_manager := AugmentManager.new(inventory)
var financial_ledger := FinancialLedger.new()
var selected_seat := 1
var day_payroll_snapshot: Dictionary = {}
var first_day_complete := false
var report_snapshot: Dictionary = {}
var _restoring_run := false
var tutorial_step := 0
var first_day_planning_open := false
var lead_source := MarketingPanel.DEFAULT_SOURCE
var lead_quantity := MarketingPanel.DEFAULT_QUANTITY
var commission_rates: Dictionary = {}
var rep_experience: Dictionary = {}
var last_rep_pay: Dictionary = {}
var shift_lead_cost := 0
var hr_feedback := ""
var projected_sales: Dictionary = {}
var tutorial_panel: PanelContainer
var tutorial_title: Label
var tutorial_body: Label
var tutorial_button: Button
var _leave_confirmation: ConfirmationDialog
var _leave_was_paused := false
var _pending_fire_id := ""
var _fire_confirmation: ConfirmationDialog
var _augment_confirmation: ConfirmationDialog
var _pending_augment_action := ""
var _pending_augment_data: Dictionary = {}


func _ready() -> void:
	_build_floor()
	_build_first_day_guide()
	augment_manager.bind_financial_ledger(financial_ledger)
	augment_manager.initialize_store_for_day(day)
	financial_ledger.reset_daily_revenue(day)
	call_queue.sale_settlement_callback = Callable(self, "_settle_sale")
	call_queue.cash_effect_callback = Callable(self, "_apply_augment_cash_effect")
	call_queue.financial_context_provider = Callable(self, "_financial_context")
	call_queue.reset(floor_plan.seats)
	planning_panel.augment_equip_requested.connect(_equip_augment)
	planning_panel.augment_replace_requested.connect(_request_replace_augment)
	planning_panel.augment_discard_requested.connect(_request_discard_augment)
	planning_panel.surgery_requested.connect(_unlock_augment_slot)
	planning_panel.fire_requested.connect(_request_fire_employee)
	planning_panel.return_reward_requested.connect(_return_to_pending_reward)
	items_button.toggled.connect(func(_pressed: bool) -> void: _toggle_inventory(true))
	people_button.toggled.connect(func(_pressed: bool) -> void: _toggle_inventory(false))
	inventory_panel.drop_validator = _can_transfer
	inventory_panel.transfer_requested.connect(_on_transfer_requested)
	for card in employee_cards:
		card.drop_validator = _can_transfer
		card.dropped.connect(_on_transfer_requested)
	prepare_tab.pressed.connect(func() -> void: _show_phase(Phase.PREPARE))
	play_tab.pressed.connect(func() -> void: _show_phase(Phase.PLAY))
	report_tab.pressed.connect(func() -> void: _show_phase(Phase.REPORT))
	store_view_tab.pressed.connect(func() -> void: _select_prepare_view(PrepareView.STORE))
	floor_view_tab.pressed.connect(func() -> void: _select_prepare_view(PrepareView.FLOOR))
	roster_view_tab.pressed.connect(func() -> void: _select_prepare_view(PrepareView.ROSTER))
	hr_tab.pressed.connect(func() -> void: _select_prepare_view(PrepareView.HR))
	marketing_tab.pressed.connect(func() -> void: _select_prepare_view(PrepareView.MARKETING))
	department_start.pressed.connect(_start_day)
	hr_panel.hire_requested.connect(_hire_employee)
	hr_panel.fire_requested.connect(_request_fire_employee)
	hr_panel.commission_changed.connect(_set_commission_rate)
	marketing_panel.plan_changed.connect(_set_lead_plan)
	store_panel.augment_purchase_requested.connect(_purchase_store_augment)
	store_panel.employee_hire_requested.connect(_hire_store_employee)
	store_panel.reroll_requested.connect(_reroll_store)
	store_panel.start_workday_requested.connect(_on_primary_pressed)
	primary_button.pressed.connect(_on_primary_pressed)
	pause_button.pressed.connect(_toggle_pause)
	for speed_name in ["Paused", "Slow", "Normal", "Fast", "Super Fast"]:
		speed_selector.add_item(speed_name)
	speed_selector.select(2)
	speed_selector.item_selected.connect(_on_speed_selected)
	main_menu_button.pressed.connect(_request_main_menu)
	report_panel.next_day_requested.connect(_prepare_next_day)
	report_panel.reward_option_selected.connect(_select_reward_option)
	report_panel.reward_claim_requested.connect(_claim_reward)
	report_panel.reward_install_requested.connect(_request_reward_install)
	report_panel.reward_skip_requested.connect(_skip_reward)
	report_panel.reward_manage_requested.connect(_open_reward_management)
	_fire_confirmation = ConfirmationDialog.new()
	_fire_confirmation.title = "Confirm Permanent Termination"
	_fire_confirmation.ok_button_text = "Fire Permanently"
	_fire_confirmation.confirmed.connect(_confirm_fire_employee)
	_fire_confirmation.canceled.connect(_cancel_fire_request)
	add_child(_fire_confirmation)
	_augment_confirmation = ConfirmationDialog.new()
	_augment_confirmation.title = "Confirm Permanent Augment Change"
	_augment_confirmation.ok_button_text = "Confirm"
	_augment_confirmation.confirmed.connect(_confirm_augment_action)
	_augment_confirmation.canceled.connect(_cancel_augment_action)
	add_child(_augment_confirmation)
	_leave_confirmation = ConfirmationDialog.new()
	_leave_confirmation.title = "Leave this shift?"
	_leave_confirmation.dialog_text = "The current shift has not been saved. Resume will return to the latest completed-day checkpoint."
	_leave_confirmation.ok_button_text = "Main Menu"
	_leave_confirmation.confirmed.connect(_open_main_menu)
	_leave_confirmation.canceled.connect(_cancel_main_menu)
	add_child(_leave_confirmation)
	day_timer.timeout.connect(_on_day_timer_timeout)
	_refresh_augment_views()
	_refresh_financial_ui()
	resized.connect(_update_layout)
	_update_layout()
	_show_score_target()
	var resume_data := RunSave.pending_resume.duplicate(true)
	RunSave.pending_resume.clear()
	if not resume_data.is_empty() and _restore_run(resume_data):
		return
	_show_phase(Phase.PREPARE)


func score_target(for_day: int) -> int:
	return BASE_SCORE_TARGET + SCORE_TARGET_STEP * (for_day - 1)


func _show_score_target() -> void:
	target_label.text = "TARGET $%d  /  " % score_target(day)


func _build_floor() -> void:
	for index in FloorPlan.SEAT_COUNT:
		var card: EmployeeCard = EMPLOYEE_SCENE.instantiate()
		floor_grid.add_child(card)
		card.configure(index + 1, floor_plan.profile(floor_plan.seats[index]))
		card.seat_selected.connect(_select_seat)
		employee_cards.append(card)
	staffed_seats.assign(floor_plan.occupied_seats())


func _build_first_day_guide() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.custom_minimum_size = Vector2(310, 0)
	tutorial_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.105)
	style.border_color = Color(0.29, 0.74, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	tutorial_panel.add_theme_stylebox_override("panel", style)
	$PageMargin/Page/Body.add_child(tutorial_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	tutorial_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	tutorial_title = Label.new()
	tutorial_title.add_theme_color_override("font_color", Color(0.38, 0.89, 0.8))
	tutorial_title.add_theme_font_size_override("font_size", 19)
	column.add_child(tutorial_title)
	tutorial_body = Label.new()
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body.add_theme_font_size_override("font_size", 16)
	tutorial_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tutorial_body)
	tutorial_button = Button.new()
	tutorial_button.custom_minimum_size = Vector2(0, 46)
	tutorial_button.pressed.connect(_advance_first_day_guide)
	column.add_child(tutorial_button)
	_refresh_first_day_guide()


func _refresh_first_day_guide() -> void:
	if tutorial_panel == null:
		return
	var titles := ["01 / YOUR SALES REP", "02 / TODAY'S TARGET", "03 / THE SHIFT"]
	var explanations := [
		"Nina handles incoming calls automatically. You manage the floor; you do not assign individual calls.",
		"Reach the sales target shown above the floor. Sales also add to Company Cash, which funds future hires and augments.",
		"A shift lasts 12 in-game hours. Pause to inspect the floor, then read the report. Miss the target or payroll and you get a write-up; three end the quarter.",
	]
	tutorial_title.text = titles[tutorial_step]
	tutorial_body.text = explanations[tutorial_step]
	tutorial_button.text = "Next"
	if tutorial_step == 2:
		tutorial_button.text = "Start First Shift" if _can_start_day() else "Review Planning"


func _advance_first_day_guide() -> void:
	if not _can_start_day() and tutorial_step == 2:
		_select_prepare_view(PrepareView.MARKETING if _lead_cost() > financial_ledger.company_cash else PrepareView.HR)
		return
	if tutorial_step < 2:
		tutorial_step += 1
		_refresh_first_day_guide()
	else:
		_start_day()


func _request_main_menu() -> void:
	if phase == Phase.PLAY:
		_leave_was_paused = paused
		if not paused:
			_toggle_pause()
		_leave_confirmation.popup_centered()
	else:
		_open_main_menu()


func _cancel_main_menu() -> void:
	if phase == Phase.PLAY and not _leave_was_paused and paused:
		_toggle_pause()


func _open_main_menu() -> void:
	if phase != Phase.PLAY:
		_save_checkpoint()
	RunSave.session_active = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _select_seat(seat: int) -> void:
	if not _is_management_phase() or (not first_day_complete and not first_day_planning_open) \
			or seat < 0 or seat >= FloorPlan.SEAT_COUNT:
		return
	selected_seat = seat
	planning_panel.show_plan(floor_plan, selected_seat, true)
	planning_panel.views.current_tab = 0
	_refresh_floor()
	# Keep keyboard-selected seats visible at small window sizes.
	floor_grid.get_parent().ensure_control_visible(employee_cards[seat])


func _hire_employee(employee_id: String) -> void:
	if not _is_management_phase():
		return
	if inventory.fired_employee_ids.has(employee_id):
		_show_hr_feedback("%s has left and cannot be rehired this run." % floor_plan.profile(employee_id).get("name", employee_id))
		return
	if not augment_manager.hire(employee_id):
		_show_hr_feedback("Hiring needs $%d and a free reserve slot." % AugmentManager.HIRE_COST)
		return
	_show_hr_feedback("%s hired into reserve. Seat them on the Sales Floor." % floor_plan.profile(employee_id)["name"])
	if day == 1 and not first_day_complete:
		first_day_planning_open = true
	_sync_floor_plan()
	_refresh_augment_views()


func _request_fire_employee(employee_id: String) -> void:
	if not _is_management_phase() or financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE:
		return
	if not inventory.owns(employee_id) or inventory.fired_employee_ids.has(employee_id):
		return
	var employee_name: String = floor_plan.profile(employee_id).get("name", employee_id)
	_fire_confirmation.dialog_text = (
		"Fire %s permanently?\n\nThe employee cannot be rehired this run. They and all installed augments will be permanently lost. Uninstalled inventory items, cash, and upkeep debt will not be refunded or changed."
		% employee_name
	)
	_pending_fire_id = employee_id
	_fire_confirmation.popup_centered()


func _confirm_fire_employee() -> void:
	if not _is_management_phase() or _pending_fire_id.is_empty():
		return
	var employee_id := _pending_fire_id
	_pending_fire_id = ""
	var employee_name: String = floor_plan.profile(employee_id).get("name", employee_id)
	var fired := inventory.fire_employee(employee_id)
	if fired.is_empty():
		return
	_clear_departed_rep(employee_id)
	_show_hr_feedback("%s fired permanently. Installed augments were lost." % employee_name)
	_sync_floor_plan()
	_refresh_augment_views()


func _clear_departed_rep(employee_id: String) -> void:
	augment_manager.second_slot_unlocked.erase(employee_id)
	commission_rates.erase(employee_id)
	rep_experience.erase(employee_id)
	last_rep_pay.erase(employee_id)


func _show_hr_feedback(message: String) -> void:
	hr_feedback = message
	status_label.text = message
	hr_panel.feedback_label.text = message


func _set_commission_rate(employee_id: String, rate: float) -> void:
	if phase != Phase.PREPARE or not inventory.owns(employee_id):
		return
	commission_rates[employee_id] = clampi(roundi(rate), 0, 100)
	_show_hr_feedback("Commission updated for the upcoming shift.")
	hr_panel.update_commission_estimate(employee_id, _estimated_commission(employee_id))
	_save_checkpoint()


func _commission_rate(employee_id: String) -> int:
	return clampi(int(commission_rates.get(employee_id, DEFAULT_COMMISSION_RATE)), 0, 100)


func _commission(employee_id: String, sales: int) -> int:
	return roundi(sales * _commission_rate(employee_id) / 100.0)


func _estimated_commission(employee_id: String) -> int:
	return roundi(float(projected_sales.get(employee_id, 0))
		* _commission_rate(employee_id) / (100.0 * COMMISSION_FORECAST_SAMPLES))


func _earnings_expectation(employee_id: String) -> int:
	var experience := int(rep_experience.get(employee_id, 0))
	var profile := floor_plan.profile(employee_id)
	var starting_pay := int(profile.get("earnings_expectation", augment_manager.daily_upkeep(employee_id)))
	return starting_pay + floori(float(experience) / EXPERIENCE_PAY_INTERVAL) * EXPERIENCE_PAY_INCREASE \
		+ augment_manager.loadout(employee_id).size() * AUGMENT_PAY_INCREASE


func _lead_cost() -> int:
	return MarketingPanel.campaign_cost(lead_source, lead_quantity)


func _lead_campaign() -> Dictionary:
	return MarketingPanel.campaign_plan(
		lead_source, lead_quantity, DAY_TICKS * CallQueueSimulation.TICK_SECONDS
	)


func _set_lead_plan(source_id: String, quantity: int) -> void:
	if phase != Phase.PREPARE or MarketingPanel.source_data(source_id)["id"] != source_id:
		return
	lead_source = source_id
	lead_quantity = clampi(quantity, 0, MarketingPanel.MAX_QUANTITY)
	_refresh_departments()
	_refresh_floor()
	_save_checkpoint()


func _can_start_day() -> bool:
	return phase == Phase.PREPARE and not floor_plan.occupied_seats().is_empty() \
		and financial_ledger.writeups < FinancialLedger.WRITEUPS_TO_TERMINATE \
		and augment_manager.pending_reward.is_empty() and _lead_cost() <= financial_ledger.company_cash


func _forecast_sales() -> Dictionary:
	var sales_totals := {}
	var projection := CallQueueSimulation.new()
	var equipment := augment_manager.equipment_instances
	var campaign := _lead_campaign()
	for seed_index in COMMISSION_FORECAST_SAMPLES:
		projection.reset(floor_plan.seats, 100 + seed_index, equipment, campaign)
		projection.advance(DAY_TICKS * CallQueueSimulation.TICK_SECONDS)
		for rep in projection.employee_results():
			var id: String = rep["employee_id"]
			sales_totals[id] = int(sales_totals.get(id, 0)) + int(rep["revenue"])
	return sales_totals


func _refresh_departments() -> void:
	if phase != Phase.PREPARE:
		return
	department_start.disabled = not _can_start_day()
	department_start.text = "Start First Shift" if not first_day_complete else "Start Workday"
	if marketing_panel.visible:
		marketing_panel.show_plan(lead_source, lead_quantity, financial_ledger.company_cash, true)
	if not hr_panel.visible:
		return
	projected_sales = _forecast_sales()
	var salaries := _payroll_snapshot()
	var rows: Array[Dictionary] = []
	for profile in floor_plan.roster:
		var id: String = profile["id"]
		var owned := inventory.owns(id)
		var last_pay: Dictionary = last_rep_pay.get(id, {})
		var row := {
			"id": id, "name": profile["name"], "archetype": profile["archetype"],
			"owned": owned, "unavailable": inventory.fired_employee_ids.has(id),
			"seated": floor_plan.seats.has(id), "can_hire": inventory.can_hire(id)
				and financial_ledger.company_cash >= AugmentManager.HIRE_COST,
			"base_salary": int(salaries["by_rep"].get(id, augment_manager.daily_upkeep(id))),
			"commission_rate": _commission_rate(id),
			"estimated_commission": _estimated_commission(id),
			"earnings_expectation": _earnings_expectation(id),
			"experience": int(rep_experience.get(id, 0)), "hiring_cost": AugmentManager.HIRE_COST,
		}
		if not last_pay.is_empty():
			row["last_earnings"] = last_pay["paid"]
			row["last_expectation"] = last_pay["expectation"]
		rows.append(row)
	hr_panel.show_state(rows, financial_ledger.company_cash, true, hr_feedback)


func _cancel_fire_request() -> void:
	_pending_fire_id = ""


func _toggle_inventory(items: bool) -> void:
	if not first_day_complete and not first_day_planning_open:
		return
	if items:
		inventory_panel.toggle_items()
	else:
		inventory_panel.toggle_people()
	items_button.set_pressed_no_signal(inventory_panel.items_open())
	people_button.set_pressed_no_signal(inventory_panel.people_open())
	_refresh_augment_views()


func _refresh_augment_views() -> void:
	planning_panel.update_augment_state(augment_manager, _is_management_phase())
	planning_panel.set_pending_reward_management(not augment_manager.pending_reward.is_empty())
	inventory_panel.show_state(augment_manager, _is_management_phase())
	_refresh_store_panel()
	_refresh_financial_ui()
	_refresh_departments()
	if first_day_complete and not _restoring_run and phase != Phase.PLAY:
		_save_checkpoint()


func _refresh_store_panel() -> void:
	store_panel.show_state(
		augment_manager, day, phase == Phase.PREPARE,
		_can_start_day()
	)


func _payroll_snapshot() -> Dictionary:
	var active := 0
	var bench := 0
	var by_rep := {}
	var effective_stats: Dictionary = augment_manager.modified_floor_stats()
	for employee_id in floor_plan.seats:
		if not employee_id.is_empty():
			var salary := roundi(float(effective_stats.get(employee_id, {}).get("daily_upkeep", 0.0)))
			by_rep[employee_id] = salary
			active += salary
	for employee_id in inventory.person_slots:
		if not employee_id.is_empty():
			var salary := roundi(float(effective_stats.get(employee_id, {}).get("daily_upkeep", 0.0)))
			by_rep[employee_id] = salary
			bench += salary
	return {"active": active, "bench": bench, "total": active + bench, "by_rep": by_rep}


func _financial_context() -> Dictionary:
	return {"company_cash": augment_manager.budget}


func _settle_sale(sale: Dictionary) -> void:
	financial_ledger.settle_sale(
		str(sale.get("employee_id", "")), int(sale.get("value", 0)),
		float(sale.get("timestamp", 0.0)), "", int(sale.get("event_id", 0))
	)


func _apply_augment_cash_effect(
		action: String,
		requested_amount: int,
		employee_id: String,
		augment_id: String,
		timestamp: float,
		event_id: int
	) -> int:
	var result := financial_ledger.apply_augment_cash_effect(
		action, requested_amount, employee_id, augment_id, timestamp, event_id
	)
	return int(result.get("applied_amount", 0))


func _refresh_financial_ui() -> void:
	if not is_node_ready():
		return
	revenue_label.text = "SALES $%d · CASH $%d" % [
		call_queue.revenue, augment_manager.budget,
	]
	var projected := _payroll_snapshot()
	planning_panel.show_financial_state(
		augment_manager.budget, financial_ledger.daily_sales_revenue, financial_ledger.upkeep_debt,
		int(projected["active"]), int(projected["bench"])
	)


## Pure check shared by drag previews and the real transfer, so feedback matches outcomes.
func _can_transfer(data: Dictionary, target_kind: String, target_index: int) -> bool:
	if not first_day_complete and not first_day_planning_open:
		return false
	if not _is_management_phase():
		return false
	match data.get("type", ""):
		"item":
			var slot := int(data.get("slot", -1))
			if slot < 0 or slot >= InventoryManager.ITEM_SLOTS or inventory.item_slots[slot].is_empty():
				return false
			if target_kind == "item":
				return target_index != slot and target_index >= 0 and target_index < InventoryManager.ITEM_SLOTS
			var employee_id := inventory.person_at(target_kind, target_index)
			return not employee_id.is_empty() and inventory.equipped_instances(employee_id).size() < augment_manager.slot_limit(employee_id)
		"person":
			var source_kind: String = data.get("kind", "")
			var source_index := int(data.get("index", -1))
			if inventory.person_at(source_kind, source_index).is_empty():
				return false
			return _valid_person_target(target_kind, target_index) \
				and not (source_kind == target_kind and source_index == target_index)
	return false


func _valid_person_target(kind: String, index: int) -> bool:
	if kind == InventoryManager.BOARD:
		return index >= 0 and index < FloorPlan.SEAT_COUNT
	return kind == InventoryManager.RESERVE and index >= 0 and index < InventoryManager.PERSON_SLOTS


func _on_transfer_requested(data: Dictionary, target_kind: String, target_index: int) -> void:
	if not _is_management_phase() or not _can_transfer(data, target_kind, target_index):
		status_label.text = "That move is not allowed."
		return
	if data["type"] == "item":
		if target_kind == "item":
			inventory.move_item(int(data["slot"]), target_index)
			status_label.text = "Item moved."
		else:
			var employee_id := inventory.person_at(target_kind, target_index)
			if not augment_manager.equip_slot(employee_id, int(data["slot"])):
				status_label.text = "No augment slot is available for that employee."
				return
			status_label.text = "Augment equipped on %s." % floor_plan.profile(employee_id).get("name", employee_id)
	else:
		inventory.move_person(data["kind"], int(data["index"]), target_kind, target_index)
		if target_kind == InventoryManager.BOARD:
			selected_seat = target_index
			planning_panel.show_plan(floor_plan, selected_seat, true)
		status_label.text = "Salesperson moved."
	_sync_floor_plan()
	_refresh_augment_views()


func _purchase_store_augment(slot_index: int) -> void:
	if phase != Phase.PREPARE:
		return
	var offer := augment_manager.store_offer(slot_index)
	var augment := AugmentManager.CATALOG.profile(str(offer.get("augment_id", "")))
	if augment_manager.purchase_store_augment(slot_index):
		store_panel.set_feedback("%s added to item inventory." % augment.get("name", "Augment"))
		_refresh_augment_views()
		return
	var reason := "Check company cash, item inventory capacity, and offer availability."
	if augment_manager.budget < int(augment.get("price", 0)):
		reason = "Insufficient company cash for that augment."
	elif augment_manager.bag.is_item_full():
		reason = "Item inventory is full. Free a slot before purchasing."
	store_panel.set_feedback(reason, true)


func _hire_store_employee(slot_index: int) -> void:
	if phase != Phase.PREPARE:
		return
	var offer := augment_manager.store_offer(slot_index)
	var employee := augment_manager.employee_profile(str(offer.get("employee_id", "")))
	if augment_manager.hire_store_employee(slot_index):
		store_panel.set_feedback("%s hired into salesperson reserve." % employee.get("name", "Salesperson"))
		_sync_floor_plan()
		_refresh_augment_views()
		return
	var reason := "That unique candidate is no longer available."
	if augment_manager.budget < AugmentManager.HIRE_COST:
		reason = "Insufficient company cash to hire."
	elif inventory.is_reserve_full():
		reason = "Salesperson reserve is full. Clear a slot before hiring."
	store_panel.set_feedback(reason, true)


func _reroll_store() -> void:
	if phase != Phase.PREPARE:
		return
	if not augment_manager.reroll_store():
		store_panel.set_feedback(
			"Reroll requires $%d company cash." % AugmentManager.CATALOG.store_reroll_cost, true
		)
		return
	store_panel.set_feedback("All seven store slots rerolled for $%d." % AugmentManager.CATALOG.store_reroll_cost)
	_refresh_augment_views()


func _equip_augment(employee_id: String, inventory_index: int) -> void:
	if not _is_management_phase():
		return
	if not augment_manager.equip_slot(employee_id, inventory_index):
		status_label.text = "No augment slot is available for that employee."
		return
	status_label.text = "Augment equipped on %s." % floor_plan.profile(employee_id).get("name", employee_id)
	_refresh_augment_views()
	_refresh_card_stats()


func _request_replace_augment(employee_id: String, slot_index: int, item_slot: int) -> void:
	if not _is_management_phase() or not inventory.owns(employee_id) \
		or slot_index < 0 or slot_index >= inventory.equipped_instances(employee_id).size() \
		or item_slot < 0 or item_slot >= InventoryManager.ITEM_SLOTS or inventory.item_slots[item_slot].is_empty():
		return
	var old_item: Dictionary = inventory.equipped_instances(employee_id)[slot_index]
	var new_item: Dictionary = inventory.item_slots[item_slot]
	var old_name: String = AugmentManager.CATALOG.profile(old_item["augment_id"]).get("name", old_item["augment_id"])
	var new_name: String = AugmentManager.CATALOG.profile(new_item["augment_id"]).get("name", new_item["augment_id"])
	_pending_augment_action = "replace_inventory"
	_pending_augment_data = {"employee_id": employee_id, "slot_index": slot_index, "item_slot": item_slot}
	_augment_confirmation.dialog_text = "Permanently install %s on %s?\n\n%s will be destroyed and cannot be recovered. There is no extra fee." % [
		new_name, floor_plan.profile(employee_id).get("name", employee_id), old_name,
	]
	_augment_confirmation.popup_centered()


func _request_discard_augment(item_slot: int) -> void:
	if not _is_management_phase() or item_slot < 0 or item_slot >= InventoryManager.ITEM_SLOTS \
		or inventory.item_slots[item_slot].is_empty():
		return
	var item: Dictionary = inventory.item_slots[item_slot]
	var augment_name: String = AugmentManager.CATALOG.profile(item["augment_id"]).get("name", item["augment_id"])
	_pending_augment_action = "discard_inventory"
	_pending_augment_data = {"item_slot": item_slot}
	_augment_confirmation.dialog_text = "Discard %s permanently?\n\nThis frees one shared inventory slot. The item cannot be recovered." % augment_name
	_augment_confirmation.popup_centered()


func _confirm_augment_action() -> void:
	var action := _pending_augment_action
	var data := _pending_augment_data.duplicate(true)
	_cancel_augment_action()
	match action:
		"replace_inventory":
			if not _is_management_phase() or not augment_manager.replace_slot_from_inventory(
					str(data["employee_id"]), int(data["slot_index"]), int(data["item_slot"])):
				status_label.text = "The replacement could not be completed; no items were changed."
				return
			status_label.text = "The old augment was destroyed and the new augment is permanently installed."
			_refresh_augment_views()
			_refresh_card_stats()
		"discard_inventory":
			if not _is_management_phase() or not augment_manager.discard_item(int(data["item_slot"])):
				status_label.text = "The item could not be discarded."
				return
			status_label.text = "Item discarded. The pending reward remains unchanged."
			_refresh_augment_views()
		"install_reward":
			if not _is_report_phase() or not augment_manager.install_reward(
					int(data["reward_index"]), str(data["employee_id"]), int(data["slot_index"])):
				status_label.text = "The reward installation failed; the reward remains available."
				return
			report_panel.show_reward_resolved()
			status_label.text = "Reward installed. The previous augment, if any, was destroyed."
			_refresh_augment_views()
			_refresh_card_stats()
		_:
			push_error("Unknown augment confirmation action: " + action)


func _cancel_augment_action() -> void:
	_pending_augment_action = ""
	_pending_augment_data.clear()


func _select_reward_option(index: int) -> void:
	if not _is_report_phase() or not augment_manager.select_reward_option(index):
		return
	_refresh_reward_ui()
	_save_checkpoint()


func _claim_reward(index: int) -> void:
	if not _is_report_phase():
		return
	if not augment_manager.claim_reward_to_inventory(index):
		status_label.text = "Cannot claim this reward: inventory is full or the offer is invalid."
		return
	report_panel.show_reward_resolved()
	status_label.text = "Augment claimed to inventory. All other reward choices were forfeited."
	_refresh_augment_views()
	_save_checkpoint()


func _request_reward_install(index: int, employee_id: String, slot_index: int) -> void:
	if not _is_report_phase() or not inventory.owns(employee_id):
		return
	if not augment_manager.select_reward_option(index):
		return
	var loadout := inventory.equipped_instances(employee_id)
	if slot_index < loadout.size():
		var old_id: String = loadout[slot_index]["augment_id"]
		var new_id: String = augment_manager.pending_reward["choices"][index]
		var old_name: String = AugmentManager.CATALOG.profile(old_id).get("name", old_id)
		var new_name: String = AugmentManager.CATALOG.profile(new_id).get("name", new_id)
		_pending_augment_action = "install_reward"
		_pending_augment_data = {
			"reward_index": index,
			"employee_id": employee_id,
			"slot_index": slot_index,
		}
		_augment_confirmation.dialog_text = "Install %s on %s?\n\nThis permanently destroys %s. There is no extra fee." % [
			new_name, floor_plan.profile(employee_id).get("name", employee_id), old_name,
		]
		_augment_confirmation.popup_centered()
		return
	if not augment_manager.install_reward(index, employee_id, slot_index):
		status_label.text = "The reward cannot be installed in that slot."
		return
	report_panel.show_reward_resolved()
	status_label.text = "Reward installed directly; it never used an inventory slot."
	_refresh_augment_views()
	_refresh_card_stats()
	_save_checkpoint()


func _skip_reward() -> void:
	if not _is_report_phase() or not augment_manager.skip_daily_reward():
		return
	report_panel.show_reward_resolved()
	status_label.text = "Daily reward skipped. All three choices were forfeited."
	_refresh_augment_views()
	_save_checkpoint()


func _open_reward_management() -> void:
	if not _is_report_phase() or augment_manager.pending_reward.is_empty():
		return
	_show_phase(Phase.REWARD_MANAGEMENT)


func _return_to_pending_reward() -> void:
	if phase == Phase.REWARD_MANAGEMENT and not augment_manager.pending_reward.is_empty():
		_show_phase(Phase.REPORT)


func _refresh_reward_ui() -> void:
	var employee_options: Array[Dictionary] = []
	var employee_ids: Array[String] = []
	for employee_id in floor_plan.seats + inventory.person_slots:
		if employee_id.is_empty() or employee_ids.has(employee_id):
			continue
		employee_ids.append(employee_id)
		employee_options.append({
			"id": employee_id,
			"name": floor_plan.profile(employee_id).get("name", employee_id),
			"equipment": inventory.equipped_instances(employee_id).duplicate(true),
			"slot_limit": augment_manager.slot_limit(employee_id),
		})
	report_panel.show_reward(augment_manager.pending_reward, employee_options, inventory.is_item_full())


func _is_management_phase() -> bool:
	return phase in [Phase.PREPARE, Phase.REWARD_MANAGEMENT]


func _is_report_phase() -> bool:
	return phase in [Phase.REPORT, Phase.TERMINATED]


func _unlock_augment_slot(employee_id: String) -> void:
	if not _is_management_phase() or not inventory.owns(employee_id) or inventory.fired_employee_ids.has(employee_id):
		return
	if not augment_manager.unlock_second_slot(employee_id):
		status_label.text = "Second-slot surgery requires $300 and can only be performed once per employee."
		return
	status_label.text = "Second augment slot unlocked for %s." % floor_plan.profile(employee_id).get("name", employee_id)
	_refresh_augment_views()


func _sync_floor_plan() -> void:
	staffed_seats.assign(floor_plan.occupied_seats())
	_refresh_card_stats()
	planning_panel.show_plan(floor_plan, selected_seat)
	_refresh_floor()
	_refresh_financial_ui()
	_save_checkpoint()


func _refresh_card_stats() -> void:
	var live_stats: Dictionary = {}
	if phase in [Phase.PLAY, Phase.REPORT, Phase.TERMINATED]:
		live_stats = call_queue.effective_stats_snapshot()
	for seat in employee_cards.size():
		var employee_id := floor_plan.seats[seat]
		var stats: Dictionary = live_stats.get(employee_id, {}) if not live_stats.is_empty() else augment_manager.modified_stats(employee_id)
		employee_cards[seat].configure(
			seat + 1, floor_plan.profile(employee_id), augment_manager.loadout(employee_id), stats
		)


func _update_layout() -> void:
	if not is_node_ready():
		return
	var compact := size.y < 650
	roster_view_tab.text = "ROSTER" if compact else "ROSTER / INVENTORY"
	people_button.text = "RESERVE" if compact else "SALESPEOPLE"
	inventory_panel.set_compact(compact)
	for edge in ["left", "right"]:
		$PageMargin.add_theme_constant_override("margin_" + edge, 16 if compact else 32)
	for edge in ["top", "bottom"]:
		$PageMargin.add_theme_constant_override("margin_" + edge, 14 if compact else 24)
	$PageMargin/Page.add_theme_constant_override("separation", 12 if compact else 18)
	$PageMargin/Page/Header/Brand/Title.add_theme_font_size_override("font_size", 26 if compact else 30)
	$PageMargin/Page/Body.add_theme_constant_override("separation", 12 if compact else 18)
	var margin := $PageMargin/Page/Body/FloorPanel/FloorMargin
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10 if compact else 16)
	$PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent.add_theme_constant_override("separation", 6 if compact else 12)
	floor_grid.add_theme_constant_override("h_separation", 8 if compact else 10)
	floor_grid.add_theme_constant_override("v_separation", 8 if compact else 10)
	for card in employee_cards:
		card.set_compact(compact)


func _select_prepare_view(view: PrepareView) -> void:
	if phase != Phase.PREPARE:
		return
	if day == 1 and not first_day_complete and view == PrepareView.STORE:
		return
	if day == 1 and not first_day_complete and view == PrepareView.FLOOR:
		first_day_planning_open = true
	prepare_view = view
	_show_phase(Phase.PREPARE, false)


func _show_phase(next_phase: Phase, reset_prepare_view := true) -> void:
	if financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE and next_phase != Phase.TERMINATED:
		return
	if next_phase == Phase.PREPARE and reset_prepare_view:
		prepare_view = PrepareView.FLOOR if day == 1 and not first_day_complete else PrepareView.STORE
	phase = next_phase
	var report_visible := phase in [Phase.REPORT, Phase.TERMINATED]
	var management_visible := _is_management_phase()
	var store_visible := phase == Phase.PREPARE and prepare_view == PrepareView.STORE
	var roster_visible := phase == Phase.PREPARE and prepare_view == PrepareView.ROSTER
	var hr_visible := phase == Phase.PREPARE and prepare_view == PrepareView.HR
	var marketing_visible := phase == Phase.PREPARE and prepare_view == PrepareView.MARKETING
	var department_visible := hr_visible or marketing_visible
	var floor_visible := not store_visible and not roster_visible and not department_visible
	hr_panel.visible = hr_visible
	marketing_panel.visible = marketing_visible
	department_nav.visible = phase == Phase.PREPARE
	hr_tab.set_pressed_no_signal(hr_visible)
	marketing_tab.set_pressed_no_signal(marketing_visible)
	department_start.visible = department_visible or roster_visible
	report_panel.visible = report_visible
	queue_panel.visible = phase == Phase.PLAY
	store_panel.visible = store_visible
	$PageMargin/Page/Body.visible = not roster_visible
	$PageMargin/Page/Body/FloorPanel.visible = floor_visible
	planning_panel.visible = management_visible and (first_day_complete or first_day_planning_open) and (
		phase != Phase.PREPARE or prepare_view == PrepareView.FLOOR
	)
	planning_guide.visible = planning_panel.visible
	tutorial_panel.visible = phase == Phase.PREPARE and day == 1 and not first_day_complete \
		and floor_visible and not first_day_planning_open
	_refresh_first_day_guide()
	floor_grid.get_parent().visible = not report_visible
	slam_board.visible = report_visible
	results_overview.visible = report_visible
	revenue_label.visible = phase != Phase.PREPARE
	store_view_tab.visible = phase == Phase.PREPARE and (day > 1 or first_day_complete)
	floor_view_tab.visible = phase == Phase.PREPARE
	roster_view_tab.visible = phase == Phase.PREPARE and (day > 1 or first_day_complete)
	store_view_tab.set_pressed_no_signal(store_visible)
	floor_view_tab.set_pressed_no_signal(phase == Phase.PREPARE and prepare_view == PrepareView.FLOOR)
	roster_view_tab.set_pressed_no_signal(roster_visible)
	items_button.visible = floor_visible and not tutorial_panel.visible
	people_button.visible = floor_visible and not tutorial_panel.visible
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL if roster_visible else Control.SIZE_FILL
	if store_visible or department_visible:
		inventory_panel.hide_all()
		items_button.set_pressed_no_signal(false)
		people_button.set_pressed_no_signal(false)
	elif roster_visible:
		inventory_panel.show_all()
	elif planning_panel.visible:
		inventory_panel.show_people()
		people_button.set_pressed_no_signal(true)
	elif phase != Phase.PREPARE:
		inventory_panel.hide_all()
		items_button.set_pressed_no_signal(false)
		people_button.set_pressed_no_signal(false)
	_refresh_augment_views()
	if report_visible and not augment_manager.pending_reward.is_empty():
		_refresh_reward_ui()
	prepare_tab.disabled = phase != Phase.PREPARE or financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE
	play_tab.disabled = phase != Phase.PLAY
	report_tab.disabled = not report_visible
	pause_button.disabled = phase != Phase.PLAY
	pause_button.visible = phase == Phase.PLAY
	speed_selector.disabled = phase != Phase.PLAY
	speed_selector.visible = phase == Phase.PLAY
	primary_button.visible = phase in [Phase.PREPARE, Phase.PLAY] and floor_visible and not tutorial_panel.visible
	match phase:
		Phase.PREPARE:
			phase_label.text = "CHROME MARKET" if store_visible \
				else "ROSTER / INVENTORY" if roster_visible \
				else "HUMAN RESOURCES" if hr_visible else "MARKETING" if marketing_visible \
				else "PREPARATION OPEN"
			status_label.text = "Nina is ready. Start your first 12-hour shift." if day == 1 and not first_day_complete else "Arrange your team before opening the floor."
			primary_button.text = "Start First Shift" if day == 1 and not first_day_complete else "Start Workday"
			floor_title.text = "FLOOR PLAN"
			if prepare_view == PrepareView.FLOOR:
				if planning_panel.visible:
					planning_panel.show_plan(floor_plan, selected_seat, true)
		Phase.REWARD_MANAGEMENT:
			phase_label.text = "TEAM MANAGEMENT · REWARD PENDING"
			status_label.text = "Manage augments or inventory, then return to the same reward offer."
			floor_title.text = "TEAM MANAGEMENT"
			planning_panel.show_plan(floor_plan, selected_seat, true)
		Phase.PLAY:
			phase_label.text = "FLOOR LIVE"
			status_label.text = "The floor is operating autonomously."
			primary_button.text = "End Workday"
			floor_title.text = "SALES FLOOR"
		Phase.REPORT:
			phase_label.text = "REPORT READY"
			status_label.text = "Review the results before preparing the next day."
			floor_title.text = "DAY CLOSED"
		Phase.TERMINATED:
			phase_label.text = "CONTRACT TERMINATED"
			status_label.text = "Three write-ups were issued. No further workdays can begin."
			floor_title.text = "RUN TERMINATED"
	_refresh_floor()


func _on_primary_pressed() -> void:
	if phase == Phase.PREPARE:
		_start_day()
	elif phase == Phase.PLAY:
		_finish_day()


func _start_day() -> void:
	if not _can_start_day():
		return
	financial_ledger.begin_workday()
	shift_lead_cost = _lead_cost()
	if shift_lead_cost > 0 and not financial_ledger.spend_cash(shift_lead_cost, "lead_acquisition", lead_source):
		return
	day_payroll_snapshot.clear()
	call_queue.reset(floor_plan.seats, -1, augment_manager.equipment_instances, _lead_campaign())
	paused = false
	play_speed = 1.0
	_resume_speed = 1.0
	day_timer.paused = false
	pause_button.text = "Pause"
	speed_selector.select(2)
	_show_phase(Phase.PLAY)
	_schedule_next_event()


func _toggle_pause() -> void:
	if phase != Phase.PLAY:
		return
	_set_play_speed(_resume_speed if paused else 0.0)


func _on_speed_selected(index: int) -> void:
	var speeds := [0.0, 0.5, 1.0, 2.0, 4.0]
	if index >= 0 and index < speeds.size():
		_set_play_speed(speeds[index])


func _set_play_speed(speed: float) -> void:
	if phase != Phase.PLAY:
		return
	if not day_timer.is_stopped() and play_speed > 0.0:
		_scheduled_remaining_seconds = maxf(CallQueueSimulation.TIME_EPSILON,
			_scheduled_remaining_seconds - (day_timer.wait_time - day_timer.time_left) * play_speed)
	if speed > 0.0:
		_resume_speed = speed
	play_speed = speed
	paused = is_zero_approx(speed)
	day_timer.stop()
	day_timer.paused = paused
	if not paused and _scheduled_remaining_seconds > 0.0:
		day_timer.start(_scheduled_remaining_seconds / speed)
	pause_button.text = "Resume" if paused else "Pause"
	var speeds := [0.0, 0.5, 1.0, 2.0, 4.0]
	speed_selector.select(speeds.find(speed))
	phase_label.text = "FLOOR PAUSED" if paused else "FLOOR LIVE"
	status_label.text = "Inspect the floor and its bottlenecks." if paused else "The floor is operating autonomously."
	_refresh_floor()


func _schedule_next_event() -> void:
	var day_remaining := DAY_TICKS * CallQueueSimulation.TICK_SECONDS - call_queue.elapsed_seconds
	_pending_event_seconds = maxf(CallQueueSimulation.TIME_EPSILON, minf(day_remaining, call_queue.time_until_next_event()))
	_scheduled_remaining_seconds = _pending_event_seconds
	day_timer.start(_pending_event_seconds / play_speed)


func _on_day_timer_timeout() -> void:
	_simulate_tick(_pending_event_seconds)
	if phase == Phase.PLAY and not paused:
		_schedule_next_event()


func _simulate_tick(seconds: float = CallQueueSimulation.TICK_SECONDS) -> void:
	if phase != Phase.PLAY or paused:
		return
	var day_remaining := DAY_TICKS * CallQueueSimulation.TICK_SECONDS - call_queue.elapsed_seconds
	call_queue.advance(minf(seconds, day_remaining))
	_refresh_floor()
	status_label.text = "%d waiting · %d on call · %d finished now" % [
		call_queue.waiting.size(), call_queue.active.size(), call_queue.completed_this_tick.size()
	]
	if call_queue.elapsed_ticks >= DAY_TICKS:
		_finish_day()


func _finish_day() -> void:
	if phase != Phase.PLAY:
		return
	day_timer.stop()
	day_timer.paused = false
	paused = false
	pause_button.text = "Pause"
	match payroll_sampling_policy:
		"end_of_day_snapshot":
			day_payroll_snapshot = _payroll_snapshot()
		_:
			push_error("Unsupported payroll sampling policy: " + payroll_sampling_policy)
			day_payroll_snapshot = _payroll_snapshot()
	var workload := call_queue.employee_results()
	var pay_by_rep := _shift_pay()
	var commission_total := 0
	for employee_id in pay_by_rep:
		commission_total += int(pay_by_rep[employee_id]["commission"])
	var daily_upkeep := int(day_payroll_snapshot["total"])
	var settlement_id := financial_ledger.next_settlement_id()
	assert(financial_ledger.daily_sales_revenue == call_queue.revenue,
		"Immediate sale settlements must match the workday sales tally.")
	var finance_result := financial_ledger.settle(
		settlement_id, augment_manager.budget, call_queue.revenue, daily_upkeep + commission_total,
		call_queue.revenue >= score_target(day),
		int(day_payroll_snapshot["active"]), int(day_payroll_snapshot["bench"]), day,
		call_queue.elapsed_seconds, shift_lead_cost, commission_total
	)
	augment_manager.budget = int(finance_result["ending_cash"])
	var stats_at_close := augment_manager.modified_floor_stats()
	var active_stats := call_queue.effective_stats_snapshot()
	stats_at_close.merge(active_stats, true)
	for employee in workload:
		var id: String = employee["employee_id"]
		var profile := floor_plan.profile(id)
		employee["name"] = profile.get("name", id)
		employee["archetype"] = profile.get("archetype", "")
		employee["shift_stats"] = stats_at_close.get(id, {})
	for employee_id in inventory.person_slots:
		if employee_id.is_empty():
			continue
		var profile := floor_plan.profile(employee_id)
		workload.append({
			"employee_id": employee_id, "name": profile.get("name", employee_id),
			"archetype": profile.get("archetype", ""), "seat": -1,
			"shift_stats": stats_at_close.get(employee_id, {}),
		})
	var departures := _settle_rep_pay(pay_by_rep, finance_result)
	finance_result["lead_source_name"] = MarketingPanel.source_data(lead_source)["name"]
	finance_result["leads_purchased"] = lead_quantity
	finance_result["rep_pay"] = pay_by_rep
	finance_result["departures"] = departures
	report_snapshot = {
		"day": day, "revenue": call_queue.revenue, "handled": call_queue.handled,
		"normal_sales": call_queue.normal_sales, "sales": call_queue.sales,
		"failed": call_queue.failed_interactions, "discarded": call_queue.discarded_today,
		"recovery_attempts": call_queue.recovery_attempts, "recovered": call_queue.recovered,
		"failed_recoveries": call_queue.failed_recoveries,
		"recovered_revenue": call_queue.recovered_revenue,
		"received": call_queue.received, "waiting": call_queue.waiting.size(),
		"unfinished": call_queue.active.size(), "abandoned": call_queue.abandoned,
		"elapsed_seconds": call_queue.elapsed_seconds,
		"workload": workload.duplicate(true), "finance": finance_result.duplicate(true),
		"sale_log": call_queue.sale_log.duplicate(true),
	}
	report_panel.show_results(
		day, call_queue.revenue, call_queue.handled, call_queue.normal_sales, call_queue.sales,
		call_queue.failed_interactions, call_queue.discarded_today,
		call_queue.recovery_attempts, call_queue.recovered, call_queue.failed_recoveries,
		call_queue.recovered_revenue,
		call_queue.received, call_queue.waiting.size(), call_queue.active.size(),
		call_queue.abandoned, workload, pay_by_rep
	)
	report_panel.show_financial_results(finance_result)
	_update_results_overview(report_snapshot)
	call_queue.clear_discard_pile()
	augment_manager.generate_daily_reward()
	first_day_complete = true
	_refresh_reward_ui()
	_show_phase(Phase.TERMINATED if finance_result["terminated"] else Phase.REPORT)
	_save_checkpoint()
	# The slam only replays recorded sales; the budget above is already final and is never touched again.
	var recorded := call_queue.sale_log.duplicate(true)
	assert(slam_board.plan.total(recorded) == call_queue.revenue, "Recorded sales must add up to the day's revenue.")
	slam_board.play(recorded, score_target(day))


func _shift_pay() -> Dictionary:
	var sales_by_rep := {}
	for sale in call_queue.sale_log:
		var employee_id: String = sale["employee_id"]
		sales_by_rep[employee_id] = int(sales_by_rep.get(employee_id, 0)) + int(sale["value"])
	var result := {}
	var salaries: Dictionary = day_payroll_snapshot["by_rep"]
	for employee_id in salaries:
		var salary := int(salaries[employee_id])
		var commission := _commission(employee_id, int(sales_by_rep.get(employee_id, 0)))
		result[employee_id] = {
			"name": floor_plan.profile(employee_id).get("name", employee_id),
			"base_salary": salary, "commission": commission, "earned": salary + commission,
			"expectation": _earnings_expectation(employee_id), "active": floor_plan.seats.has(employee_id),
		}
	return result


func _settle_rep_pay(pay_by_rep: Dictionary, finance: Dictionary) -> Array[Dictionary]:
	var departures: Array[Dictionary] = []
	var payroll_due := int(finance["current_upkeep"])
	var payroll_paid := int(finance["paid_current_upkeep"])
	var cumulative_due := 0
	var cumulative_paid := 0
	for employee_id in pay_by_rep:
		var pay: Dictionary = pay_by_rep[employee_id]
		cumulative_due += int(pay["earned"])
		# Round cumulative shares, so the individual payouts sum to payroll paid.
		@warning_ignore("integer_division")
		var next_paid := cumulative_due * payroll_paid / payroll_due if payroll_due > 0 else 0
		var paid := next_paid - cumulative_paid
		cumulative_paid = next_paid
		pay["paid"] = paid
		if paid < int(pay["expectation"]):
			inventory.fire_employee(employee_id)
			_clear_departed_rep(employee_id)
			departures.append(pay.duplicate(true))
		else:
			last_rep_pay[employee_id] = pay.duplicate(true)
			if pay["active"]:
				rep_experience[employee_id] = int(rep_experience.get(employee_id, 0)) + 1
	staffed_seats.assign(floor_plan.occupied_seats())
	return departures


func _prepare_next_day() -> void:
	if phase != Phase.REPORT or financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE \
		or not augment_manager.pending_reward.is_empty():
		return
	slam_board.stop()
	day_payroll_snapshot.clear()
	day = mini(day + 1, 60)
	financial_ledger.reset_daily_revenue(day)
	day_label.text = "DAY %02d / 60" % day
	_show_score_target()
	augment_manager.initialize_store_for_day(day)
	call_queue.reset(floor_plan.seats)
	pause_button.text = "Pause"
	_show_phase(Phase.PREPARE)
	_save_checkpoint()


func _save_checkpoint() -> void:
	if not RunSave.session_active or not first_day_complete or phase == Phase.PLAY:
		return
	var data := {
		"day": day,
		"phase": "report" if phase in [Phase.REPORT, Phase.TERMINATED, Phase.REWARD_MANAGEMENT] else "prepare",
		"first_day_complete": first_day_complete,
		"departments": {
			"lead_source": lead_source, "lead_quantity": lead_quantity,
			"commission_rates": commission_rates, "experience": rep_experience, "last_rep_pay": last_rep_pay,
		},
		"inventory": inventory.to_dict(),
		"augments": augment_manager.state_to_dict(),
		"finance": financial_ledger.to_dict(),
		"report": report_snapshot.duplicate(true),
	}
	if not RunSave.write(data):
		push_error("Could not autosave the quarter.")
		status_label.text = "Autosave failed. Your latest completed day may not be available to Resume."


func load_saved_run(data: Dictionary) -> bool:
	return _restore_run(data)


func _restore_run(data: Dictionary) -> bool:
	_restoring_run = true
	var saved_day := int(data.get("day", 0))
	var saved_phase := str(data.get("phase", ""))
	if saved_day < 1 or saved_day > 60 or saved_phase not in ["prepare", "report"]:
		_restoring_run = false
		return false
	var saved_inventory: Variant = data.get("inventory", {})
	var saved_augments: Variant = data.get("augments", {})
	var saved_finance: Variant = data.get("finance", {})
	var saved_report: Variant = data.get("report", {})
	if not saved_inventory is Dictionary or not saved_augments is Dictionary \
			or not saved_finance is Dictionary or not saved_report is Dictionary:
		_restoring_run = false
		return false
	if saved_phase == "report" and saved_report.is_empty():
		_restoring_run = false
		return false
	if not inventory.load_dict(saved_inventory):
		_restoring_run = false
		return false
	if not financial_ledger.load_dict(saved_finance):
		_restoring_run = false
		return false
	if not augment_manager.load_state_dict(saved_augments):
		_restoring_run = false
		return false
	if augment_manager.budget != financial_ledger.company_cash:
		_restoring_run = false
		return false
	var departments: Variant = data.get("departments", {})
	if departments is Dictionary:
		var source := str(departments.get("lead_source", MarketingPanel.DEFAULT_SOURCE))
		lead_source = str(MarketingPanel.source_data(source)["id"])
		lead_quantity = clampi(int(departments.get("lead_quantity", MarketingPanel.DEFAULT_QUANTITY)), 0, MarketingPanel.MAX_QUANTITY)
		commission_rates = _saved_department_dictionary(departments.get("commission_rates", {}))
		rep_experience = _saved_department_dictionary(departments.get("experience", {}))
		last_rep_pay = _saved_department_dictionary(departments.get("last_rep_pay", {}))
	day = saved_day
	first_day_complete = bool(data.get("first_day_complete", true))
	report_snapshot = saved_report.duplicate(true)
	selected_seat = 0
	staffed_seats.assign(floor_plan.occupied_seats())
	call_queue.reset(floor_plan.seats)
	if saved_phase == "report":
		call_queue.revenue = int(report_snapshot.get("revenue", 0))
		call_queue.elapsed_seconds = float(report_snapshot.get("elapsed_seconds", DAY_TICKS * CallQueueSimulation.TICK_SECONDS))
		call_queue.elapsed_ticks = floori(call_queue.elapsed_seconds / CallQueueSimulation.TICK_SECONDS)
	day_label.text = "DAY %02d / 60" % day
	_show_score_target()
	_refresh_augment_views()
	if saved_phase == "report":
		_display_saved_report()
		_show_phase(Phase.TERMINATED if financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE else Phase.REPORT)
		var sales: Array = report_snapshot.get("sale_log", [])
		slam_board.play(sales, score_target(day))
		slam_board.skip()
	else:
		_show_phase(Phase.PREPARE)
	_restoring_run = false
	return true


func _saved_department_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _display_saved_report() -> void:
	var report := report_snapshot
	var finance: Dictionary = report.get("finance", {})
	var workload: Array[Dictionary] = []
	workload.assign(report.get("workload", []))
	report_panel.show_results(
		int(report.get("day", day)), int(report.get("revenue", 0)), int(report.get("handled", 0)),
		int(report.get("normal_sales", 0)), int(report.get("sales", 0)),
		int(report.get("failed", 0)), int(report.get("discarded", 0)),
		int(report.get("recovery_attempts", 0)), int(report.get("recovered", 0)),
		int(report.get("failed_recoveries", 0)), int(report.get("recovered_revenue", 0)),
		int(report.get("received", 0)), int(report.get("waiting", 0)),
		int(report.get("unfinished", 0)), int(report.get("abandoned", 0)), workload,
		finance.get("rep_pay", {})
	)
	report_panel.show_financial_results(finance)
	_update_results_overview(report)
	_refresh_reward_ui()
	if augment_manager.pending_reward.is_empty():
		report_panel.show_reward_resolved()


func _update_results_overview(report: Dictionary) -> void:
	var stats: GridContainer = results_overview.get_node("OverviewStats")
	var handled := int(report.get("handled", 0))
	var conversion := 0.0 if handled == 0 else float(report.get("normal_sales", 0)) / float(handled) * 100.0
	(stats.get_node("Sales") as Label).text = "SALES\n%d" % int(report.get("sales", 0))
	(stats.get_node("Handled") as Label).text = "CALLS HANDLED\n%d" % handled
	(stats.get_node("Conversion") as Label).text = "NORMAL CONVERSION\n%.0f%%" % conversion
	(stats.get_node("Abandoned") as Label).text = "LEFT WHILE WAITING\n%d" % int(report.get("abandoned", 0))
	(results_overview.get_node("OverviewInsight") as Label).text = report_panel.insight_label.text


func _refresh_floor() -> void:
	var game_minutes := clampi(floori(call_queue.elapsed_seconds / EmployeeRoster.REAL_SECONDS_PER_GAME_HOUR * 60.0), 0, 720)
	shift_clock.text = "%02d:%02d / 12:00" % [floori(game_minutes / 60.0), game_minutes % 60]
	var state := "PREPARE"
	if phase in [Phase.REPORT, Phase.TERMINATED]:
		state = "CLOSED"
	elif phase == Phase.PLAY:
		state = "PAUSED" if paused else "LIVE"
	_refresh_card_stats()
	for index in employee_cards.size():
		employee_cards[index].set_planning_state(_is_management_phase() and not tutorial_panel.visible, index == selected_seat)
		var employee_id := floor_plan.seats[index]
		var break_remaining := 0.0
		if call_queue.employee_stats.has(employee_id):
			break_remaining = float(call_queue.employee_stats[employee_id]["break_remaining_seconds"])
		employee_cards[index].show_call(call_queue.active.get(index, {}), state,
			call_queue.completed_this_tick.get(index, {}), break_remaining)
	primary_button.disabled = phase == Phase.PREPARE and not _can_start_day()
	department_start.disabled = not _can_start_day()
	var start_hint := ""
	if phase == Phase.PREPARE:
		if staffed_seats.is_empty():
			start_hint = "Seat at least one rep on the Sales Floor."
		elif _lead_cost() > financial_ledger.company_cash:
			start_hint = "Reduce your lead order in Marketing before starting."
	primary_button.tooltip_text = start_hint
	department_start.tooltip_text = start_hint
	store_panel.start_button.tooltip_text = start_hint
	if tutorial_panel.visible:
		_refresh_first_day_guide()
	revenue_label.text = "SALES $%d · CASH $%d" % [
		call_queue.revenue, augment_manager.budget,
	]
	queue_panel.update_queue(
		call_queue.waiting, call_queue.active.size(), call_queue.handled,
		call_queue.received, state, call_queue.last_dispatch, call_queue.abandoned,
		call_queue.get_discard_count(),
		call_queue.elapsed_seconds / CallQueueSimulation.TICK_SECONDS
	)
