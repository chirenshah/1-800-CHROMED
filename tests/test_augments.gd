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
	_check(manager.store_offers.size() == MANAGER.STORE_SLOT_COUNT,
		"A new store contains four standard, one premium, and two recruitment slots.")
	var standard_ids: Array[String] = []
	for slot_index in MANAGER.STANDARD_STORE_SLOTS:
		var offer := manager.store_offer(slot_index)
		if offer.get("status", "") == "available":
			_check(str(offer.get("rarity", "")) in ["Common", "Uncommon", "Rare"],
				"Standard slots only use Common, Uncommon, or Rare augments.")
			_check(not standard_ids.has(str(offer.get("augment_id", ""))),
				"One store generation does not repeat an augment.")
			standard_ids.append(str(offer.get("augment_id", "")))
	var premium := manager.store_offer(MANAGER.PREMIUM_STORE_SLOT)
	if premium.get("status", "") == "available":
		_check(str(premium.get("rarity", "")) in ["Epic", "Legendary"],
			"The premium slot only uses Epic or Legendary augments.")
	var recruit_ids: Array[String] = []
	for slot_index in range(MANAGER.EMPLOYEE_STORE_START, MANAGER.STORE_SLOT_COUNT):
		var offer := manager.store_offer(slot_index)
		if offer.get("status", "") == "available":
			var employee_id := str(offer.get("employee_id", ""))
			_check(not recruit_ids.has(employee_id) and not manager.bag.owns(employee_id),
				"Recruitment candidates are distinct unhired unique employees.")
			recruit_ids.append(employee_id)
	_check(manager.hire("zip"), "Zip must be hired before transferring an augment to him.")
	manager.budget = 500
	manager.store_offers[0] = _augment_offer("AUG_001", "Common", "standard")
	manager.store_offers[1] = _augment_offer("AUG_002", "Common", "standard")
	manager.store_offers[2] = _augment_offer("AUG_003", "Rare", "standard")
	_check(manager.purchase(0) and manager.budget == 400 and manager.inventory == ["AUG_001"],
		"A store purchase deducts company cash once and adds the augment to item inventory.")
	_check(not manager.purchase(0) and not manager.purchase(99),
		"A sold store slot cannot be purchased twice, and invalid indexes are rejected.")
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
	_check(not manager.unequip("nina", 0) and manager.inventory.is_empty()
		and is_equal_approx(BASE_ROSTER.conversion_chance("nina"), 0.58),
		"Installed augments cannot be unequipped or transferred.")

	manager.budget = 500
	manager.store_offers[1] = _augment_offer("AUG_002", "Common", "standard")
	manager.store_offers[2] = _augment_offer("AUG_003", "Rare", "standard")
	_check(manager.purchase(1) and manager.purchase(2), "Speed and conversion augments should be purchasable.")
	var funds_before_replace := manager.budget
	_check(manager.replace_slot_from_inventory("nina", 0, 0)
		and manager.loadout("nina") == ["AUG_002"] and manager.budget == funds_before_replace,
		"Replacing during Prepare destroys the old augment without another fee.")
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
	_check(BASE_ROSTER.conversion_chance_with_augments("victoria", clamped_conversion) > 1.0,
		"Modified Conversion remains uncapped for dependent effects; only actual rolls clamp.")
	_check(not manager.equip("nina", 0), "A full augment loadout must reject further equipment.")

	manager.budget = 500
	var saved_store := manager.store_offers.duplicate(true)
	var saved_revision := manager.store_revision
	var saved_inventory := manager.bag.item_slots.duplicate(true)
	var saved_equipment := manager.equipment_instances.duplicate(true)
	var saved_employees := manager.bag.person_slots.duplicate()
	_check(not manager.initialize_store_for_day(manager.store_day)
		and manager.store_offers == saved_store,
		"Re-entering the same Prepare day does not regenerate stock.")
	for slot_index in manager.store_offers.size():
		var emptied_offer := manager.store_offer(slot_index)
		emptied_offer["status"] = "sold"
		manager.store_offers[slot_index] = emptied_offer
	var reroll_succeeded := manager.reroll_store()
	var all_slots_refilled := true
	for offer in manager.store_offers:
		if offer.get("status", "") != "available":
			all_slots_refilled = false
	_check(reroll_succeeded and manager.budget == 400
		and manager.store_revision == saved_revision + 1
		and manager.bag.item_slots == saved_inventory
		and manager.equipment_instances == saved_equipment
		and manager.bag.person_slots == saved_employees
		and all_slots_refilled,
		"Reroll charges once, replaces all seven offers, and preserves owned items, equipment, and hires.")
	manager.budget = 99
	var before_unaffordable_reroll := manager.store_offers.duplicate(true)
	_check(not manager.reroll_store() and manager.budget == 99
		and manager.store_offers == before_unaffordable_reroll,
		"An unaffordable reroll changes neither cash nor store contents.")
	var restored_manager := MANAGER.new()
	_check(restored_manager.load_state_dict(manager.state_to_dict())
		and restored_manager.store_offers == manager.store_offers
		and restored_manager.store_day == manager.store_day,
		"Serialized store offers and their sold states restore without rerolling.")

	var recruit_manager := MANAGER.new()
	recruit_manager.store_offers[MANAGER.EMPLOYEE_STORE_START] = {
		"kind": "employee", "status": "available", "employee_id": "zip",
	}
	_check(recruit_manager.hire_store_employee(MANAGER.EMPLOYEE_STORE_START)
		and recruit_manager.budget == 400
		and recruit_manager.bag.person_slots.has("zip")
		and recruit_manager.store_offer(MANAGER.EMPLOYEE_STORE_START).get("status", "") == "sold",
		"A Store hire charges once, enters reserve, and marks its offer sold.")
	_check(recruit_manager.reroll_store() and recruit_manager.budget == 300,
		"A reroll after hiring still costs the same fixed $100.")
	for employee_id in ["victoria", "ada", "dex", "marcus", "brick"]:
		_check(recruit_manager.bag.hire(employee_id),
			"Recruitment fixture should fill the existing reserve.")
	var hired_offer := recruit_manager.store_offer(MANAGER.EMPLOYEE_STORE_START)
	var hired_again := recruit_manager.store_offer(MANAGER.EMPLOYEE_STORE_START + 1)
	_check(hired_offer.get("employee_id", "") != "zip"
		and hired_again.get("employee_id", "") != "zip",
		"Previously hired employees remain excluded after rerolls.")
	recruit_manager.store_offers[MANAGER.EMPLOYEE_STORE_START] = {
		"kind": "employee", "status": "available", "employee_id": "mox",
	}
	var cash_before_full_reserve_hire := recruit_manager.budget
	_check(not recruit_manager.hire_store_employee(MANAGER.EMPLOYEE_STORE_START)
		and recruit_manager.budget == cash_before_full_reserve_hire,
		"A full reserve rejects Store hires without charging.")


