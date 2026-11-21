extends PanelContainer
class_name MarketingPanel
## Immediate planning choices. The workday owns and persists the selected campaign.

signal plan_changed(source_id: String, quantity: int)

const DEFAULT_SOURCE := "cold_list"
const DEFAULT_QUANTITY := 12
const MAX_QUANTITY := 100
const SOURCES := [
	{
		"id": "cold_list", "name": "Broad campaign", "cost": 10,
		"value": 240, "conversion_bonus": 0.0, "patience_ticks": 8.0,
		"description": "Broad reach at a low acquisition cost.",
	},
	{
		"id": "inquiries", "name": "Inbound inquiries", "cost": 20,
		"value": 300, "conversion_bonus": 12.0, "patience_ticks": 10.0,
		"description": "Interested callers with more time to discuss a purchase.",
	},
	{
		"id": "referrals", "name": "Qualified referrals", "cost": 30,
		"value": 360, "conversion_bonus": 20.0, "patience_ticks": 12.0,
		"description": "Screened buyers with higher-value needs.",
	},
]

var source_selector: OptionButton
var quantity_input: SpinBox
var summary_label: Label
var source_details: Label
var _cash := 0
var _updating := false


static func source_catalog() -> Array:
	return SOURCES.duplicate(true)


static func source_data(source_id: String) -> Dictionary:
	for source in SOURCES:
		if str(source["id"]) == source_id:
			return source.duplicate(true)
	return SOURCES[0].duplicate(true)


static func campaign_cost(source_id: String, quantity: int) -> int:
	return int(source_data(source_id)["cost"]) * clampi(quantity, 0, MAX_QUANTITY)


static func campaign_plan(source_id: String, quantity: int, duration_seconds: float = 36.0) -> Dictionary:
	var source := source_data(source_id)
	return {
		"source_id": source["id"], "quantity": clampi(quantity, 0, MAX_QUANTITY),
		"value": source["value"], "conversion_bonus": source["conversion_bonus"],
		"patience_ticks": source["patience_ticks"], "duration_seconds": duration_seconds,
	}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var title := Label.new()
	title.text = "MARKETING"
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var instructions := Label.new()
	instructions.text = "Choose a lead source and the number of inbound calls for the next shift."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instructions)
	var source_label := Label.new()
	source_label.text = "Lead source"
	content.add_child(source_label)
	source_selector = OptionButton.new()
	source_selector.custom_minimum_size.y = 42
	for source in SOURCES:
		source_selector.add_item("%s · $%d per lead" % [source["name"], source["cost"]])
		source_selector.set_item_metadata(source_selector.item_count - 1, source["id"])
	content.add_child(source_selector)
	source_details = Label.new()
	source_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(source_details)
	var quantity_row := HBoxContainer.new()
	quantity_row.add_theme_constant_override("separation", 16)
	content.add_child(quantity_row)
	var quantity_label := Label.new()
	quantity_label.text = "Leads per shift"
	quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quantity_row.add_child(quantity_label)
	quantity_input = SpinBox.new()
	quantity_input.min_value = 0
	quantity_input.max_value = MAX_QUANTITY
	quantity_input.step = 1
	quantity_input.value = DEFAULT_QUANTITY
	quantity_input.custom_minimum_size = Vector2(140, 42)
	quantity_row.add_child(quantity_input)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary_label)
	var timing := Label.new()
	timing.text = "Changes apply to the upcoming shift. Lead costs are paid when the shift starts, including leads that later abandon or fail to convert."
	timing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(timing)
	source_selector.item_selected.connect(func(_index: int) -> void: _on_choice_changed())
	quantity_input.value_changed.connect(func(_value: float) -> void: _on_choice_changed())
	_refresh_summary()


func show_plan(source_id: String, quantity: int, cash: int, editable: bool = true) -> void:
	_updating = true
	_cash = cash
	var canonical_id := str(source_data(source_id)["id"])
	for index in source_selector.item_count:
		if str(source_selector.get_item_metadata(index)) == canonical_id:
			source_selector.select(index)
			break
	quantity_input.value = clampi(quantity, 0, MAX_QUANTITY)
	source_selector.disabled = not editable
	quantity_input.editable = editable
	_refresh_summary()
	_updating = false


func _on_choice_changed() -> void:
	_refresh_summary()
	if not _updating:
		plan_changed.emit(_selected_source(), int(quantity_input.value))


func _selected_source() -> String:
	return str(source_selector.get_item_metadata(source_selector.selected))


func _refresh_summary() -> void:
	var source_id := _selected_source()
	var source := source_data(source_id)
	var quantity := int(quantity_input.value)
	var cost := campaign_cost(source_id, quantity)
	source_details.text = "%s\nSale value $%d · Conversion adjustment +%d points · Waiting patience %.1f seconds" % [
		source["description"], source["value"], int(source["conversion_bonus"]),
		float(source["patience_ticks"]) * CallQueueSimulation.TICK_SECONDS,
	]
	summary_label.text = "%d leads · $%d acquisition cost · $%d company cash" % [quantity, cost, _cash]
	summary_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.42) if cost > _cash else Color(0.88, 0.94, 1.0))
	if cost > _cash:
		summary_label.text += "\nReduce the order or free up cash before starting the shift."
