extends RefCounted
class_name AugmentManager

const CATALOG: AugmentCatalog = preload("res://data/augment_catalog.tres")
const EMPLOYEES: EmployeeRoster = preload("res://data/planning_roster.tres")
const SURGERY_COST := 300
const STARTING_BUDGET := 500
const SHOP_SIZE := 3

var budget := STARTING_BUDGET
var inventory: Array[String] = []
var equipment: Dictionary = {}
var second_slot_unlocked: Dictionary = {}
var shop_offers: Array[String] = []
var purchased_offer_indexes: Array[int] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
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
	if budget < int(augment["price"]):
		return false
	budget -= int(augment["price"])
	inventory.append(augment_id)
	purchased_offer_indexes.append(offer_index)
	return true


func equip(employee_id: String, inventory_index: int) -> bool:
	if EMPLOYEES.profile(employee_id).is_empty() or inventory_index < 0 or inventory_index >= inventory.size():
		return false
	var loadout: Array[String] = []
	loadout.assign(equipment.get(employee_id, []))
	var slot_limit := 2 if second_slot_unlocked.get(employee_id, false) else 1
	if loadout.size() >= slot_limit:
		return false
	loadout.append(inventory[inventory_index])
	equipment[employee_id] = loadout
	inventory.remove_at(inventory_index)
	return true


func unequip(employee_id: String, slot_index: int) -> bool:
	if not equipment.has(employee_id):
		return false
	var loadout: Array[String] = equipment[employee_id]
	if slot_index < 0 or slot_index >= loadout.size():
		return false
	inventory.append(loadout[slot_index])
	loadout.remove_at(slot_index)
	if loadout.is_empty():
		equipment.erase(employee_id)
	return true


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
	result.assign(equipment.get(employee_id, []))
	return result
