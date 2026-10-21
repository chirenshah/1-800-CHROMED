extends Control

enum Phase { PREPARE, PLAY, REPORT }

const EMPLOYEE_SCENE := preload("res://scenes/employee.tscn")
const DAY_TICKS := 40
const BASE_SCORE_TARGET := 1000
const SCORE_TARGET_STEP := 250

@onready var prepare_tab: Button = $PageMargin/Page/Tabs/PrepareTab
@onready var play_tab: Button = $PageMargin/Page/Tabs/PlayTab
@onready var report_tab: Button = $PageMargin/Page/Tabs/ReportTab
@onready var items_button: Button = $PageMargin/Page/Tabs/ItemsButton
@onready var people_button: Button = $PageMargin/Page/Tabs/PeopleButton
@onready var inventory_panel: InventoryPanel = $PageMargin/Page/InventoryPanel
@onready var phase_label: Label = $PageMargin/Page/Tabs/PhaseLabel
@onready var day_label: Label = $PageMargin/Page/Header/DayLabel
@onready var floor_grid: GridContainer = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorScroll/FloorGrid
@onready var revenue_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/RevenueLabel
@onready var target_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/TargetLabel
@onready var status_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/StatusLabel
@onready var pause_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PauseButton
@onready var primary_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PrimaryButton
@onready var report_panel: ReportPanel = $PageMargin/Page/Body/ReportPanel
@onready var slam_board: SalesSlamBoard = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/SalesSlamBoard
@onready var queue_panel: CallQueuePanel = $PageMargin/Page/Body/CallQueuePanel
@onready var planning_panel: PlanningPanel = $PageMargin/Page/Body/PlanningPanel
@onready var floor_title: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/FloorTitle
@onready var planning_guide: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/PlanningGuide
@onready var day_timer: Timer = $DayTimer

var phase := Phase.PREPARE
var day := 1
var paused := false
var employee_cards: Array[EmployeeCard] = []
var staffed_seats: Array[int] = []
var call_queue := CallQueueSimulation.new()
var inventory := InventoryManager.new()
var floor_plan := inventory.floor_plan
var augment_manager := AugmentManager.new(inventory)
var selected_seat := 0


func _ready() -> void:
	_build_floor()
	call_queue.reset(floor_plan.seats)
	planning_panel.assignment_requested.connect(_assign_employee)
	planning_panel.bench_requested.connect(_bench_employee)
	planning_panel.augment_purchase_requested.connect(_purchase_augment)
	planning_panel.augment_equip_requested.connect(_equip_augment)
	planning_panel.augment_unequip_requested.connect(_unequip_augment)
	planning_panel.surgery_requested.connect(_unlock_augment_slot)
	planning_panel.hire_requested.connect(_hire_employee)
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
	primary_button.pressed.connect(_on_primary_pressed)
	pause_button.pressed.connect(_toggle_pause)
	report_panel.next_day_requested.connect(_prepare_next_day)
	day_timer.timeout.connect(_on_day_timer_timeout)
	_refresh_augment_views()
	resized.connect(_update_layout)
	_update_layout()
	_show_score_target()
	_show_phase(Phase.PREPARE)


func score_target(for_day: int) -> int:
	return BASE_SCORE_TARGET + SCORE_TARGET_STEP * (for_day - 1)


func _show_score_target() -> void:
	planning_panel.show_score_target(day, score_target(day))
	target_label.text = "TARGET $%d  /  " % score_target(day)


func _build_floor() -> void:
	for index in FloorPlan.SEAT_COUNT:
		var card: EmployeeCard = EMPLOYEE_SCENE.instantiate()
		floor_grid.add_child(card)
		card.configure(index + 1, floor_plan.profile(floor_plan.seats[index]))
		card.seat_selected.connect(_select_seat)
		employee_cards.append(card)
	staffed_seats.assign(floor_plan.occupied_seats())


func _select_seat(seat: int) -> void:
	if phase != Phase.PREPARE or seat < 0 or seat >= FloorPlan.SEAT_COUNT:
		return
	selected_seat = seat
	planning_panel.show_plan(floor_plan, selected_seat, true)
	_refresh_floor()
	# Keep keyboard-selected seats visible at small window sizes.
	floor_grid.get_parent().ensure_control_visible(employee_cards[seat])


func _assign_employee(seat: int, employee_id: String) -> void:
	if phase != Phase.PREPARE or not inventory.deploy(seat, employee_id):
		return
	_sync_floor_plan()
	status_label.text = "%s assigned to Seat %02d. Intake priority stays with the seat." % [floor_plan.profile(employee_id)["name"], seat + 1]


func _bench_employee(seat: int) -> void:
	if phase != Phase.PREPARE or seat < 0 or seat >= FloorPlan.SEAT_COUNT:
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
	if phase != Phase.PREPARE:
		return
	if not augment_manager.hire(employee_id):
		status_label.text = "Hiring needs $%d and a free reserve slot." % AugmentManager.HIRE_COST
		return
	status_label.text = "%s hired into the salesperson reserve." % floor_plan.profile(employee_id)["name"]
	_sync_floor_plan()
	_refresh_augment_views()


func _toggle_inventory(items: bool) -> void:
	if items:
		inventory_panel.toggle_items()
	else:
		inventory_panel.toggle_people()
	items_button.set_pressed_no_signal(inventory_panel.items_open())
	people_button.set_pressed_no_signal(inventory_panel.people_open())
	_refresh_augment_views()


