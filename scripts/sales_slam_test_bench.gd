extends Control
## Standalone Sales Slam sandbox: run this scene (F6) and click a scenario.

var board: SalesSlamBoard
var readout: Label


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.047, 0.078)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "SALES SLAM TEST BENCH"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var buttons := HFlowContainer.new()
	column.add_child(buttons)
	for scenario in SalesSlamScenarios.all():
		var button := Button.new()
		button.text = scenario["name"]
		button.pressed.connect(_play.bind(scenario))
		buttons.add_child(button)
	var midway := Button.new()
	midway.text = "Skip midway"
	midway.pressed.connect(_skip_midway)
	buttons.add_child(midway)
	readout = Label.new()
	readout.text = "Pick a scenario."
	column.add_child(readout)
	board = SalesSlamBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.finished.connect(_on_finished)
	column.add_child(board)


func _play(scenario: Dictionary) -> void:
	readout.text = "%s · goal $%d · recorded $%d" % [scenario["name"], scenario["goal"], SalesSlamPlan.new().total(scenario["sales"])]
	board.play(scenario["sales"], scenario["goal"])


func _skip_midway() -> void:
	_play(SalesSlamScenarios.named("Greatly exceeding"))
	await get_tree().create_timer(1.0).timeout
	board.skip()


func _on_finished(result: Dictionary) -> void:
	readout.text += "  →  final $%d, demolitions %d" % [result["total"], result["demolitions"]]
