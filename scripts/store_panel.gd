extends PanelContainer
class_name StorePanel
## Prepare-phase storefront. It renders state owned by AugmentManager and never rolls stock itself.

signal augment_purchase_requested(slot_index: int)
signal employee_hire_requested(slot_index: int)
signal reroll_requested
signal start_workday_requested

const COMMON := Color(0.30, 0.80, 0.92)
const UNCOMMON := Color(0.35, 0.88, 0.59)
const RARE := Color(0.42, 0.64, 1.0)
const EPIC := Color(0.88, 0.42, 0.96)
const LEGENDARY := Color(1.0, 0.72, 0.28)
const TEXT := Color(0.92, 0.95, 1.0)
const MUTED := Color(0.57, 0.67, 0.76)
const DARK := Color(0.035, 0.052, 0.082)

var cash_label: Label
var day_label: Label
var reroll_button: Button
var start_button: Button
var feedback_label: Label
var augment_buy_buttons: Array[Button] = []
var employee_hire_buttons: Array[Button] = []
var _standard_cards: Array[Dictionary] = []
var _premium_card: Dictionary = {}
var _employee_cards: Array[Dictionary] = []


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _panel_style(Color(0.17, 0.33, 0.40), DARK))
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title := _label("CHROME MARKET", 22, Color(0.98, 0.30, 0.76))
	heading.add_child(title)
	day_label = _label("DAY 01 · PREPARE", 12, MUTED)
	heading.add_child(day_label)
	cash_label = _label("COMPANY CASH  $500", 17, LEGENDARY)
	header.add_child(cash_label)
	reroll_button = Button.new()
	reroll_button.text = "REROLL STORE — $100"
	reroll_button.custom_minimum_size = Vector2(188, 42)
	reroll_button.tooltip_text = "Spend company cash to replace all seven offerings."
	reroll_button.add_theme_stylebox_override("normal", _panel_style(Color(0.82, 0.31, 0.70), Color(0.16, 0.06, 0.18)))
	reroll_button.add_theme_stylebox_override("hover", _panel_style(Color(1.0, 0.50, 0.85), Color(0.24, 0.07, 0.24)))
	reroll_button.add_theme_color_override("font_color", TEXT)
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	header.add_child(reroll_button)
	start_button = Button.new()
	start_button.text = "START WORKDAY"
	start_button.custom_minimum_size = Vector2(150, 42)
	start_button.add_theme_stylebox_override("normal", _panel_style(Color(0.25, 0.78, 0.67), Color(0.035, 0.14, 0.13)))
	start_button.add_theme_color_override("font_color", TEXT)
	start_button.pressed.connect(func() -> void: start_workday_requested.emit())
	header.add_child(start_button)

	content.add_child(_section_heading("CYBERNETIC AUGMENTS — 4 STANDARD SLOTS"))
	var standard_row := HBoxContainer.new()
	standard_row.add_theme_constant_override("separation", 8)
	standard_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(standard_row)
	for slot_index in AugmentManager.STANDARD_STORE_SLOTS:
		var card := _build_augment_card(standard_row, slot_index, false)
		_standard_cards.append(card)
		augment_buy_buttons.append(card["buy_button"])

	content.add_child(_section_heading("PREMIUM AUGMENT — EPIC / LEGENDARY"))
	_premium_card = _build_augment_card(content, AugmentManager.PREMIUM_STORE_SLOT, true)
	augment_buy_buttons.append(_premium_card["buy_button"])

	content.add_child(_section_heading("RECRUITMENT — 2 SALESPEOPLE"))
	var employee_row := HBoxContainer.new()
	employee_row.add_theme_constant_override("separation", 8)
	employee_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(employee_row)
	for slot_index in AugmentManager.EMPLOYEE_STORE_SLOTS:
		var card := _build_employee_card(
			employee_row, AugmentManager.EMPLOYEE_STORE_START + slot_index
		)
		_employee_cards.append(card)
		employee_hire_buttons.append(card["hire_button"])

	feedback_label = _label("Offers stay fixed until reroll or the next workday.", 11, MUTED)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(feedback_label)


