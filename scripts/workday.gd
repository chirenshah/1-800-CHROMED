extends Control

enum Phase { PREPARE, PLAY, REPORT, REWARD_MANAGEMENT, TERMINATED }
enum PrepareView { FLOOR, STORE, CALENDAR }
@export_enum("End-of-day snapshot (prototype):end_of_day_snapshot")
var payroll_sampling_policy: String = "end_of_day_snapshot"

const EMPLOYEE_SCENE := preload("res://scenes/employee.tscn")
const DESK_ROW_TEXTURE: Texture2D = preload("res://assets/sales_floor/desk_row.png")
const DAY_TICKS := 48 # Twelve game hours at three real seconds per hour.
const BASE_SCORE_TARGET := 1000
const SCORE_TARGET_STEP := 250
const FLOOR_WIDTH := 700.0
const FLOOR_HEIGHT := 488.0
const FLOOR_PANEL_BORDER_INSET := 2.0
const DESK_ROW_WIDTH := 670.0
const DESK_ROW_HEIGHT := 150.0
const DESK_ROW_X := 15.0
const DESK_ROW_NAMES := ["BackRow", "MiddleRow", "FrontRow"]
const DESK_ROW_Y_OFFSETS := [68.0, 203.0, 338.0]
const EMPLOYEE_X_OFFSETS := [112.0, 335.0, 558.0]
const EMPLOYEE_CARD_WIDTH := 134.0
const EMPLOYEE_CARD_HEIGHT := 105.0
const REFERENCE_WIDTH := 1280.0
const REFERENCE_HEIGHT := 720.0
const HEADER_HEIGHT := 72.0
const BOTTOM_PANEL_HEIGHT := 160.0
const SIDEBAR_WIDTH := 160.0

@onready var prepare_sidebar: PanelContainer = $PageMargin/Page/Workspace/PrepareSidebar
@onready var scoreboard: RevenueScoreboard = $PageMargin/Page/Workspace/Scoreboard
@onready var floor_view_button: Button = $PageMargin/Page/Workspace/PrepareSidebar/Margin/Content/FloorButton
@onready var store_view_button: Button = $PageMargin/Page/Workspace/PrepareSidebar/Margin/Content/StoreButton
@onready var calendar_view_button: Button = $PageMargin/Page/Workspace/PrepareSidebar/Margin/Content/CalendarButton
@onready var begin_workday_button: Button = $PageMargin/Page/Workspace/PrepareSidebar/Margin/Content/BeginWorkdayButton
@onready var primary_button: Button = $PageMargin/Page/Workspace/PrepareSidebar/Margin/Content/BeginWorkdayButton
@onready var inventory_panel: InventoryPanel = $PageMargin/Page/BottomPanel/InventoryPanel
@onready var phase_label: Label = $PageMargin/Page/Header/PhaseLabel
@onready var day_label: Label = $PageMargin/Page/Header/DayLabel
@onready var cash_label: Label = $PageMargin/Page/Header/CashLabel
@onready var daily_goal_label: Label = $PageMargin/Page/Header/DailyGoalLabel
@onready var writeups_label: Label = $PageMargin/Page/Header/WriteupsLabel
@onready var shift_clock: Label = $PageMargin/Page/Header/ShiftClock
@onready var floor_grid: Control = $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin/FloorContent/FloorScroll/FloorGrid
@onready var sales_floor_art: Control = $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin/FloorContent/FloorScroll/FloorGrid/SalesFloorArt
@onready var floor_header: Control = $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin/FloorContent/FloorHeader
@onready var revenue_label: Label = $PageMargin/Page/Workspace/Scoreboard/Margin/Content/RevenueLabel
@onready var target_label: Label = $PageMargin/Page/Workspace/Scoreboard/Margin/Content/TargetLabel
@onready var status_label: Label = $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin/FloorContent/Footer/StatusLabel
@onready var pause_button: Button = $PageMargin/Page/Workspace/Scoreboard/Margin/Content/PauseButton
@onready var report_panel: ReportPanel = $PageMargin/Page/Workspace/MainContent/MainPanels/ReportPanel
@onready var slam_board: SalesSlamBoard = $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin/FloorContent/SalesSlamBoard
@onready var queue_panel: CallQueuePanel = $PageMargin/Page/BottomPanel/CallQueuePanel
@onready var planning_panel: PlanningPanel = $PageMargin/Page/Workspace/MainContent/MainPanels/PlanningPanel
@onready var store_panel: StorePanel = $PageMargin/Page/Workspace/MainContent/MainPanels/StorePanel
@onready var calendar_panel: CalendarPanel = $PageMargin/Page/Workspace/MainContent/MainPanels/CalendarPanel
@onready var floor_title: Label = $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin/FloorContent/FloorHeader/FloorTitle
@onready var planning_guide: Label = $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin/FloorContent/PlanningGuide
@onready var day_timer: Timer = $DayTimer

