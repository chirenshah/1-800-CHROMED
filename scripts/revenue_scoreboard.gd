extends PanelContainer
class_name RevenueScoreboard

signal pause_requested
signal end_workday_requested

const CYAN := Color(0.29, 0.94, 0.82)
const AMBER := Color(0.98, 0.72, 0.25)
const MUTED := Color(0.62, 0.73, 0.79)

@onready var revenue_label: Label = $Margin/Content/RevenueLabel
@onready var target_label: Label = $Margin/Content/TargetLabel
@onready var progress_bar: ProgressBar = $Margin/Content/ProgressBar
@onready var progress_label: Label = $Margin/Content/ProgressLabel
@onready var feedback_label: Label = $Margin/Content/FeedbackLabel
@onready var pause_button: Button = $Margin/Content/PauseButton
@onready var end_workday_button: Button = $Margin/Content/EndWorkdayButton


func _ready() -> void:
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	end_workday_button.pressed.connect(func() -> void: end_workday_requested.emit())


func show_state(revenue: int, target: int, state: String, is_live: bool, paused: bool) -> void:
	var safe_target := maxi(target, 1)
	var progress := clampf(float(revenue) / float(safe_target), 0.0, 1.0)
	revenue_label.text = "$%d" % revenue
	target_label.text = "GOAL  $%d" % target
	progress_bar.value = progress * 100.0
	progress_label.text = "%d%% OF GOAL" % floori(progress * 100.0)
	if revenue > target:
		feedback_label.text = "GOAL EXCEEDED"
		feedback_label.add_theme_color_override("font_color", CYAN)
	elif revenue == target:
		feedback_label.text = "GOAL REACHED"
		feedback_label.add_theme_color_override("font_color", CYAN)
	else:
		feedback_label.text = "$%d TO GO" % (target - revenue)
		feedback_label.add_theme_color_override("font_color", AMBER)
	pause_button.disabled = not is_live
	pause_button.text = "Resume" if paused else "Pause"
	end_workday_button.disabled = not is_live
	if state == "CLOSED":
		feedback_label.text = "WORKDAY CLOSED"
		feedback_label.add_theme_color_override("font_color", MUTED)