func _build_augment_card(parent: Control, slot_index: int, premium: bool) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 108 if premium else 116)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel", _panel_style(EPIC if premium else COMMON, Color(0.045, 0.065, 0.10))
	)
	parent.add_child(card)
	var inner: Control
	if premium:
		inner = HBoxContainer.new()
		inner.add_theme_constant_override("separation", 10)
	else:
		inner = VBoxContainer.new()
		inner.add_theme_constant_override("separation", 3)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	margin.add_child(inner)
	card.add_child(margin)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(details)
	var rarity_label := _label("STANDARD", 10, MUTED)
	details.add_child(rarity_label)
	var name_label := _label("Augment", 14, TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(name_label)
	var effect_label := _label("", 10, MUTED)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(effect_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(82 if premium else 0, 32)
	buy_button.pressed.connect(func() -> void: augment_purchase_requested.emit(slot_index))
	if premium:
		inner.add_child(buy_button)
	else:
		details.add_child(buy_button)
	return {
		"card": card,
		"rarity_label": rarity_label,
		"name_label": name_label,
		"effect_label": effect_label,
		"buy_button": buy_button,
	}


func _build_employee_card(parent: Control, slot_index: int) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 126)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.30, 0.76, 0.75), Color(0.045, 0.065, 0.10)))
	parent.add_child(card)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(66, 82)
	portrait.add_theme_stylebox_override("panel", _panel_style(Color(0.21, 0.49, 0.55), Color(0.025, 0.04, 0.065)))
	row.add_child(portrait)
	var portrait_label := _label("NO\nART", 11, MUTED)
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(portrait_label)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	var name_label := _label("Available candidate", 15, TEXT)
	details.add_child(name_label)
	var class_label := _label("", 11, COMMON)
	details.add_child(class_label)
	var stats_label := _label("", 10, MUTED)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(stats_label)
	var hire_button := Button.new()
	hire_button.custom_minimum_size = Vector2(112, 34)
	hire_button.pressed.connect(func() -> void: employee_hire_requested.emit(slot_index))
	details.add_child(hire_button)
	return {
		"name_label": name_label,
		"class_label": class_label,
		"stats_label": stats_label,
		"hire_button": hire_button,
	}


func show_state(
		manager: AugmentManager,
		day: int,
		editable: bool,
		can_start_workday: bool
	) -> void:
	day_label.text = "DAY %02d · PREPARE" % day
	cash_label.text = "COMPANY CASH  $%d" % manager.budget
	var reroll_cost := maxi(AugmentManager.CATALOG.store_reroll_cost, 0)
	reroll_button.text = "REROLL STORE — $%d" % reroll_cost
	reroll_button.disabled = not editable or manager.budget < reroll_cost
	start_button.disabled = not editable or not can_start_workday

	for slot_index in _standard_cards.size():
		_show_augment_card(_standard_cards[slot_index], manager, slot_index, editable)
	_show_augment_card(_premium_card, manager, AugmentManager.PREMIUM_STORE_SLOT, editable)
	for index in _employee_cards.size():
		_show_employee_card(
			_employee_cards[index], manager, AugmentManager.EMPLOYEE_STORE_START + index, editable
		)


func _show_augment_card(
		card: Dictionary,
		manager: AugmentManager,
		slot_index: int,
		editable: bool
	) -> void:
	var offer := manager.store_offer(slot_index)
	var status := str(offer.get("status", "sold_out"))
	var rarity_label: Label = card["rarity_label"]
	var name_label: Label = card["name_label"]
	var effect_label: Label = card["effect_label"]
	var buy_button: Button = card["buy_button"]
	var accent := _rarity_color(str(offer.get("rarity", "")))
	rarity_label.add_theme_color_override("font_color", accent)
	(card["card"] as PanelContainer).add_theme_stylebox_override(
		"panel", _panel_style(accent, Color(0.045, 0.065, 0.10))
	)
	if status == "sold":
		rarity_label.text = "SOLD"
		name_label.text = "Purchased"
		effect_label.text = "Added to your inventory. It remains yours after rerolls."
		buy_button.text = "SOLD"
		buy_button.disabled = true
		return
	if status != "available":
		rarity_label.text = "SOLD OUT"
		name_label.text = "No augment in this tier"
		effect_label.text = "No eligible catalog entry is available for this slot."
		buy_button.text = "SOLD OUT"
		buy_button.disabled = true
		return

	var augment := AugmentManager.CATALOG.profile(str(offer.get("augment_id", "")))
	if augment.is_empty():
		push_error("Store contains an unknown augment offer at slot %d." % slot_index)
		buy_button.disabled = true
		return
	var augment_name := str(augment.get("name", "Unknown augment"))
	var price := maxi(int(augment.get("price", 0)), 0)
	rarity_label.text = "%s · %s" % [
		str(offer.get("tier", "STANDARD")).to_upper(), str(augment.get("rarity", "Common")).to_upper(),
	]
	name_label.text = augment_name
	effect_label.text = _augment_effect_text(augment)
	effect_label.tooltip_text = str(augment.get("description", ""))
	buy_button.text = "BUY · $%d" % price
	buy_button.disabled = not editable or manager.bag.is_item_full() or manager.budget < price
	buy_button.tooltip_text = "The item inventory is full." if manager.bag.is_item_full() \
		else "Insufficient company cash." if manager.budget < price else "Add to item inventory; not auto-equipped."


