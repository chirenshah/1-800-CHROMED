extends Control

enum Phase { PREPARE, PLAY, REPORT }

const EMPLOYEE_SCENE := preload("res://scenes/employee.tscn")
const DAY_TICKS := 45

@onready var prepare_tab: Button = $PageMargin/Page/Tabs/PrepareTab
@onready var play_tab: Button = $PageMargin/Page/Tabs/PlayTab
@onready var report_tab: Button = $PageMargin/Page/Tabs/ReportTab
@onready var phase_label: Label = $PageMargin/Page/Tabs/PhaseLabel
@onready var day_label: Label = $PageMargin/Page/Header/DayLabel
@onready var floor_grid: GridContainer = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorScroll/FloorGrid
@onready var revenue_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/RevenueLabel
@onready var status_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/StatusLabel
@onready var pause_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PauseButton
@onready var primary_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PrimaryButton
@onready var report_panel: ReportPanel = $PageMargin/Page/Body/ReportPanel
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
var floor_plan := FloorPlan.new()
var selected_seat := 0


func _ready() -> void:
	_build_floor()
	call_queue.reset(floor_plan.seats)
	planning_panel.assignment_requested.connect(_assign_employee)
	planning_panel.bench_requested.connect(_bench_employee)
	prepare_tab.pressed.connect(func() -> void: _show_phase(Phase.PREPARE))
	play_tab.pressed.connect(func() -> void: _show_phase(Phase.PLAY))
	report_tab.pressed.connect(func() -> void: _show_phase(Phase.REPORT))
	primary_button.pressed.connect(_on_primary_pressed)
	pause_button.pressed.connect(_toggle_pause)
	report_panel.next_day_requested.connect(_prepare_next_day)
	day_timer.timeout.connect(_simulate_tick)
	resized.connect(_update_layout)
	_update_layout()
	_show_phase(Phase.PREPARE)


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
	if phase != Phase.PREPARE or not floor_plan.assign(seat, employee_id):
		return
	_sync_floor_plan()
	status_label.text = "%s assigned to Seat %02d. Intake priority stays with the seat." % [floor_plan.profile(employee_id)["name"], seat + 1]


func _bench_employee(seat: int) -> void:
	if phase != Phase.PREPARE or not floor_plan.bench(seat):
		return
	_sync_floor_plan()
	status_label.text = "Seat %02d is now open. The employee remains available in the planner." % (seat + 1)
	if staffed_seats.is_empty():
		status_label.text = "Assign at least one colleague before starting the workday."


func _sync_floor_plan() -> void:
	staffed_seats.assign(floor_plan.occupied_seats())
	for seat in employee_cards.size():
		employee_cards[seat].configure(seat + 1, floor_plan.profile(floor_plan.seats[seat]))
	planning_panel.show_plan(floor_plan, selected_seat)
	_refresh_floor()


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
	revenue_label.visible = phase != Phase.PREPARE
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
	call_queue.reset(floor_plan.seats)
	paused = false
	day_timer.paused = false
	pause_button.text = "Pause"
	_show_phase(Phase.PLAY)
	day_timer.start()


func _toggle_pause() -> void:
	if phase != Phase.PLAY:
		return
	paused = not paused
	day_timer.paused = paused
	pause_button.text = "Resume" if paused else "Pause"
	phase_label.text = "FLOOR PAUSED" if paused else "FLOOR LIVE"
	status_label.text = "Inspect the floor and its bottlenecks." if paused else "The floor is operating autonomously."
	_refresh_floor()


func _simulate_tick() -> void:
	if phase != Phase.PLAY or paused:
		return
	call_queue.advance()
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
	for employee in workload:
		employee["name"] = floor_plan.profile(employee["employee_id"]).get("name", employee["employee_id"])
	report_panel.show_results(
		day, call_queue.revenue, call_queue.handled, call_queue.sales,
		call_queue.received, call_queue.waiting.size(), call_queue.active.size(),
		call_queue.abandoned, workload
	)
	_show_phase(Phase.REPORT)


func _prepare_next_day() -> void:
	if phase != Phase.REPORT:
		return
	day = mini(day + 1, 60)
	day_label.text = "DAY %02d / 60" % day
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
		call_queue.elapsed_ticks
	)
