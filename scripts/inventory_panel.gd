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


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.067, 0.106)
	style.set_border_width_all(1)
	style.border_color = Color(0.16, 0.21, 0.29)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	items_section = _build_section(row, "ITEM INVENTORY  ·  %d slots" % InventoryManager.ITEM_SLOTS, InventoryManager.ITEM_COLUMNS)
	for slot_index in InventoryManager.ITEM_SLOTS:
		item_cells.append(_make_cell(items_section.get_child(1), "item", slot_index))
		item_cells[slot_index].custom_minimum_size = Vector2(88, 52)
	people_section = _build_section(row, "SALESPERSON RESERVE  ·  %d slots" % InventoryManager.PERSON_SLOTS, InventoryManager.PERSON_SLOTS)
	for slot_index in InventoryManager.PERSON_SLOTS:
		var cell := _make_cell(people_section.get_child(1), InventoryManager.RESERVE, slot_index)
		cell.custom_minimum_size = Vector2(96, 78)
		person_cells.append(cell)
	items_section.visible = false
	people_section.visible = false
	visible = false


func toggle_items() -> void:
	items_section.visible = not items_section.visible
	_sync_visibility()


func toggle_people() -> void:
	people_section.visible = not people_section.visible
	_sync_visibility()


func items_open() -> bool:
	return items_section.visible


func people_open() -> bool:
	return people_section.visible


func show_state(inventory: InventoryManager, editable: bool) -> void:
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
		var detail := "%s\nSPD %d · CNV %d%%" % [employee["archetype"], employee["speed"], employee["conversion"]]
		if not augment_names.is_empty():
			detail += "\n◆ " + ", ".join(augment_names)
		cell.show_contents(employee["name"], detail,
			"%s · %s\nUpsell %d%% · ×%.1f\nAugments: %s" % [employee["name"], employee["archetype"], employee["upsell_chance"],
				employee["upsell_multiplier"], ", ".join(augment_names) if not augment_names.is_empty() else "none"],
			{"type": "person", "kind": InventoryManager.RESERVE, "index": slot_index})


func _sync_visibility() -> void:
	visible = items_section.visible or people_section.visible


func _build_section(parent: Control, title: String, columns: int) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(0.29, 0.94, 0.82))
	section.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)
	return section


func _make_cell(grid: Node, kind: String, slot_index: int) -> InventorySlot:
	var cell := InventorySlot.new()
	cell.kind = kind
	cell.index = slot_index
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.dropped.connect(func(data: Dictionary, target_kind: String, target_index: int) -> void:
		transfer_requested.emit(data, target_kind, target_index))
	grid.add_child(cell)
	return cell


func _effect_text(augment: Dictionary) -> String:
	return "+%d pp Conversion" % int(augment["bonus"]) if augment["stat"] == "conversion" else "+%d%% Speed" % int(augment["bonus"])
