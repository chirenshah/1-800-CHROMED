extends RefCounted
class_name AugmentManager

const CATALOG: AugmentCatalog = preload("res://data/augment_catalog.tres")
const EMPLOYEES: EmployeeRoster = preload("res://data/planning_roster.tres")
const EFFECT_ENGINE = preload("res://scripts/augment_effect_engine.gd")
const SURGERY_COST := 300
const STARTING_BUDGET := 500
const STANDARD_STORE_SLOTS := 4
const PREMIUM_STORE_SLOT := 4
const EMPLOYEE_STORE_START := 5
const EMPLOYEE_STORE_SLOTS := 2
const STORE_SLOT_COUNT := 7

const HIRE_COST := 100
const DAILY_REWARD_OFFER_COUNT := 3
const DAILY_REWARD_PICK_COUNT := 1

## Shared available cash: purchases, hiring, surgery, sales and payroll use this balance.
var _budget := STARTING_BUDGET
var financial_ledger: FinancialLedger
var budget: int:
	get:
		return financial_ledger.company_cash if financial_ledger != null else _budget
	set(value):
		_budget = maxi(value, 0)
		if financial_ledger != null:
			financial_ledger.company_cash = _budget
var bag: InventoryManager
var second_slot_unlocked: Dictionary = {}
var store_offers: Array[Dictionary] = []
var store_day := 0
var store_revision := 0
var pending_reward: Dictionary = {}
var reward_offer_count := DAILY_REWARD_OFFER_COUNT
var reward_pick_count := DAILY_REWARD_PICK_COUNT
var _rng := RandomNumberGenerator.new()

## Augment ids currently stored in the item inventory, in slot order.
var inventory: Array[String]:
	get:
		return bag.item_augment_ids()

## Equipped augment ids per employee, as consumed by the call simulation.
var equipment: Dictionary:
	get:
		return bag.equipped_augment_ids()


var equipment_instances: Dictionary:
	get:
		return bag.equipment.duplicate(true)


func _init(inventory_manager: InventoryManager = null) -> void:
	bag = inventory_manager if inventory_manager != null else InventoryManager.new()
	_rng.randomize()
	initialize_store_for_day(1)


func bind_financial_ledger(ledger: FinancialLedger) -> void:
	financial_ledger = ledger
	financial_ledger.company_cash = _budget


func employee_profile(employee_id: String) -> Dictionary:
	return EMPLOYEES.profile(employee_id)


func daily_upkeep(employee_id: String) -> int:
	return EMPLOYEES.daily_upkeep(employee_id)


func _spend_cash(amount: int, source_type: String, source_id: String) -> bool:
	var cost := maxi(amount, 0)
	if budget < cost:
		return false
	if financial_ledger == null:
		_budget -= cost
		return true
	return financial_ledger.spend_cash(cost, source_type, source_id)


func initialize_store_for_day(day: int) -> bool:
	assert(day > 0, "Store day must be positive.")
	if store_day == day and store_offers.size() == STORE_SLOT_COUNT:
		return false
	store_offers = _generate_store_offers()
	store_day = day
	store_revision += 1
	return true


func reroll_store() -> bool:
	var cost := maxi(CATALOG.store_reroll_cost, 0)
	if store_day <= 0 or store_offers.size() != STORE_SLOT_COUNT or budget < cost:
		return false
	if not _spend_cash(cost, "store_reroll", str(store_day)):
		return false
	store_offers = _generate_store_offers()
	store_revision += 1
	return true