func _augment_offer(augment_id: String, rarity: String, tier: String) -> Dictionary:
	return {
		"kind": "augment",
		"tier": tier,
		"status": "available",
		"rarity": rarity,
		"augment_id": augment_id,
	}


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
	scene.first_day_complete = true
	scene._select_prepare_view(scene.PrepareView.STORE)
	_check(scene.augment_manager.budget == 500 and scene.augment_manager.store_offers.size() == 7
		and scene.prepare_view == scene.PrepareView.STORE and scene.store_panel.visible
		and scene.store_panel.augment_buy_buttons.size() == 5
		and scene.store_panel.employee_hire_buttons.size() == 2,
		"Prepare opens the seven-slot Store with five augment cards and two recruitment cards.")
	scene.augment_manager.store_offers[0] = _augment_offer("AUG_001", "Common", "standard")
	scene._refresh_augment_views()
	_check(scene.store_panel.cash_label.text.contains("$500")
		and scene.store_panel.augment_buy_buttons[0].text == "BUY · $100",
		"Store cards show the current Company Cash and the augment's rarity-tier price.")
	scene._purchase_store_augment(0)
	scene._equip_augment("nina", 0)
	_check(scene.augment_manager.budget == 400 and scene.augment_manager.loadout("nina") == ["AUG_001"],
		"Purchases enter the shared inventory and can be installed using the existing equipment flow.")
	scene._set_commission_rate("nina", 30)
	scene._start_day()
	_check(scene.call_queue.equipped_augments["nina"] == ["AUG_001"]
		and scene.store_panel.reroll_button.disabled,
		"Starting Play snapshots equipment and disables Store rerolls outside Prepare.")
	var unchanged_budget: int = scene.augment_manager.budget
	var unchanged_inventory: Array = scene.augment_manager.inventory.duplicate()
	scene._purchase_store_augment(1)
	_check(scene.augment_manager.budget == unchanged_budget
		and scene.augment_manager.inventory == unchanged_inventory,
		"Augment changes must be rejected during Play.")
	scene.call_queue.revenue = 50
	scene.call_queue.sale_log.append({"id": 0, "value": 50, "employee_id": "nina", "recovery": false})
	scene._settle_sale({"employee_id": "nina", "value": 50, "timestamp": 1.0})
	scene._finish_day()
	_check(scene.augment_manager.budget == unchanged_budget + 50 - 100 - 15
		and scene.augment_manager.pending_reward.get("choices", []).size() == 3
		and scene.report_panel.next_day_button.disabled,
		"Workday revenue is added to cash once, then base salary and earned commission are settled.")
	scene._prepare_next_day()
	_check(scene.day == 1 and scene.phase == scene.Phase.REPORT and not scene.store_panel.visible,
		"The next day remains blocked until its reward is resolved.")
	scene._claim_reward(0)
	_check(scene.augment_manager.pending_reward.is_empty() and scene.inventory.item_count() == 1,
		"Claiming one daily reward resolves the offer and adds only that augment to inventory.")
	scene._prepare_next_day()
	_check(scene.prepare_view == scene.PrepareView.STORE and scene.store_panel.visible
		and scene.augment_manager.store_day == scene.day
		and scene.augment_manager.loadout("nina") == ["AUG_001"]
		and scene.call_queue.equipped_augments.is_empty(),
		"Next-day Prepare regenerates store stock once while equipment persists.")
	scene._start_day()
	_check(scene.call_queue.equipped_augments["nina"] == ["AUG_001"],
		"Persisted augments must be reapplied automatically on the next workday.")
	scene.day_timer.stop()
	scene.queue_free()
	await process_frame
