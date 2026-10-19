extends SceneTree
## Godot --headless --path . --script res://tests/test_augments.gd

const MANAGER := preload("res://scripts/augment_manager.gd")
const ROSTER := preload("res://scripts/employee_roster.gd")
const BASE_ROSTER: EmployeeRoster = preload("res://data/planning_roster.tres")
const MODEL := preload("res://scripts/call_queue_simulation.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	_test_manager()
	_test_simulation()
	_test_recycler_augments()
	await _test_workday_integration()
	if failures.is_empty():
		print("PASS: augment shop, budget, inventory, equipment slots, surgery, effective stats, and Prepare/Play persistence.")
	quit(0 if failures.is_empty() else 1)


func _test_manager() -> void:
	var manager := MANAGER.new()
	_check(MANAGER.CATALOG.augments.size() == 6 and manager.shop_offers.size() == 3,
		"The shop must offer three choices from the six data-defined augments.")
	_check(manager.shop_offers[0] != manager.shop_offers[1]
		and manager.shop_offers[0] != manager.shop_offers[2]
		and manager.shop_offers[1] != manager.shop_offers[2],
		"Offers within a shop refresh must be distinct.")
	manager.budget = 500
	manager.shop_offers = ["AUG_001", "AUG_002", "AUG_003"]
	_check(manager.purchase(0) and manager.budget == 400 and manager.inventory == ["AUG_001"],
		"Purchasing must deduct the fixed price and add the augment to inventory.")
	_check(not manager.purchase(0) and not manager.purchase(99),
		"An offer can only be purchased once, and invalid offer indexes are rejected.")
	manager.budget = 0
	_check(not manager.purchase(1) and manager.inventory == ["AUG_001"],
		"Purchases that exceed the available budget must fail without changing inventory.")
	manager.budget = 400
	_check(manager.equip("nina", 0) and manager.inventory.is_empty(),
		"An augment can be equipped into a character's first slot.")
	var loadout := manager.loadout("nina")
	_check(manager.slot_limit("nina") == 1 and loadout == ["AUG_001"],
		"Every character starts with exactly one augment slot.")
	_check(is_equal_approx(BASE_ROSTER.conversion_chance_with_augments("nina", loadout), 0.68),
		"Conversion augments add percentage points to the authored base stat.")
	_check(manager.unequip("nina", 0) and manager.inventory == ["AUG_001"]
		and is_equal_approx(BASE_ROSTER.conversion_chance("nina"), 0.58),
		"Unequipping restores the base stat and returns the item to inventory.")
	_check(manager.equip("zip", 0) and manager.loadout("zip") == ["AUG_001"],
		"Unequipped augments can be transferred to another character.")

	manager.budget = 500
	manager.shop_offers = ["AUG_001", "AUG_002", "AUG_003"]
	manager.purchased_offer_indexes.clear()
	_check(manager.purchase(1) and manager.purchase(2), "Speed and conversion augments should be purchasable.")
	_check(manager.equip("nina", 0), "An available inventory item should equip successfully.")
	var speed_loadout := manager.loadout("nina")
	_check(is_equal_approx(BASE_ROSTER.handling_seconds_with_augments("nina", speed_loadout), 18.0 / 4.0 / 1.15),
		"Speed augments must reduce call duration using the existing handling formula.")
	_check(not manager.unlock_second_slot("nina") and manager.slot_limit("nina") == 1,
		"Surgery must not be purchasable without its full $300 cost.")
	manager.budget = 500
	_check(manager.unlock_second_slot("nina") and manager.budget == 200
		and manager.slot_limit("nina") == 2,
		"Surgery must permanently unlock exactly one additional slot for $300.")
	_check(manager.equip("nina", 0) and manager.loadout("nina").size() == 2,
		"An upgraded character can equip a second augment.")
	_check(is_equal_approx(BASE_ROSTER.handling_seconds_with_augments("nina", manager.loadout("nina")),
		18.0 / 4.0 / 1.15),
		"Conversion and Speed bonuses affect only their respective stats.")
	var stacked_speed: Array[String] = ["AUG_002", "AUG_002"]
	_check(is_equal_approx(BASE_ROSTER.handling_seconds_with_augments("nina", stacked_speed),
		18.0 / 4.0 / 1.30),
		"Multiple Speed bonuses must add together before modifying handling time.")
	var clamped_conversion: Array[String] = ["AUG_005"]
	_check(is_equal_approx(BASE_ROSTER.conversion_chance_with_augments("victoria", clamped_conversion), 1.0),
		"Conversion bonuses must clamp at 100 percent.")
	_check(not manager.equip("nina", 0), "A full augment loadout must reject further equipment.")


func _test_simulation() -> void:
	var data := ROSTER.new()
	data.employees.append({"id": "seller", "speed": 5, "conversion": 95})
	var model := MODEL.new()
	model.roster = data
	var loadout: Array[String] = ["AUG_002", "AUG_005"]
	model.reset(["seller"], 17, {"seller": loadout})
	model.next_arrival_seconds = INF
	model.receive_call()
	var duration := data.handling_seconds_with_augments("seller", loadout)
	_check(is_equal_approx(float(model.active[0]["duration"]), duration / MODEL.TICK_SECONDS),
		"Equipped Speed must affect the live call-duration calculation.")
	model.advance(duration)
	_check(model.sales == 1 and model.revenue == 195,
		"Equipped Conversion must affect automated sale outcomes without changing payout by itself.")
	model.reset(["seller"], 17)
	model.next_arrival_seconds = INF
	model.receive_call()
	_check(is_equal_approx(float(model.active[0]["duration"]),
		data.handling_seconds("seller") / MODEL.TICK_SECONDS),
		"Resetting without a loadout must preserve base behavior.")


func _test_recycler_augments() -> void:
	var data := ROSTER.new()
	data.employees.append({"id": "seller", "archetype": "Hustler", "speed": 5, "conversion": 0})
	data.employees.append({"id": "scrap", "archetype": "Recycler", "speed": 5, "conversion": 100})
	var loadout: Array[String] = ["AUG_002", "AUG_005"]
	var model := MODEL.new()
	model.roster = data
	model.reset(["seller", "scrap"], 18, {"scrap": loadout})
	model.next_arrival_seconds = INF
	model.receive_call()
	model.advance(data.handling_seconds("seller"))
	_check(model.active.has(1) and model.active[1].get("recovery", false)
		and is_equal_approx(float(model.active[1]["duration"]),
			data.handling_seconds_with_augments("scrap", loadout) / MODEL.TICK_SECONDS),
		"Recycler handling must use the equipped Speed augment.")
	model.advance(data.handling_seconds_with_augments("scrap", loadout))
	_check(model.recovered == 1 and model.sales == 1,
		"Recycler conversion must use the normal augmented employee stat path.")


func _test_workday_integration() -> void:
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var panel: PlanningPanel = scene.planning_panel
	_check(scene.augment_manager.budget == 500 and scene.augment_manager.shop_offers.size() == 3
		and panel.offer_buttons.size() == 3,
		"Prepare must display the initial budget and three shop offers.")
	scene.augment_manager.shop_offers = ["AUG_001", "AUG_002", "AUG_003"]
	panel.update_augment_state(scene.augment_manager, true)
	_check(panel.offer_buttons[0].text.contains("Silver Tongue")
		and panel.offer_buttons[0].text.contains("Common")
		and panel.offer_buttons[0].text.contains("+10 pp Conversion")
		and panel.offer_buttons[0].text.contains("$100"),
		"Each offer must display its name, rarity, stat bonus, and price.")
	scene._purchase_augment(0)
	scene._equip_augment("nina", 0)
	_check(scene.augment_manager.budget == 400 and scene.augment_manager.loadout("nina") == ["AUG_001"],
		"Prepare controls must purchase and equip augments on the selected employee.")
	scene._start_day()
	_check(scene.call_queue.equipped_augments["nina"] == ["AUG_001"],
		"Starting Play must snapshot the equipped augment loadouts.")
	var unchanged_budget := scene.augment_manager.budget
	var unchanged_inventory := scene.augment_manager.inventory.duplicate()
	scene._purchase_augment(1)
	_check(scene.augment_manager.budget == unchanged_budget
		and scene.augment_manager.inventory == unchanged_inventory,
		"Augment changes must be rejected during Play.")
	scene.call_queue.revenue = 50
	scene._finish_day()
	_check(scene.augment_manager.budget == 450, "Workday revenue must be added to the department budget.")
	scene._prepare_next_day()
	_check(scene.augment_manager.loadout("nina") == ["AUG_001"]
		and scene.call_queue.equipped_augments.is_empty(),
		"Equipment persists into the next Prepare phase and is applied when that day starts.")
	scene._start_day()
	_check(scene.call_queue.equipped_augments["nina"] == ["AUG_001"],
		"Persisted augments must be reapplied automatically on the next workday.")
	scene.day_timer.stop()
	scene.queue_free()
	await process_frame
