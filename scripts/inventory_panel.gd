extends PanelContainer
class_name InventoryPanel
## Item (2x6) and salesperson (1x6) inventory views. Pure presentation over InventoryManager.

signal transfer_requested(data: Dictionary, target_kind: String, target_index: int)

var drop_validator := Callable():
	set(value):
		drop_validator = value
		for slot in item_cells + person_cells:
			slot.drop_validator = value

var item_cells: Array[InventorySlot] = []
var person_cells: Array[InventorySlot] = []
var items_section: VBoxContainer
var people_section: VBoxContainer
var _updating_cell_sizes := false


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.067, 0.106)
	style.set_border_width_all(1)
	style.border_color = Color(0.16, 0.21, 0.29)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	people_section = _build_section(
		row, "RESERVE EMPLOYEES  ·  %d slots" % InventoryManager.PERSON_SLOTS,
		InventoryManager.PERSON_SLOTS
	)
	for slot_index in InventoryManager.PERSON_SLOTS:
		var cell := _make_cell(people_section.get_child(1), InventoryManager.RESERVE, slot_index)
		person_cells.append(cell)
	items_section = _build_section(
		row, "AUGMENTS & ITEMS  ·  %d slots" % InventoryManager.ITEM_SLOTS,
		InventoryManager.ITEM_COLUMNS
	)
	for slot_index in InventoryManager.ITEM_SLOTS:
		item_cells.append(_make_cell(items_section.get_child(1), "item", slot_index))
	var size_source := get_parent() as Control
	if size_source == null:
		push_error("InventoryPanel requires a Control parent for responsive sizing.")
		return
	size_source.resized.connect(_update_cell_sizes)
	call_deferred("_update_cell_sizes")
	items_section.visible = true
	people_section.visible = true
	visible = false


func show_all() -> void:
	items_section.visible = true
	people_section.visible = true
	visible = true


func hide_all() -> void:
	items_section.visible = false
	people_section.visible = false
	visible = false


func show_state(augment_manager: AugmentManager, editable: bool) -> void:
	var inventory: InventoryManager = augment_manager.bag
	for slot_index in item_cells.size():
		var cell := item_cells[slot_index]
		cell.editable = editable
		var item := inventory.item_slots[slot_index]
		if item.is_empty():
			cell.show_contents("", "", "Empty item slot", {})
			continue
		var augment := AugmentManager.CATALOG.profile(item["augment_id"])
		var effect := _effect_text(augment)
		cell.show_contents(augment["name"], "%s\n%s" % [augment["rarity"], effect],
			"%s · %s\n%s\nWorth $%d" % [augment["name"], augment["rarity"], effect, augment["price"]],
			{"type": "item", "slot": slot_index}, Color(0.98, 0.72, 0.4))
	for slot_index in person_cells.size():
		var cell := person_cells[slot_index]
		cell.editable = editable
		var employee := inventory.floor_plan.profile(inventory.person_slots[slot_index])
		if employee.is_empty():
			cell.show_contents("", "", "Empty reserve slot", {})
			continue
		var loadout := inventory.equipped_instances(employee["id"])
		var augment_names: Array[String] = []
		for equipped: Dictionary in loadout:
			augment_names.append(AugmentManager.CATALOG.profile(equipped["augment_id"])["name"])
		var stats: Dictionary = augment_manager.modified_stats(employee["id"])
		var detail := "%s\nSPD %.2f · CNV %.0f%%" % [
			employee["archetype"], float(stats.get("speed", employee["speed"])),
			float(stats.get("conversion", employee["conversion"])),
		]
		if not augment_names.is_empty():
			detail += "\n◆ " + ", ".join(augment_names)
		cell.show_contents(employee["name"], detail,
			"%s · %s\nUpsell %.1f%% · ×%.2f · Upkeep $%.0f/day\nAugments: %s" % [
				employee["name"], employee["archetype"], float(stats.get("upsell_chance", employee["upsell_chance"])),
				float(stats.get("upsell_multiplier", employee["upsell_multiplier"])),
				float(stats.get("daily_upkeep", FloorPlan.CATALOG.daily_upkeep(employee["id"]))),
				", ".join(augment_names) if not augment_names.is_empty() else "none",
			],
			{"type": "person", "kind": InventoryManager.RESERVE, "index": slot_index})


func _build_section(parent: Control, title: String, columns: int) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_stretch_ratio = 1.0
	parent.add_child(section)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.29, 0.94, 0.82))
	section.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)
	return section


func _make_cell(grid: Node, kind: String, slot_index: int) -> InventorySlot:
	var cell := InventorySlot.new()
	cell.kind = kind
	cell.index = slot_index
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.dropped.connect(func(data: Dictionary, target_kind: String, target_index: int) -> void:
		transfer_requested.emit(data, target_kind, target_index))
	grid.add_child(cell)
	return cell


func _update_cell_sizes() -> void:
	if not is_node_ready() or _updating_cell_sizes:
		return
	_updating_cell_sizes = true
	var size_source := get_parent() as Control
	if size_source == null:
		push_error("InventoryPanel requires a Control parent for responsive sizing.")
		_updating_cell_sizes = false
		return
	var available_width := maxf(0.0, size_source.size.x - 32.0)
	var cell_width := maxf(64.0, (available_width / 2.0 - 30.0) / 6.0)
	var available_height := maxf(0.0, size_source.size.y - 42.0)
	var item_height := maxf(34.0, (available_height - 6.0) / 2.0)
	var person_height := maxf(52.0, available_height)
	var person_size := Vector2(cell_width, person_height)
	for cell in person_cells:
		if not cell.custom_minimum_size.is_equal_approx(person_size):
			cell.custom_minimum_size = person_size
	var item_size := Vector2(cell_width, item_height)
	for cell in item_cells:
		if not cell.custom_minimum_size.is_equal_approx(item_size):
			cell.custom_minimum_size = item_size
	_updating_cell_sizes = false


func _effect_text(augment: Dictionary) -> String:
	if augment.has("stat") and augment.has("bonus"):
		return "+%d pp Conversion" % int(augment["bonus"]) \
			if augment["stat"] == "conversion" else "+%d%% Speed" % int(augment["bonus"])
	return str(augment.get("description", "Rule-changing effect"))