func _refresh_augment_views() -> void:
	planning_panel.update_augment_state(augment_manager, phase == Phase.PREPARE)
	inventory_panel.show_state(inventory, phase == Phase.PREPARE)


## Pure check shared by drag previews and the real transfer, so feedback matches outcomes.
func _can_transfer(data: Dictionary, target_kind: String, target_index: int) -> bool:
	if phase != Phase.PREPARE:
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
	if phase != Phase.PREPARE or not _can_transfer(data, target_kind, target_index):
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


func _purchase_augment(offer_index: int) -> void:
	if phase != Phase.PREPARE:
		return
	if not augment_manager.purchase(offer_index):
		status_label.text = "That augment cannot be purchased: check the budget and free item slots."
		return
	var augment_id: String = augment_manager.shop_offers[offer_index]
	status_label.text = "%s added to inventory." % AugmentManager.CATALOG.profile(augment_id)["name"]
	_refresh_augment_views()


func _equip_augment(employee_id: String, inventory_index: int) -> void:
	if phase != Phase.PREPARE:
		return
	if not augment_manager.equip(employee_id, inventory_index):
		status_label.text = "No augment slot is available for that employee."
		return
	status_label.text = "Augment equipped on %s." % floor_plan.profile(employee_id).get("name", employee_id)
	_refresh_augment_views()
	_refresh_card_stats()


func _unequip_augment(employee_id: String, slot_index: int) -> void:
	if phase != Phase.PREPARE:
		return
	if not augment_manager.unequip(employee_id, slot_index):
		status_label.text = "That augment slot is empty or the item inventory is full."
		return
	status_label.text = "Augment returned to inventory."
	_refresh_augment_views()
	_refresh_card_stats()


func _unlock_augment_slot(employee_id: String) -> void:
	if phase != Phase.PREPARE:
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


func _refresh_card_stats() -> void:
	for seat in employee_cards.size():
		var employee_id := floor_plan.seats[seat]
		employee_cards[seat].configure(seat + 1, floor_plan.profile(employee_id), augment_manager.loadout(employee_id))


func _update_layout() -> void:
	if not is_node_ready():
		return
	var compact := size.y < 650
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


func _show_phase(next_phase: Phase) -> void:
	phase = next_phase
	report_panel.visible = phase == Phase.REPORT
	queue_panel.visible = phase == Phase.PLAY
	planning_panel.visible = phase == Phase.PREPARE
	planning_guide.visible = phase == Phase.PREPARE
	floor_grid.get_parent().visible = phase != Phase.REPORT
	slam_board.visible = phase == Phase.REPORT
	revenue_label.visible = phase != Phase.PREPARE
	_refresh_augment_views()
	prepare_tab.disabled = phase != Phase.PREPARE
	play_tab.disabled = phase != Phase.PLAY
	report_tab.disabled = phase != Phase.REPORT
	pause_button.disabled = phase != Phase.PLAY
	pause_button.visible = phase == Phase.PLAY
	primary_button.visible = phase != Phase.REPORT
	match phase:
		Phase.PREPARE:
			phase_label.text = "PREPARATION OPEN"
			status_label.text = "Arrange your team before opening the floor."
			primary_button.text = "Start Workday"
			floor_title.text = "FLOOR PLAN"
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
	_refresh_floor()


func _on_primary_pressed() -> void:
	if phase == Phase.PREPARE:
		_start_day()
	elif phase == Phase.PLAY:
		_finish_day()


func _start_day() -> void:
	if phase != Phase.PREPARE or staffed_seats.is_empty():
		return
	call_queue.reset(floor_plan.seats, -1, augment_manager.equipment)
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
	var workload := call_queue.employee_results()
	augment_manager.budget += call_queue.revenue
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
	call_queue.clear_discard_pile()
	_show_phase(Phase.REPORT)
	# The slam only replays recorded sales; the budget above is already final and is never touched again.
	var recorded := call_queue.sale_log.duplicate(true)
	assert(slam_board.plan.total(recorded) == call_queue.revenue, "Recorded sales must add up to the day's revenue.")
	slam_board.play(recorded, score_target(day))


func _prepare_next_day() -> void:
	if phase != Phase.REPORT:
		return
	slam_board.stop()
	day = mini(day + 1, 60)
	day_label.text = "DAY %02d / 60" % day
	_show_score_target()
	augment_manager.refresh_shop()
	_refresh_augment_views()
	call_queue.reset(floor_plan.seats)
	pause_button.text = "Pause"
	_show_phase(Phase.PREPARE)


func _refresh_floor() -> void:
	var state := "PREPARE"
	if phase == Phase.REPORT:
		state = "CLOSED"
	elif phase == Phase.PLAY:
		state = "PAUSED" if paused else "LIVE"
	for index in employee_cards.size():
		employee_cards[index].set_planning_state(phase == Phase.PREPARE, index == selected_seat)
		employee_cards[index].show_call(call_queue.active.get(index, {}), state,
			call_queue.completed_this_tick.get(index, {}))
	primary_button.disabled = phase == Phase.PREPARE and staffed_seats.is_empty()
	revenue_label.text = "$%d" % call_queue.revenue
	queue_panel.update_queue(
		call_queue.waiting, call_queue.active.size(), call_queue.handled,
		call_queue.received, state, call_queue.last_dispatch, call_queue.abandoned,
		call_queue.get_discard_count(),
		call_queue.elapsed_seconds / CallQueueSimulation.TICK_SECONDS
	)