var phase := Phase.PREPARE
var prepare_view := PrepareView.STORE
var day := 1
var paused := false
var employee_cards: Array[EmployeeCard] = []
var staffed_seats: Array[int] = []
var call_queue := CallQueueSimulation.new()
var inventory := InventoryManager.new()
var floor_plan := inventory.floor_plan
var augment_manager := AugmentManager.new(inventory)
var financial_ledger := FinancialLedger.new()
var selected_seat := 1
var day_payroll_snapshot: Dictionary = {}
var _pending_fire_id := ""
var _fire_confirmation: ConfirmationDialog
var _augment_confirmation: ConfirmationDialog
var _pending_augment_action := ""
var _pending_augment_data: Dictionary = {}


func _ready() -> void:
	_build_floor()
	floor_grid.resized.connect(_layout_sales_floor)
	augment_manager.bind_financial_ledger(financial_ledger)
	augment_manager.initialize_store_for_day(day)
	financial_ledger.reset_daily_revenue(day, score_target(day))
	call_queue.sale_settlement_callback = Callable(self, "_settle_sale")
	call_queue.cash_effect_callback = Callable(self, "_apply_augment_cash_effect")
	call_queue.financial_context_provider = Callable(self, "_financial_context")
	call_queue.reset(floor_plan.seats)
	planning_panel.assignment_requested.connect(_assign_employee)
	planning_panel.bench_requested.connect(_bench_employee)
	planning_panel.augment_equip_requested.connect(_equip_augment)
	planning_panel.augment_replace_requested.connect(_request_replace_augment)
	planning_panel.augment_discard_requested.connect(_request_discard_augment)
	planning_panel.surgery_requested.connect(_unlock_augment_slot)
	planning_panel.hire_requested.connect(_hire_employee)
	planning_panel.fire_requested.connect(_request_fire_employee)
	planning_panel.return_reward_requested.connect(_return_to_pending_reward)
	inventory_panel.drop_validator = _can_transfer
	inventory_panel.transfer_requested.connect(_on_transfer_requested)
	for card in employee_cards:
		card.drop_validator = _can_transfer
		card.dropped.connect(_on_transfer_requested)
	store_panel.augment_purchase_requested.connect(_purchase_store_augment)
	store_panel.employee_hire_requested.connect(_hire_store_employee)
	store_panel.reroll_requested.connect(_reroll_store)
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
	day_timer.timeout.connect(_on_day_timer_timeout)
	var view_group := ButtonGroup.new()
	view_group.allow_unpress = false
	var view_buttons: Array[Button] = [floor_view_button, store_view_button, calendar_view_button]
	for button in view_buttons:
		button.button_group = view_group
	floor_view_button.pressed.connect(func() -> void: _select_prepare_view(PrepareView.FLOOR))
	store_view_button.pressed.connect(func() -> void: _select_prepare_view(PrepareView.STORE))
	calendar_view_button.pressed.connect(func() -> void: _select_prepare_view(PrepareView.CALENDAR))
	begin_workday_button.pressed.connect(_on_primary_pressed)
	scoreboard.pause_requested.connect(_toggle_pause)
	scoreboard.end_workday_requested.connect(_on_primary_pressed)
	_refresh_augment_views()
	_refresh_financial_ui()
	resized.connect(_update_layout)
	_update_layout()
	call_deferred("_update_layout")
	_show_score_target()
	_show_phase(Phase.PREPARE)


