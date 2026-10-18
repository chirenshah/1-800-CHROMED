extends PanelContainer
class_name ReportPanel

signal next_day_requested

@onready var title_label: Label = $Margin/Content/Title
@onready var revenue_label: Label = $Margin/Content/RevenueLabel
@onready var calls_label: Label = $Margin/Content/CallsLabel
@onready var conversion_label: Label = $Margin/Content/ConversionLabel
@onready var insight_label: Label = $Margin/Content/Insight
@onready var next_day_button: Button = $Margin/Content/NextDayButton


func _ready() -> void:
	next_day_button.pressed.connect(func() -> void: next_day_requested.emit())


func show_results(day: int, revenue: int, calls: int, sales: int) -> void:
	var conversion := 0.0 if calls == 0 else float(sales) / float(calls) * 100.0
	title_label.text = "Day %d Performance" % day
	revenue_label.text = "Revenue  $%s" % _format_number(revenue)
	calls_label.text = "Calls handled  %d" % calls
	conversion_label.text = "Conversion  %.0f%%" % conversion
	insight_label.text = _build_insight(calls, conversion)


func _build_insight(calls: int, conversion: float) -> String:
	if calls == 0:
		return "No activity was recorded. Check the incoming lead source before the next day."
	if conversion < 20.0:
		return "The floor handled demand, but few calls converted. Review team fit and lead routing."
	return "The floor converted demand reliably. Look for idle capacity before increasing lead volume."


func _format_number(value: int) -> String:
	var digits := str(value)
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(-3) + output
		digits = digits.left(digits.length() - 3)
	return digits + output
