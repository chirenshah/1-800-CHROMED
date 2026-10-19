extends RefCounted
class_name AugmentManager

const CATALOG: AugmentCatalog = preload("res://data/augment_catalog.tres")
const EMPLOYEES: EmployeeRoster = preload("res://data/planning_roster.tres")
const SURGERY_COST := 300
const STARTING_BUDGET := 500
const SHOP_SIZE := 3

const HIRE_COST := 100

var budget := STARTING_BUDGET
var bag: InventoryManager
var second_slot_unlocked: Dictionary = {}
var shop_offers: Array[String] = []
var purchased_offer_indexes: Array[int] = []
var _rng := RandomNumberGenerator.new()

## Augment ids currently stored in the item inventory, in slot order.
var inventory: Array[String]:
	get:
		return bag.item_augment_ids()

## Equipped augment ids per employee, as consumed by the call simulation.
var equipment: Dictionary:
	get:
		return bag.equipped_augment_ids()


func _init(inventory_manager: InventoryManager = null) -> void:
	bag = inventory_manager if inventory_manager != null else InventoryManager.new()
	_rng.randomize()
	refresh_shop()


func refresh_shop() -> void:
	var available: Array[String] = []
	for augment in CATALOG.augments:
		available.append(augment["id"])
	shop_offers.clear()
	purchased_offer_indexes.clear()
	for _offer_index in SHOP_SIZE:
		var selected := _rng.randi_range(0, available.size() - 1)
		shop_offers.append(available[selected])
		available.remove_at(selected)


func purchase(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= shop_offers.size() or purchased_offer_indexes.has(offer_index):
		return false
	var augment_id: String = shop_offers[offer_index]
	var augment := CATALOG.profile(augment_id)
	if augment.is_empty():
		return false
	if budget < int(augment["price"]) or bag.is_item_full():
		return false
	if bag.add_item(augment_id).is_empty():
		return false
	budget -= int(augment["price"])
	purchased_offer_indexes.append(offer_index)
	return true


## Hires into the salesperson reserve. Fails without charging when unaffordable or full.
func hire(employee_id: String) -> bool:
	if budget < HIRE_COST or not bag.hire(employee_id):
		return false
	budget -= HIRE_COST
	return true


## Equips the nth stored item (gaps ignored); kept for list-style callers.
func equip(employee_id: String, inventory_index: int) -> bool:
	return equip_slot(employee_id, bag.slot_of_nth_item(inventory_index))


func equip_slot(employee_id: String, item_slot: int) -> bool:
	if EMPLOYEES.profile(employee_id).is_empty():
		return false
	return bag.equip_item(employee_id, item_slot, slot_limit(employee_id))


func unequip(employee_id: String, slot_index: int) -> bool:
	return bag.unequip_item(employee_id, slot_index)


func unlock_second_slot(employee_id: String) -> bool:
	if EMPLOYEES.profile(employee_id).is_empty() or second_slot_unlocked.get(employee_id, false) or budget < SURGERY_COST:
		return false
	budget -= SURGERY_COST
	second_slot_unlocked[employee_id] = true
	return true


func slot_limit(employee_id: String) -> int:
	return 2 if second_slot_unlocked.get(employee_id, false) else 1


func loadout(employee_id: String) -> Array[String]:
	var result: Array[String] = []
	for item: Dictionary in bag.equipped_instances(employee_id):
		result.append(item["augment_id"])
	return result