func score_target(for_day: int) -> int:
	return BASE_SCORE_TARGET + SCORE_TARGET_STEP * (for_day - 1)


func _show_score_target() -> void:
	var target := score_target(day)
	target_label.text = "GOAL $%d" % target
	daily_goal_label.text = "GOAL  $%d" % target


func _build_floor() -> void:
	for row_index in DESK_ROW_Y_OFFSETS.size():
		var row := Control.new()
		row.name = DESK_ROW_NAMES[row_index]
		row.position = Vector2(0.0, DESK_ROW_Y_OFFSETS[row_index])
		row.size = Vector2(FLOOR_WIDTH, DESK_ROW_HEIGHT)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		sales_floor_art.add_child(row)

		var slots := Control.new()
		slots.name = "EmployeeSlots"
		slots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slots.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(slots)

		var first_seat := row_index * 3
		for column in EMPLOYEE_X_OFFSETS.size():
			var index := first_seat + column
			var card: EmployeeCard = EMPLOYEE_SCENE.instantiate()
			card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			slots.add_child(card)
			card.set_compact(true, EMPLOYEE_CARD_HEIGHT)
			card.position = Vector2(
				DESK_ROW_X + EMPLOYEE_X_OFFSETS[column] - EMPLOYEE_CARD_WIDTH / 2.0,
				0.0
			)
			card.size = Vector2(EMPLOYEE_CARD_WIDTH, EMPLOYEE_CARD_HEIGHT)
			card.configure(index + 1, floor_plan.profile(floor_plan.seats[index]))
			card.seat_selected.connect(_select_seat)
			employee_cards.append(card)

		var desk_foreground := TextureRect.new()
		desk_foreground.name = "DeskForeground"
		desk_foreground.texture = DESK_ROW_TEXTURE
		desk_foreground.position = Vector2(DESK_ROW_X, 0.0)
		desk_foreground.size = Vector2(DESK_ROW_WIDTH, DESK_ROW_HEIGHT)
		desk_foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		desk_foreground.stretch_mode = TextureRect.STRETCH_SCALE
		desk_foreground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		desk_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(desk_foreground)
	staffed_seats.assign(floor_plan.occupied_seats())


func _select_seat(seat: int) -> void:
	if not _is_management_phase() or seat < 0 or seat >= FloorPlan.SEAT_COUNT:
		return
	selected_seat = seat
	planning_panel.show_plan(floor_plan, selected_seat, true)
	planning_panel.views.current_tab = 0
	_refresh_floor()
	# Keep keyboard-selected seats visible at small window sizes.
	floor_grid.get_parent().ensure_control_visible(employee_cards[seat])


func _assign_employee(seat: int, employee_id: String) -> void:
	if not _is_management_phase() or not inventory.deploy(seat, employee_id):
		return
	_sync_floor_plan()
	status_label.text = "%s assigned to Seat %02d. Intake priority stays with the seat." % [floor_plan.profile(employee_id)["name"], seat + 1]


func _bench_employee(seat: int) -> void:
	if not _is_management_phase() or seat < 0 or seat >= FloorPlan.SEAT_COUNT:
		return
	if inventory.is_reserve_full() and not floor_plan.seats[seat].is_empty():
		status_label.text = "Salesperson reserve is full. Free a slot before recalling."
		return
	if not inventory.recall(seat):
		return
	_sync_floor_plan()
	status_label.text = "Seat %02d is now open. The employee waits in the salesperson reserve." % (seat + 1)
	if staffed_seats.is_empty():
		status_label.text = "Assign at least one colleague before starting the workday."


func _hire_employee(employee_id: String) -> void:
	if not _is_management_phase():
		return
	if inventory.fired_employee_ids.has(employee_id):
		status_label.text = "%s was fired and cannot be rehired this run." % floor_plan.profile(employee_id).get("name", employee_id)
		return
	if not augment_manager.hire(employee_id):
		status_label.text = "Hiring needs $%d and a free reserve slot." % AugmentManager.HIRE_COST
		return
	status_label.text = "%s hired into the salesperson reserve." % floor_plan.profile(employee_id)["name"]
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
	augment_manager.second_slot_unlocked.erase(employee_id)
	_sync_floor_plan()
	_refresh_augment_views()
	status_label.text = "%s fired permanently. Installed augments were lost; debt and uninstalled items remain unchanged." % employee_name


