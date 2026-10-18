extends Control

enum Phase { PREPARE, PLAY, REPORT }

const EMPLOYEE_SCENE := preload("res://scenes/employee.tscn")
const DAY_TICKS := 12

@onready var prepare_tab: Button = $PageMargin/Page/Tabs/PrepareTab
@onready var play_tab: Button = $PageMargin/Page/Tabs/PlayTab
@onready var report_tab: Button = $PageMargin/Page/Tabs/ReportTab
@onready var phase_label: Label = $PageMargin/Page/Tabs/PhaseLabel
@onready var day_label: Label = $PageMargin/Page/Header/DayLabel
@onready var floor_grid: GridContainer = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorGrid
@onready var revenue_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/FloorHeader/RevenueLabel
@onready var status_label: Label = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/StatusLabel
@onready var pause_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PauseButton
@onready var primary_button: Button = $PageMargin/Page/Body/FloorPanel/FloorMargin/FloorContent/Footer/PrimaryButton
@onready var report_panel: ReportPanel = $PageMargin/Page/Body/ReportPanel
@onready var day_timer: Timer = $DayTimer

var phase := Phase.PREPARE
var day := 1
var tick := 0
var revenue := 0
var calls := 0
var sales := 0
var paused := false
var employee_cards: Array[EmployeeCard] = []


func _ready() -> void:
	_build_floor()
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


func _show_phase(next_phase: Phase) -> void:
	phase = next_phase
	report_panel.visible = phase == Phase.REPORT
	prepare_tab.disabled = phase != Phase.PREPARE
	play_tab.disabled = phase != Phase.PLAY
	report_tab.disabled = tick < DAY_TICKS or phase == Phase.REPORT
	pause_button.disabled = phase != Phase.PLAY
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


func _on_primary_pressed() -> void:
	if phase == Phase.PREPARE:
		_start_day()
	elif phase == Phase.PLAY:
		_finish_day()


func _start_day() -> void:
	tick = 0
	revenue = 0
	calls = 0
	sales = 0
	paused = false
	revenue_label.text = "$0"
	pause_button.text = "Pause"
	_show_phase(Phase.PLAY)
	day_timer.start()


func _toggle_pause() -> void:
	paused = not paused
	day_timer.paused = paused
	pause_button.text = "Resume" if paused else "Pause"
	phase_label.text = "FLOOR PAUSED" if paused else "FLOOR LIVE"
	status_label.text = "Inspect the floor and its bottlenecks." if paused else "The floor is operating autonomously."


func _simulate_tick() -> void:
	tick += 1
	calls += 1 + tick % 3
	var made_sale := tick % 3 != 0
	if made_sale:
		sales += 1
		revenue += 180 + tick * 15
	revenue_label.text = "$%d" % revenue
	for index in employee_cards.size():
		employee_cards[index].set_working(index < 4 and (tick + index) % 3 != 0)
	status_label.text = "Processing lead batch %d of %d" % [tick, DAY_TICKS]
	if tick >= DAY_TICKS:
		_finish_day()


func _finish_day() -> void:
	day_timer.stop()
	day_timer.paused = false
	paused = false
	for card in employee_cards:
		card.set_working(false)
	report_panel.show_results(day, revenue, calls, sales)
	_show_phase(Phase.REPORT)


func _prepare_next_day() -> void:
	day = mini(day + 1, 60)
	day_label.text = "DAY %02d / 60" % day
	tick = 0
	_show_phase(Phase.PREPARE)
