extends SceneTree
## Godot --headless --path . --script res://tests/test_inventory.gd

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _all_person_ids(inventory: InventoryManager) -> Array[String]:
	var ids: Array[String] = []
	for id in inventory.floor_plan.seats + inventory.person_slots:
		if not id.is_empty():
			ids.append(id)
	return ids


func _test_items() -> void:
	var manager := AugmentManager.new()
	var inventory := manager.bag
	_check(inventory.item_slots.size() == 12 and InventoryManager.ITEM_ROWS == 2 and InventoryManager.ITEM_COLUMNS == 6,
		"Item inventory must be 2 rows by 6 columns.")
	_check(inventory.person_slots.size() == 6 and inventory.floor_plan.seats.size() == 9,
		"Reserve has six slots and the board stays 3x3.")
	var first := inventory.add_item("AUG_001")
	var second := inventory.add_item("AUG_001")
	_check(first["uid"] != second["uid"] and inventory.item_count() == 2,
		"Identical augments occupy separate slots with unique instance ids.")
	_check(inventory.move_item(0, 5) and inventory.item_slots[5]["uid"] == first["uid"] and inventory.item_slots[0].is_empty(),
		"Dragging to an empty slot moves the item.")
	_check(inventory.move_item(1, 5) and inventory.item_slots[1]["uid"] == first["uid"] and inventory.item_slots[5]["uid"] == second["uid"],
		"Dragging to an occupied slot swaps items.")
	var before := inventory.to_dict()
	_check(not inventory.move_item(0, 1) and not inventory.move_item(1, 1) and not inventory.move_item(1, 99)
		and inventory.to_dict() == before, "Invalid item moves must leave state unchanged.")
	_check(manager.equip_slot("nina", 1) and inventory.equipped_instances("nina")[0]["uid"] == first["uid"]
		and inventory.item_slots[1].is_empty(), "Equipping moves the same instance out of the grid.")
	_check(not manager.equip_slot("nina", 1) and not manager.equip_slot("nina", 5),
		"An empty slot cannot be equipped, and a full loadout rejects equipment.")
	while not inventory.is_item_full():
		inventory.add_item("AUG_001")
	_check(not manager.unequip("nina", 0) and inventory.equipped_instances("nina").size() == 1,
		"Unequipping is blocked while the item inventory is full.")
	inventory.item_slots[7] = {}
	_check(manager.unequip("nina", 0) and inventory.item_slots[7]["uid"] == first["uid"],
		"Unequipping returns the same instance to the grid.")
	_check(inventory.add_item("AUG_001").is_empty(), "A full grid refuses new items.")
	manager.budget = 500
	manager.shop_offers[0] = "AUG_001"
	_check(not manager.purchase(0) and manager.budget == 500, "A full inventory blocks purchase without charging.")


func _test_people() -> void:
	var manager := AugmentManager.new()
	var inventory := manager.bag
	_check(inventory.owned_count() == 3 and inventory.person_slots.count("") == 6, "The player starts with three salespeople on the board.")
	_check(not manager.hire("nina") and manager.budget == 500, "Owned salespeople cannot be hired twice.")
	_check(manager.hire("dex") and manager.budget == 400 and inventory.person_slots[0] == "dex"
		and not inventory.floor_plan.seats.has("dex"), "Hires enter reserve, are charged, and never auto-deploy.")
	_check(not manager.hire("missing") and manager.budget == 400, "Unknown hires fail without charging.")
	manager.budget = 1000
	for id in ["victoria", "echo", "rook", "marcus", "brick"]:
		manager.hire(id)
	var budget_before := manager.budget
	_check(inventory.is_reserve_full() and not manager.hire("zero") and manager.budget == budget_before,
		"A full reserve blocks hiring without charging.")
	var ids := _all_person_ids(inventory)
	_check(inventory.move_person("reserve", 0, "board", 3) and inventory.floor_plan.seats[3] == "dex" and inventory.person_slots[0].is_empty(),
		"Reserve to empty board seat moves the salesperson.")
	_check(inventory.move_person("reserve", 1, "board", 3) and inventory.person_slots[1] == "dex" and inventory.floor_plan.seats[3] != "dex",
		"Reserve to occupied seat swaps without losing either person.")
	_check(inventory.move_person("board", 0, "board", 8) and inventory.floor_plan.seats[8] == "nina" and inventory.floor_plan.seats[0].is_empty(),
		"Board to board moves into an empty seat.")
	_check(inventory.move_person("board", 8, "board", 1) and inventory.floor_plan.seats[8] == "zip",
		"Board to occupied board seat swaps.")
	_check(inventory.recall(8) and not inventory.floor_plan.seats.has("zip") and inventory.person_slots.has("zip"),
		"Recall returns a seated salesperson to reserve.")
	var snapshot := inventory.to_dict()
	_check(not inventory.move_person("board", 5, "reserve", 0) and not inventory.move_person("reserve", 0, "reserve", 0)
		and not inventory.move_person("board", 99, "board", 0) and not inventory.move_person("bogus", 0, "board", 0)
		and inventory.to_dict() == snapshot, "Invalid moves leave everything unchanged.")
	var after_ids := _all_person_ids(inventory)
	after_ids.sort()
	ids.sort()
	_check(after_ids == ids, "No salesperson is duplicated or lost across transfers.")