func _cancel_fire_request() -> void:
	_pending_fire_id = ""


func _refresh_augment_views() -> void:
	planning_panel.update_augment_state(augment_manager, _is_management_phase())
	planning_panel.set_pending_reward_management(not augment_manager.pending_reward.is_empty())
	inventory_panel.show_state(augment_manager, _is_management_phase())
	_refresh_store_panel()
	_refresh_financial_ui()


func _refresh_store_panel() -> void:
	store_panel.show_state(augment_manager, phase == Phase.PREPARE)


func _payroll_snapshot() -> Dictionary:
	var active := 0
	var bench := 0
	var effective_stats: Dictionary = augment_manager.modified_floor_stats()
	for employee_id in floor_plan.seats:
		if not employee_id.is_empty():
			active += roundi(float(effective_stats.get(employee_id, {}).get("daily_upkeep", 0.0)))
	for employee_id in inventory.person_slots:
		if not employee_id.is_empty():
			bench += roundi(float(effective_stats.get(employee_id, {}).get("daily_upkeep", 0.0)))
	return {"active": active, "bench": bench, "total": active + bench}


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
	cash_label.text = "CASH  $%d" % augment_manager.budget
	writeups_label.text = "WRITE-UPS  %d/%d" % [
		financial_ledger.writeups, FinancialLedger.WRITEUPS_TO_TERMINATE,
	]
	_show_score_target()
	var projected := _payroll_snapshot()
	planning_panel.show_financial_state(
		augment_manager.budget, financial_ledger.daily_sales_revenue, financial_ledger.upkeep_debt,
		int(projected["active"]), int(projected["bench"])
	)


## Pure check shared by drag previews and the real transfer, so feedback matches outcomes.
func _can_transfer(data: Dictionary, target_kind: String, target_index: int) -> bool:
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


func _claim_reward(index: int) -> void:
	if not _is_report_phase():
		return
	if not augment_manager.claim_reward_to_inventory(index):
		status_label.text = "Cannot claim this reward: inventory is full or the offer is invalid."
		return
	report_panel.show_reward_resolved()
	status_label.text = "Augment claimed to inventory. All other reward choices were forfeited."
	_refresh_augment_views()


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


func _skip_reward() -> void:
	if not _is_report_phase() or not augment_manager.skip_daily_reward():
		return
	report_panel.show_reward_resolved()
	status_label.text = "Daily reward skipped. All three choices were forfeited."
	_refresh_augment_views()


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
	var header_ratio := HEADER_HEIGHT / REFERENCE_HEIGHT
	var bottom_ratio := BOTTOM_PANEL_HEIGHT / REFERENCE_HEIGHT
	var sidebar_ratio := SIDEBAR_WIDTH / REFERENCE_WIDTH
	var header := $PageMargin/Page/Header as Control
	var workspace := $PageMargin/Page/Workspace as Control
	var main_content := $PageMargin/Page/Workspace/MainContent as Control
	var sidebar_controls: Array[Control] = [
		$PageMargin/Page/Workspace/PrepareSidebar,
		$PageMargin/Page/Workspace/Scoreboard,
	]
	var bottom_panel := $PageMargin/Page/BottomPanel as Control
	_set_region(header, 0.0, 0.0, 1.0, header_ratio)
	_set_region(workspace, 0.0, header_ratio, 1.0, 1.0 - bottom_ratio)
	_set_region(bottom_panel, 0.0, 1.0 - bottom_ratio, 1.0, 1.0)
	_set_region(main_content, 0.0, 0.0, 1.0 - sidebar_ratio, 1.0)
	for control in sidebar_controls:
		_set_region(control, 1.0 - sidebar_ratio, 0.0, 1.0, 1.0)
	var bottom_children: Array[Control] = [
		$PageMargin/Page/BottomPanel/InventoryPanel,
		$PageMargin/Page/BottomPanel/CallQueuePanel,
	]
	for control in bottom_children:
		_set_region(control, 0.0, 0.0, 1.0, 1.0)
	var content_panels: Array[Control] = [
		$PageMargin/Page/Workspace/MainContent/MainPanels,
	]
	for panel in content_panels:
		_set_region(panel, 0.0, 0.0, 1.0, 1.0)
	var compact := size.y < 650
	$PageMargin/Page/Header.add_theme_constant_override("separation", 6 if compact else 12)
	$PageMargin/Page/Header/HeaderMargin/Brand/Title.add_theme_font_size_override("font_size", 20 if compact else 24)
	$PageMargin/Page/Workspace/MainContent/MainPanels.add_theme_constant_override("separation", 10 if compact else 14)
	var margin := $PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel/FloorMargin
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 0)
	for card in employee_cards:
		card.set_compact(true, EMPLOYEE_CARD_HEIGHT)
	_layout_sales_floor()
	calendar_panel.show_day(day)


