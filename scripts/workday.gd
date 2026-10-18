extends Control

enum Phase { PREPARE, PLAY, REPORT }

const EMPLOYEE_SCENE := preload("res://scenes/employee.tscn")
const DAY_TICKS := 12

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
@onready var day_timer: Timer = $DayTimer

var phase := Phase.PREPARE
var day := 1
var paused := false
var employee_cards: Array[EmployeeCard] = []
var staffed_seats: Array[int] = []
var call_queue := CallQueueSimulation.new()


func _ready() -> void:
	_build_floor()
	call_queue.reset(staffed_seats)
	prepare_tab.pressed.connect(func() -> void: _show_phase(Phase.PREPARE))
	play_tab.pressed.connect(func() -> void: _show_phase(Phase.PLAY))
	report_tab.pressed.connect(func() -> void: _show_phase(Phase.REPORT))
	primary_button.pressed.connect(_on_primary_pressed)
	pause_button.pressed.connect(_toggle_pause)
	report_panel.next_day_requested.connect(_prepare_next_day)
	day_timer.timeout.connect(_simulate_tick)
	_show_phase(Phase.PREPARE)


func _build_floor() -> void:
	var team := [
		["Mara Voss", "Closer"], ["Jax Rowan", "Qualifier"], ["Unassigned", "Open workstation"],
		["Ilya Chen", "Generalist"], ["Unassigned", "Open workstation"], ["Unassigned", "Open workstation"],
		["Unassigned", "Open workstation"], ["Unassigned", "Open workstation"], ["Unassigned", "Open workstation"]
	]
	for index in team.size():
		var card: EmployeeCard = EMPLOYEE_SCENE.instantiate()
		floor_grid.add_child(card)
		card.setup(index + 1, team[index][0], team[index][1])
		employee_cards.append(card)
		if card.staffed:
			staffed_seats.append(index)


func _show_phase(next_phase: Phase) -> void:
	phase = next_phase
	report_panel.visible = phase == Phase.REPORT
	queue_panel.visible = phase != Phase.REPORT
	prepare_tab.disabled = phase != Phase.PREPARE
	play_tab.disabled = phase != Phase.PLAY
	report_tab.disabled = phase != Phase.REPORT
	pause_button.disabled = phase != Phase.PLAY
	pause_button.visible = phase != Phase.REPORT
	primary_button.visible = phase != Phase.REPORT
	match phase:
		Phase.PREPARE:
			phase_label.text = "PREPARATION OPEN"
			status_label.text = "Arrange your team before opening the floor."
			primary_button.text = "Start Workday"
		Phase.PLAY:
			phase_label.text = "FLOOR LIVE"
			status_label.text = "The floor is operating autonomously."
			primary_button.text = "End Workday"
		Phase.REPORT:
			phase_label.text = "REPORT READY"
			status_label.text = "Review the results before preparing the next day."
	_refresh_floor()


func _on_primary_pressed() -> void:
	if phase == Phase.PREPARE:
		_start_day()
	elif phase == Phase.PLAY:
		_finish_day()


func _start_day() -> void:
	call_queue.reset(staffed_seats)
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
	status_label.text = "%d waiting · %d on call · %d handled" % [
		call_queue.waiting.size(), call_queue.active.size(), call_queue.handled
	]
	if call_queue.elapsed_ticks >= DAY_TICKS:
		_finish_day()


func _finish_day() -> void:
	day_timer.stop()
	day_timer.paused = false
	paused = false
	pause_button.text = "Pause"
	report_panel.show_results(
		day, call_queue.revenue, call_queue.handled, call_queue.sales,
		call_queue.received, call_queue.waiting.size(), call_queue.active.size()
	)
	_show_phase(Phase.REPORT)


func _prepare_next_day() -> void:
	day = mini(day + 1, 60)
	day_label.text = "DAY %02d / 60" % day
	call_queue.reset(staffed_seats)
	pause_button.text = "Pause"
	_show_phase(Phase.PREPARE)


func _refresh_floor() -> void:
	var state := "PREPARE"
	if phase == Phase.REPORT:
		state = "CLOSED"
	elif phase == Phase.PLAY:
		state = "PAUSED" if paused else "LIVE"
	for index in employee_cards.size():
		employee_cards[index].show_call(call_queue.active.get(index, {}), state)
	revenue_label.text = "$%d" % call_queue.revenue
	queue_panel.update_queue(
		call_queue.waiting, call_queue.active.size(), call_queue.handled,
		call_queue.received, state, call_queue.last_dispatch
	)