func store_offer(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= store_offers.size():
		return {}
	return store_offers[slot_index].duplicate(true)


func purchase_store_augment(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= EMPLOYEE_STORE_START or slot_index >= store_offers.size():
		return false
	var offer := store_offers[slot_index]
	if offer.get("kind", "") != "augment" or offer.get("status", "") != "available":
		return false
	var augment_id := str(offer.get("augment_id", ""))
	var augment := CATALOG.profile(augment_id)
	if augment.is_empty() or not augment.get("available_in_shop", true):
		return false
	var price := maxi(int(augment.get("price", 0)), 0)
	if budget < price or bag.is_item_full():
		return false
	var item := bag.add_item(augment_id)
	if item.is_empty():
		return false
	assert(_spend_cash(price, "augment_purchase", augment_id))
	_mark_store_offer_sold(slot_index)
	return true


func hire_store_employee(slot_index: int) -> bool:
	if slot_index < EMPLOYEE_STORE_START or slot_index >= STORE_SLOT_COUNT \
		or slot_index >= store_offers.size():
		return false
	var offer := store_offers[slot_index]
	if offer.get("kind", "") != "employee" or offer.get("status", "") != "available":
		return false
	var employee_id := str(offer.get("employee_id", ""))
	if not hire(employee_id):
		return false
	_mark_store_offer_sold(slot_index)
	return true


func _generate_store_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var available_augments: Array[String] = []
	for augment: Dictionary in CATALOG.augments:
		var augment_id := str(augment.get("id", ""))
		if augment.get("available_in_shop", true) and not augment_id.is_empty():
			available_augments.append(augment_id)
	available_augments.sort()
	for slot_index in STANDARD_STORE_SLOTS:
		offers.append(_draw_store_augment(
			"standard", CATALOG.standard_store_rarity_weights, available_augments
		))
	offers.append(_draw_store_augment(
		"premium", CATALOG.premium_store_rarity_weights, available_augments
	))

	var eligible_employees: Array[String] = []
	for employee: Dictionary in EMPLOYEES.employees:
		var employee_id := str(employee.get("id", ""))
		if not employee_id.is_empty() and not bag.owns(employee_id) \
			and not bag.fired_employee_ids.has(employee_id):
			eligible_employees.append(employee_id)
	eligible_employees.sort()
	for _slot_index in EMPLOYEE_STORE_SLOTS:
		if eligible_employees.is_empty():
			offers.append({"kind": "employee", "status": "sold_out", "employee_id": ""})
			continue
		var selected_index := _rng.randi_range(0, eligible_employees.size() - 1)
		var employee_id := eligible_employees[selected_index]
		eligible_employees.remove_at(selected_index)
		offers.append({
			"kind": "employee",
			"status": "available",
			"employee_id": employee_id,
		})
	assert(offers.size() == STORE_SLOT_COUNT, "Store generation must create exactly seven slots.")
	return offers


func _draw_store_augment(
		tier: String,
		weights: Dictionary,
		available_augments: Array[String]
	) -> Dictionary:
	var allowed_rarities: Array[String] = []
	if tier == "standard":
		allowed_rarities.append("Common")
		allowed_rarities.append("Uncommon")
		allowed_rarities.append("Rare")
	else:
		allowed_rarities.append("Epic")
		allowed_rarities.append("Legendary")
	var tier_weights := {}
	for rarity in allowed_rarities:
		if weights.has(rarity):
			tier_weights[rarity] = weights[rarity]
	var rarity := _draw_weighted_rarity(tier_weights)
	var candidates := _augments_of_rarity(rarity, available_augments)
	if candidates.is_empty():
		var fallback_weights := {}
		for configured_rarity: Variant in tier_weights:
			var rarity_name := str(configured_rarity)
			if int(tier_weights[configured_rarity]) > 0 \
				and not _augments_of_rarity(rarity_name, available_augments).is_empty():
				fallback_weights[rarity_name] = int(tier_weights[configured_rarity])
		rarity = _draw_weighted_rarity(fallback_weights)
		candidates = _augments_of_rarity(rarity, available_augments)
	if candidates.is_empty():
		return {"kind": "augment", "tier": tier, "status": "sold_out", "rarity": rarity}
	var selected := candidates[_rng.randi_range(0, candidates.size() - 1)]
	available_augments.erase(selected)
	return {
		"kind": "augment",
		"tier": tier,
		"status": "available",
		"rarity": rarity,
		"augment_id": selected,
	}


func _draw_weighted_rarity(weights: Dictionary) -> String:
	var rarities: Array[String] = []
	var total_weight := 0
	for rarity: Variant in weights:
		var weight := maxi(int(weights[rarity]), 0)
		if weight > 0:
			rarities.append(str(rarity))
			total_weight += weight
	rarities.sort()
	if total_weight <= 0:
		return ""
	var roll := _rng.randi_range(1, total_weight)
	for rarity in rarities:
		roll -= maxi(int(weights[rarity]), 0)
		if roll <= 0:
			return rarity
	return ""


func _augments_of_rarity(rarity: String, available_augments: Array[String]) -> Array[String]:
	var candidates: Array[String] = []
	if rarity.is_empty():
		return candidates
	for augment_id in available_augments:
		if str(CATALOG.profile(augment_id).get("rarity", "")) == rarity:
			candidates.append(augment_id)
	return candidates


func _mark_store_offer_sold(slot_index: int) -> void:
	var offer := store_offers[slot_index].duplicate(true)
	offer["status"] = "sold"
	store_offers[slot_index] = offer


func purchase(offer_index: int) -> bool:
	return purchase_store_augment(offer_index)


func generate_daily_reward() -> Dictionary:
	if not pending_reward.is_empty():
		return pending_reward.duplicate(true)
	var available: Array[String] = []
	for augment: Dictionary in CATALOG.augments:
		available.append(str(augment["id"]))
	var choices: Array[String] = []
	for _choice in reward_offer_count:
		var selected := _draw_augment(available)
		if selected.is_empty():
			break
		choices.append(selected)
		available.erase(selected)
	pending_reward = {
		"choices": choices,
		"selected_index": 0,
		"picks_allowed": reward_pick_count,
	}
	return pending_reward.duplicate(true)


func select_reward_option(index: int) -> bool:
	var choices: Array = pending_reward.get("choices", [])
	if pending_reward.is_empty() or index < 0 or index >= choices.size():
		return false
	pending_reward["selected_index"] = index
	return true


func claim_reward_to_inventory(index: int) -> bool:
	if not select_reward_option(index):
		return false
	var augment_id: String = pending_reward["choices"][index]
	if bag.add_item(augment_id).is_empty():
		return false
	pending_reward.clear()
	return true


func install_reward(index: int, employee_id: String, slot_index: int) -> bool:
	if not select_reward_option(index) or not bag.owns(employee_id):
		return false
	if not bag.install_augment(employee_id, str(pending_reward["choices"][index]), slot_index, slot_limit(employee_id)):
		return false
	pending_reward.clear()
	return true


func skip_daily_reward() -> bool:
	if pending_reward.is_empty():
		return false
	pending_reward.clear()
	return true


func discard_item(item_slot: int) -> bool:
	return not bag.discard_item(item_slot).is_empty()


## Hires into the salesperson reserve. Fails without charging when unaffordable or full.
func hire(employee_id: String) -> bool:
	if budget < HIRE_COST or not bag.hire(employee_id):
		return false
	assert(_spend_cash(HIRE_COST, "employee_hire", employee_id))
	for slot_index in range(EMPLOYEE_STORE_START, store_offers.size()):
		if store_offers[slot_index].get("employee_id", "") == employee_id \
			and store_offers[slot_index].get("status", "") == "available":
			_mark_store_offer_sold(slot_index)
	return true


## Equips the nth stored item (gaps ignored); kept for list-style callers.
func equip(employee_id: String, inventory_index: int) -> bool:
	return equip_slot(employee_id, bag.slot_of_nth_item(inventory_index))


func equip_slot(employee_id: String, item_slot: int) -> bool:
	if EMPLOYEES.profile(employee_id).is_empty():
		return false
	return bag.equip_item(employee_id, item_slot, slot_limit(employee_id))


func replace_slot_from_inventory(employee_id: String, equip_index: int, item_slot: int) -> bool:
	if EMPLOYEES.profile(employee_id).is_empty():
		return false
	return bag.replace_item(employee_id, equip_index, item_slot)


func unequip(_employee_id: String, _slot_index: int) -> bool:
	return false


func unlock_second_slot(employee_id: String) -> bool:
	if EMPLOYEES.profile(employee_id).is_empty() or second_slot_unlocked.get(employee_id, false) or budget < SURGERY_COST:
		return false
	assert(_spend_cash(SURGERY_COST, "augment_surgery", employee_id))
	second_slot_unlocked[employee_id] = true
	return true


func slot_limit(employee_id: String) -> int:
	return 2 if second_slot_unlocked.get(employee_id, false) else 1


func loadout(employee_id: String) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in bag.equipped_instances(employee_id):
		result.append(item["augment_id"])
	return result


func modified_stats(employee_id: String) -> Dictionary:
	return modified_floor_stats().get(employee_id, {})


func modified_floor_stats() -> Dictionary:
	var loadouts: Dictionary = bag.equipment.duplicate(true)
	var positions := {}
	for seat in bag.floor_plan.seats.size():
		var seated_id: String = bag.floor_plan.seats[seat]
		if not seated_id.is_empty():
			positions[seated_id] = seat
	for seated_id in bag.person_slots:
		if not seated_id.is_empty():
			positions[seated_id] = -1
	for employee: Dictionary in EMPLOYEES.employees:
		var employee_id: String = employee.get("id", "")
		if not positions.has(employee_id):
			positions[employee_id] = -1
		if not loadouts.has(employee_id):
			loadouts[employee_id] = []
	var engine = EFFECT_ENGINE.new()
	return engine.resolve_floor_stats(
		EMPLOYEES, loadouts, positions, {}, [], {"company_cash": budget}
	)


func _draw_augment(available: Array[String]) -> String:
	var eligible_by_rarity := {}
	var total_weight := 0
	for augment_id in available:
		var augment := CATALOG.profile(augment_id)
		var rarity: String = augment.get("rarity", "Common")
		var weight := maxi(0, int(CATALOG.rarity_weights.get(rarity, 0)))
		if weight == 0:
			continue
		if not eligible_by_rarity.has(rarity):
			eligible_by_rarity[rarity] = []
		eligible_by_rarity[rarity].append(augment_id)
	for rarity: String in eligible_by_rarity:
		total_weight += int(CATALOG.rarity_weights[rarity])
	if total_weight == 0:
		return ""
	var roll := _rng.randi_range(1, total_weight)
	for rarity: String in eligible_by_rarity:
		roll -= int(CATALOG.rarity_weights[rarity])
		if roll <= 0:
			var candidates: Array = eligible_by_rarity[rarity]
			return str(candidates[_rng.randi_range(0, candidates.size() - 1)])
	return ""


func state_to_dict() -> Dictionary:
	return {
		"budget": budget,
		"second_slot_unlocked": second_slot_unlocked.duplicate(true),
		"store_day": store_day,
		"store_revision": store_revision,
		"store_offers": store_offers.duplicate(true),
		"store_rng_state": _rng.state,
		"pending_reward": pending_reward.duplicate(true),
	}


func load_state_dict(data: Dictionary) -> bool:
	var offers: Array = data.get("store_offers", [])
	var reward: Dictionary = data.get("pending_reward", {})
	var reward_choices: Array = reward.get("choices", [])
	if not offers.is_empty() and offers.size() != STORE_SLOT_COUNT:
		return false
	for slot_index in offers.size():
		var offer: Variant = offers[slot_index]
		if not offer is Dictionary:
			return false
		var kind := str(offer.get("kind", ""))
		var status := str(offer.get("status", ""))
		if status not in ["available", "sold", "sold_out"]:
			return false
		if slot_index < EMPLOYEE_STORE_START:
			if kind != "augment":
				return false
			var expected_tier := "standard" if slot_index < STANDARD_STORE_SLOTS else "premium"
			var allowed_rarities: Array[String] = []
			allowed_rarities.assign(["Common", "Uncommon", "Rare"] \
				if expected_tier == "standard" else ["Epic", "Legendary"])
			if str(offer.get("tier", "")) != expected_tier:
				return false
			var augment_id := str(offer.get("augment_id", ""))
			if status != "sold_out":
				var augment := CATALOG.profile(augment_id)
				if augment.is_empty() or not augment.get("available_in_shop", true) \
					or str(augment.get("rarity", "")) not in allowed_rarities \
					or str(augment.get("rarity", "")) != str(offer.get("rarity", "")):
					return false
		else:
			if kind != "employee":
				return false
			var employee_id := str(offer.get("employee_id", ""))
			if status != "sold_out" and EMPLOYEES.profile(employee_id).is_empty():
				return false
	for augment_id: String in reward_choices:
		if CATALOG.profile(augment_id).is_empty():
			return false
	if reward_choices.size() > reward_offer_count \
		or int(reward.get("selected_index", 0)) < 0 \
		or (not reward_choices.is_empty() and int(reward.get("selected_index", 0)) >= reward_choices.size()):
		return false
	var unique_choices := {}
	for augment_id: String in reward_choices:
		if unique_choices.has(augment_id):
			return false
		unique_choices[augment_id] = true
	budget = int(data.get("budget", STARTING_BUDGET))
	second_slot_unlocked = data.get("second_slot_unlocked", {}).duplicate(true)
	if offers.is_empty():
		store_offers.clear()
		store_day = 0
		initialize_store_for_day(maxi(int(data.get("store_day", 1)), 1))
	else:
		store_offers.assign(offers)
		store_day = maxi(int(data.get("store_day", 1)), 1)
	store_revision = maxi(int(data.get("store_revision", store_revision)), 1)
	_rng.state = int(data.get("store_rng_state", _rng.state))
	pending_reward = reward.duplicate(true)
	return true