func _layout_sales_floor() -> void:
	if not is_node_ready() or floor_grid.size.x <= 0.0 or floor_grid.size.y <= 0.0:
		return
	var compact := size.y < 650
	var main_content_width := size.x * (1.0 - SIDEBAR_WIDTH / REFERENCE_WIDTH)
	var panel_gap := 0.0
	var planning_width := 0.0
	if planning_panel.visible:
		panel_gap = 10.0 if compact else 14.0
		planning_width = planning_panel.custom_minimum_size.x
	var available_floor_width := maxf(
		0.0,
		minf(
			floor_grid.size.x,
			main_content_width - planning_width - panel_gap - FLOOR_PANEL_BORDER_INSET
		)
	)
	var scale_factor := minf(
		1.0,
		minf(available_floor_width / FLOOR_WIDTH, floor_grid.size.y / FLOOR_HEIGHT)
	)
	var rendered_size := Vector2(FLOOR_WIDTH, FLOOR_HEIGHT) * scale_factor
	sales_floor_art.scale = Vector2.ONE * scale_factor
	sales_floor_art.position = Vector2(
		(available_floor_width - rendered_size.x) / 2.0,
		(floor_grid.size.y - rendered_size.y) / 2.0
	)
	floor_header.offset_bottom = 32.0 * scale_factor
	planning_guide.offset_top = 34.0 * scale_factor
	planning_guide.offset_bottom = 68.0 * scale_factor
	floor_title.add_theme_font_size_override("font_size", 15 if scale_factor < 0.9 else 20)
	planning_guide.add_theme_font_size_override("font_size", 9 if scale_factor < 0.9 else 12)
	status_label.add_theme_font_size_override("font_size", 10 if scale_factor < 0.9 else 13)