func _test_equipment_follows_people() -> void:
	var manager := AugmentManager.new()
	var inventory := manager.bag
	manager.hire("dex")
	inventory.add_item("AUG_001")
	_check(manager.equip_slot("dex", 0) and manager.loadout("dex") == ["AUG_001"],
		"Augments can equip to a salesperson in reserve.")
	inventory.move_person("reserve", 0, "board", 5)
	_check(manager.loadout("dex") == ["AUG_001"] and manager.equipment["dex"] == ["AUG_001"],
		"Equipped augments stay attached when a salesperson moves to the board.")
	_check(not manager.equip_slot("zebra", 0), "Unknown salespeople cannot be equipped.")


func _test_persistence() -> void:
	var manager := AugmentManager.new()
	manager.hire("dex")
	manager.bag.add_item("AUG_001")
	manager.bag.add_item("AUG_001")
	manager.equip_slot("dex", 0)
	var saved := manager.bag.to_dict()
	var restored := InventoryManager.new()
	_check(restored.load_dict(saved) and restored.to_dict() == saved, "Inventory state must round-trip.")
	var corrupt := saved.duplicate(true)
	corrupt["reserve"][1] = "nina"
	_check(not InventoryManager.new().load_dict(corrupt), "A duplicated salesperson must be rejected on load.")
	var item := restored.add_item("AUG_001")
	_check(item["uid"] != saved["items"][1]["uid"], "Restored inventories must not reuse instance ids.")


func _test_scene() -> void:
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	var panel: InventoryPanel = scene.inventory_panel
	_check(not panel.visible and scene.items_button != null and scene.people_button != null,
		"Inventory is hidden until a button opens it.")
	scene._toggle_inventory(true)
	_check(panel.visible and panel.items_open() and not panel.people_open() and panel.item_cells.size() == 12,
		"The Items button must open the 12-slot item grid.")
	scene._toggle_inventory(false)
	_check(panel.people_open() and panel.person_cells.size() == 6, "The Salespeople button must open the six-slot reserve.")
	scene.augment_manager.budget = 1000
	scene._hire_employee("dex")
	scene._purchase_augment(0)
	_check(scene.inventory.person_slots[0] == "dex" and scene.inventory.item_count() == 1
		and panel.person_cells[0].drag_data["type"] == "person" and panel.item_cells[0].drag_data["type"] == "item",
		"Shop and hiring results must appear in the inventory views.")
	var item_drag: Dictionary = panel.item_cells[0].drag_data
	var person_drag: Dictionary = panel.person_cells[0].drag_data
	_check(scene._can_transfer(item_drag, "reserve", 0) and not scene._can_transfer(item_drag, "reserve", 3)
		and scene._can_transfer(item_drag, "board", 0) and not scene._can_transfer(item_drag, "board", 5),
		"Item drops are valid only on salespeople with a free augment slot.")
	scene._on_transfer_requested(item_drag, "reserve", 0)
	_check(scene.inventory.item_count() == 0 and scene.augment_manager.loadout("dex").size() == 1,
		"Dropping an item on a reserve salesperson equips it.")
	scene._on_transfer_requested(person_drag, "board", 4)
	_check(scene.floor_plan.seats[4] == "dex" and scene.employee_cards[4].employee_id == "dex"
		and scene.augment_manager.loadout("dex").size() == 1 and scene.staffed_seats.has(4),
		"Dropping a reserve salesperson on the board deploys them with their augment.")
	scene._on_transfer_requested({"type": "person", "kind": "board", "index": 4}, "reserve", 2)
	_check(scene.inventory.person_slots[2] == "dex" and not scene.floor_plan.seats.has("dex"),
		"Dragging a board salesperson to reserve recalls them.")
	scene._start_day()
	var locked := scene.inventory.to_dict()
	_check(not scene._can_transfer({"type": "person", "kind": "reserve", "index": 2}, "board", 4),
		"Inventory moves are rejected during Play.")
	scene._on_transfer_requested({"type": "person", "kind": "reserve", "index": 2}, "board", 4)
	scene._hire_employee("echo")
	_check(scene.inventory.to_dict() == locked and not panel.person_cells[2].editable,
		"Play must lock roster, hiring, and inventory changes.")
	scene.day_timer.stop()
	scene._finish_day()
	scene._prepare_next_day()
	await process_frame
	_check(scene.inventory.to_dict() == locked, "Inventory and board persist into the next workday.")
	scene.queue_free()
	await process_frame


func _run() -> void:
	_test_items()
	_test_people()
	_test_equipment_follows_people()
	_test_persistence()
	await _test_scene()
	if failures.is_empty():
		print("PASS: inventory slots, drag transfers, equipment, hiring, shop limits, persistence, and phase locks.")
	quit(0 if failures.is_empty() else 1)