func _show_employee_card(
		card: Dictionary,
		manager: AugmentManager,
		slot_index: int,
		editable: bool
	) -> void:
	var offer := manager.store_offer(slot_index)
	var status := str(offer.get("status", "sold_out"))
	var name_label: Label = card["name_label"]
	var class_label: Label = card["class_label"]
	var stats_label: Label = card["stats_label"]
	var hire_button: Button = card["hire_button"]
	if status == "sold":
		name_label.text = "HIRED"
		class_label.text = "Candidate unavailable"
		stats_label.text = "This unique employee has joined the company."
		hire_button.text = "SOLD"
		hire_button.disabled = true
		return
	var employee_id := str(offer.get("employee_id", ""))
	var employee := manager.employee_profile(employee_id)
	if status != "available" or employee.is_empty():
		name_label.text = "NO CANDIDATES"
		class_label.text = "Recruitment slot sold out"
		stats_label.text = "All eligible unique characters are already hired or fired."
		hire_button.text = "SOLD OUT"
		hire_button.disabled = true
		return
	if manager.bag.owns(employee_id) or manager.bag.fired_employee_ids.has(employee_id):
		name_label.text = "NO LONGER AVAILABLE"
		class_label.text = "Unique candidate unavailable"
		stats_label.text = "This employee was hired or fired during the current run."
		hire_button.text = "UNAVAILABLE"
		hire_button.disabled = true
		return
	name_label.text = str(employee.get("name", employee_id))
	class_label.text = str(employee.get("archetype", "Salesperson"))
	var stats := manager.modified_stats(employee_id)
	stats_label.text = "SPD %.1f · CNV %.0f%% · UP %.0f%%\n$%d hire · $%.0f/day upkeep" % [
		float(stats.get("speed", employee.get("speed", 0.0))),
		float(stats.get("conversion", employee.get("conversion", 0.0))),
		float(stats.get("upsell_chance", employee.get("upsell_chance", 0.0))),
		AugmentManager.HIRE_COST,
		float(stats.get("daily_upkeep", manager.daily_upkeep(employee_id))),
	]
	hire_button.text = "HIRE · $%d" % AugmentManager.HIRE_COST
	var reserve_full := manager.bag.is_reserve_full()
	var affordable := manager.budget >= AugmentManager.HIRE_COST
	hire_button.disabled = not editable or reserve_full or not affordable
	hire_button.tooltip_text = "The salesperson reserve is full." if reserve_full \
		else "Insufficient company cash." if not affordable else "Hires enter inactive reserve and incur daily upkeep."


func set_feedback(message: String, is_error := false) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.44) if is_error else MUTED)


func _augment_effect_text(augment: Dictionary) -> String:
	if augment.has("stat") and augment.has("bonus"):
		return "+%d pp Conversion" % int(augment["bonus"]) \
			if augment["stat"] == "conversion" else "+%d%% Speed" % int(augment["bonus"])
	return str(augment.get("description", "Rule-changing effect"))


func _section_heading(text: String) -> Label:
	var label := _label(text, 11, Color(0.31, 0.88, 0.81))
	return label


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style(border: Color, fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(4)
	style.set_content_margin_all(7)
	return style


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Common":
			return COMMON
		"Uncommon":
			return UNCOMMON
		"Rare":
			return RARE
		"Epic":
			return EPIC
		"Legendary":
			return LEGENDARY
		_:
			return MUTED