func _set_region(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _select_prepare_view(view: PrepareView) -> void:
	if phase != Phase.PREPARE:
		return
	prepare_view = view
	_show_phase(Phase.PREPARE, false)


func _show_phase(next_phase: Phase, reset_prepare_view := true) -> void:
	if financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE and next_phase != Phase.TERMINATED:
		return
	if next_phase == Phase.PREPARE and reset_prepare_view:
		prepare_view = PrepareView.STORE
	phase = next_phase
	var report_visible := phase in [Phase.REPORT, Phase.TERMINATED]
	var store_visible := phase == Phase.PREPARE and prepare_view == PrepareView.STORE
	var calendar_visible := phase == Phase.PREPARE and prepare_view == PrepareView.CALENDAR
	var floor_visible := not store_visible and not calendar_visible
	report_panel.visible = report_visible
	queue_panel.visible = phase == Phase.PLAY
	store_panel.visible = store_visible
	calendar_panel.visible = calendar_visible
	$PageMargin/Page/Workspace/MainContent/MainPanels/FloorPanel.visible = floor_visible
	planning_panel.visible = phase == Phase.REWARD_MANAGEMENT
	planning_guide.visible = floor_visible and not report_visible
	floor_grid.get_parent().visible = not report_visible
	slam_board.visible = report_visible
	prepare_sidebar.visible = phase == Phase.PREPARE
	scoreboard.visible = phase == Phase.PLAY
	if phase in [Phase.PREPARE, Phase.REWARD_MANAGEMENT]:
		inventory_panel.show_all()
	else:
		inventory_panel.hide_all()
	floor_view_button.set_pressed_no_signal(phase == Phase.PREPARE and prepare_view == PrepareView.FLOOR)
	store_view_button.set_pressed_no_signal(store_visible)
	calendar_view_button.set_pressed_no_signal(calendar_visible)
	calendar_panel.show_day(day)
	_refresh_augment_views()
	if report_visible and not augment_manager.pending_reward.is_empty():
		_refresh_reward_ui()
	begin_workday_button.disabled = not _can_start_workday()
	pause_button.disabled = phase != Phase.PLAY
	scoreboard.end_workday_button.disabled = phase != Phase.PLAY
	match phase:
		Phase.PREPARE:
			phase_label.text = "PREPARE"
			status_label.text = "Arrange your team before opening the floor."
			floor_title.text = "FLOOR PLAN"
			if prepare_view == PrepareView.FLOOR:
				planning_panel.show_plan(floor_plan, selected_seat, true)
		Phase.REWARD_MANAGEMENT:
			phase_label.text = "REWARD MANAGEMENT"
			status_label.text = "Manage augments or inventory, then return to the same reward offer."
			floor_title.text = "TEAM MANAGEMENT"
			planning_panel.show_plan(floor_plan, selected_seat, true)
		Phase.PLAY:
			phase_label.text = "WORKDAY"
			status_label.text = "The floor is operating autonomously."
			floor_title.text = "SALES FLOOR"
		Phase.REPORT:
			phase_label.text = "REVIEW"
			status_label.text = "Review the results before preparing the next day."
			floor_title.text = "DAY CLOSED"
		Phase.TERMINATED:
			phase_label.text = "CONTRACT TERMINATED"
			status_label.text = "Three write-ups were issued. No further workdays can begin."
			floor_title.text = "RUN TERMINATED"
	_refresh_floor()


func _can_start_workday() -> bool:
	return phase == Phase.PREPARE and not staffed_seats.is_empty() \
		and financial_ledger.writeups < FinancialLedger.WRITEUPS_TO_TERMINATE \
		and augment_manager.pending_reward.is_empty()


func _on_primary_pressed() -> void:
	if phase == Phase.PREPARE:
		_start_day()
	elif phase == Phase.PLAY:
		_finish_day()


func _start_day() -> void:
	if phase != Phase.PREPARE or staffed_seats.is_empty() \
		or financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE \
		or not augment_manager.pending_reward.is_empty():
		return
	prepare_view = PrepareView.FLOOR
	financial_ledger.begin_workday()
	day_payroll_snapshot.clear()
	call_queue.reset(floor_plan.seats, -1, augment_manager.equipment_instances)
	paused = false
	day_timer.paused = false
	pause_button.text = "Pause"
	_show_phase(Phase.PLAY)
	_schedule_next_event()


func _toggle_pause() -> void:
	if phase != Phase.PLAY:
		return
	paused = not paused
	day_timer.paused = paused
	pause_button.text = "Resume" if paused else "Pause"
	phase_label.text = "FLOOR PAUSED" if paused else "FLOOR LIVE"
	status_label.text = "Inspect the floor and its bottlenecks." if paused else "The floor is operating autonomously."
	_refresh_floor()


func _schedule_next_event() -> void:
	var day_remaining := DAY_TICKS * CallQueueSimulation.TICK_SECONDS - call_queue.elapsed_seconds
	day_timer.start(maxf(CallQueueSimulation.TIME_EPSILON, minf(day_remaining, call_queue.time_until_next_event())))


func _on_day_timer_timeout() -> void:
	_simulate_tick(day_timer.wait_time)
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
	var daily_upkeep := int(day_payroll_snapshot["total"])
	var settlement_id := financial_ledger.next_settlement_id()
	assert(financial_ledger.daily_sales_revenue == call_queue.revenue,
		"Immediate sale settlements must match the workday sales tally.")
	var finance_result := financial_ledger.settle(
		settlement_id, augment_manager.budget, call_queue.revenue, daily_upkeep,
		call_queue.revenue >= score_target(day),
		int(day_payroll_snapshot["active"]), int(day_payroll_snapshot["bench"]), day,
		call_queue.elapsed_seconds
	)
	augment_manager.budget = int(finance_result["ending_cash"])
	var workload := call_queue.employee_results()
	for employee in workload:
		var profile := floor_plan.profile(employee["employee_id"])
		employee["name"] = profile.get("name", employee["employee_id"])
		employee["archetype"] = profile.get("archetype", "")
	report_panel.show_results(
		day, call_queue.revenue, call_queue.handled, call_queue.normal_sales, call_queue.sales,
		call_queue.failed_interactions, call_queue.discarded_today,
		call_queue.recovery_attempts, call_queue.recovered, call_queue.failed_recoveries,
		call_queue.recovered_revenue,
		call_queue.received, call_queue.waiting.size(), call_queue.active.size(),
		call_queue.abandoned, workload
	)
	report_panel.show_financial_results(finance_result)
	call_queue.clear_discard_pile()
	augment_manager.generate_daily_reward()
	_refresh_reward_ui()
	_show_phase(Phase.TERMINATED if finance_result["terminated"] else Phase.REPORT)
	# The slam only replays recorded sales; the budget above is already final and is never touched again.
	var recorded := call_queue.sale_log.duplicate(true)
	assert(slam_board.plan.total(recorded) == call_queue.revenue, "Recorded sales must add up to the day's revenue.")
	slam_board.play(recorded, score_target(day))


func _prepare_next_day() -> void:
	if phase != Phase.REPORT or financial_ledger.writeups >= FinancialLedger.WRITEUPS_TO_TERMINATE \
		or not augment_manager.pending_reward.is_empty():
		return
	slam_board.stop()
	day_payroll_snapshot.clear()
	day = mini(day + 1, 60)
	financial_ledger.reset_daily_revenue(day, score_target(day))
	day_label.text = _day_label_text()
	_show_score_target()
	augment_manager.initialize_store_for_day(day)
	_refresh_augment_views()
	call_queue.reset(floor_plan.seats)
	pause_button.text = "Pause"
	_show_phase(Phase.PREPARE)


func _day_label_text() -> String:
	var month := floori(float(day - 1) / 20.0) + 1
	var month_day := (day - 1) % 20 + 1
	return "MONTH %d · DAY %02d / 20" % [month, month_day]


func _refresh_floor() -> void:
	var game_minutes := clampi(floori(call_queue.elapsed_seconds / EmployeeRoster.REAL_SECONDS_PER_GAME_HOUR * 60.0), 0, 720)
	shift_clock.text = "%02d:%02d / 12:00" % [floori(game_minutes / 60.0), game_minutes % 60]
	day_label.text = _day_label_text()
	var state := "PREPARE"
	if phase in [Phase.REPORT, Phase.TERMINATED]:
		state = "CLOSED"
	elif phase == Phase.PLAY:
		state = "PAUSED" if paused else "LIVE"
	_refresh_card_stats()
	for index in employee_cards.size():
		employee_cards[index].set_planning_state(_is_management_phase(), index == selected_seat)
		var employee_id := floor_plan.seats[index]
		var break_remaining := 0.0
		if call_queue.employee_stats.has(employee_id):
			break_remaining = float(call_queue.employee_stats[employee_id]["break_remaining_seconds"])
		employee_cards[index].show_call(call_queue.active.get(index, {}), state,
			call_queue.completed_this_tick.get(index, {}), break_remaining)
	begin_workday_button.disabled = not _can_start_workday()
	revenue_label.text = "$%d" % call_queue.revenue
	scoreboard.show_state(call_queue.revenue, score_target(day), state, phase == Phase.PLAY, paused)
	queue_panel.update_queue(
		call_queue.waiting, call_queue.active.size(), call_queue.handled,
		call_queue.received, state, call_queue.last_dispatch, call_queue.abandoned,
		call_queue.get_discard_count(),
		call_queue.elapsed_seconds / CallQueueSimulation.TICK_SECONDS
	)
