extends RefCounted
class_name InventoryManager
## Authoritative ownership of augment instances and salespeople.
## The board itself stays in FloorPlan; this class never touches UI nodes.

const ITEM_ROWS := 2
const ITEM_COLUMNS := 6
const ITEM_SLOTS := ITEM_ROWS * ITEM_COLUMNS
const PERSON_SLOTS := 6
const BOARD := "board"
const RESERVE := "reserve"

var floor_plan: FloorPlan
var item_slots: Array[Dictionary] = []
var person_slots: Array[String] = []
# Equipped instances per employee id, whether the employee is seated or in reserve.
var equipment: Dictionary = {}
var _next_item_number := 1


func _init(plan: FloorPlan = null) -> void:
	floor_plan = plan if plan != null else FloorPlan.new()
	for _slot in ITEM_SLOTS:
		item_slots.append({})
	for _slot in PERSON_SLOTS:
		person_slots.append("")


# --- Items -----------------------------------------------------------------

func item_count() -> int:
	return item_slots.size() - item_slots.count({})


func first_free_item_slot() -> int:
	return item_slots.find({})


func is_item_full() -> bool:
	return first_free_item_slot() == -1


func add_item(augment_id: String) -> Dictionary:
	var slot := first_free_item_slot()
	if slot == -1 or AugmentManager.CATALOG.profile(augment_id).is_empty():
		return {}
	var item := {"uid": "item_%04d" % _next_item_number, "augment_id": augment_id}
	_next_item_number += 1
	item_slots[slot] = item
	return item


func move_item(from_slot: int, to_slot: int) -> bool:
	if not _valid_item_slot(from_slot) or not _valid_item_slot(to_slot) or from_slot == to_slot:
		return false
	if item_slots[from_slot].is_empty():
		return false
	var moved := item_slots[from_slot]
	item_slots[from_slot] = item_slots[to_slot]
	item_slots[to_slot] = moved
	return true


func item_augment_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in item_slots:
		if not item.is_empty():
			ids.append(item["augment_id"])
	return ids


## Maps the nth stored item (ignoring gaps) to its slot, or -1.
func slot_of_nth_item(index: int) -> int:
	if index < 0:
		return -1
	var seen := 0
	for slot in item_slots.size():
		if item_slots[slot].is_empty():
			continue
		if seen == index:
			return slot
		seen += 1
	return -1


func equip_item(employee_id: String, item_slot: int, slot_limit: int) -> bool:
	if not owns(employee_id) or not _valid_item_slot(item_slot) or item_slots[item_slot].is_empty():
		return false
	var loadout: Array = equipment.get(employee_id, [])
	if loadout.size() >= slot_limit:
		return false
	loadout.append(item_slots[item_slot])
	equipment[employee_id] = loadout
	item_slots[item_slot] = {}
	return true


func unequip_item(employee_id: String, equip_index: int, target_slot: int = -1) -> bool:
	var loadout: Array = equipment.get(employee_id, [])
	if equip_index < 0 or equip_index >= loadout.size():
		return false
	if target_slot == -1:
		target_slot = first_free_item_slot()
	if not _valid_item_slot(target_slot) or not item_slots[target_slot].is_empty():
		return false
	item_slots[target_slot] = loadout[equip_index]
	loadout.remove_at(equip_index)
	if loadout.is_empty():
		equipment.erase(employee_id)
	return true


func equipped_instances(employee_id: String) -> Array:
	return equipment.get(employee_id, [])


func equipped_augment_ids() -> Dictionary:
	var result := {}
	for employee_id: String in equipment:
		var ids: Array[String] = []
		for item: Dictionary in equipment[employee_id]:
			ids.append(item["augment_id"])
		result[employee_id] = ids
	return result


# --- Salespeople -----------------------------------------------------------

func owns(employee_id: String) -> bool:
	return not employee_id.is_empty() and (floor_plan.seats.has(employee_id) or person_slots.has(employee_id))


func owned_count() -> int:
	return floor_plan.occupied_seats().size() + person_slots.size() - person_slots.count("")


func first_free_person_slot() -> int:
	return person_slots.find("")


func is_reserve_full() -> bool:
	return first_free_person_slot() == -1


func can_hire(employee_id: String) -> bool:
	return not floor_plan.profile(employee_id).is_empty() and not owns(employee_id) and not is_reserve_full()


## New hires always enter reserve and are never deployed automatically.
func hire(employee_id: String) -> bool:
	if not can_hire(employee_id):
		return false
	person_slots[first_free_person_slot()] = employee_id
	return true


## Moves or swaps salespeople between "board" seats and "reserve" slots in one step.
func move_person(source_kind: String, source_index: int, target_kind: String, target_index: int) -> bool:
	if not _valid_person_slot(source_kind, source_index) or not _valid_person_slot(target_kind, target_index):
		return false
	if source_kind == target_kind and source_index == target_index:
		return false
	var mover := _person_at(source_kind, source_index)
	if mover.is_empty():
		return false
	var displaced := _person_at(target_kind, target_index)
	_set_person(target_kind, target_index, mover)
	_set_person(source_kind, source_index, displaced)
	return true


## Planner entry point: deploys an owned salesperson to a seat, swapping if needed.
func deploy(seat: int, employee_id: String) -> bool:
	var seat_source := floor_plan.seats.find(employee_id)
	if seat_source != -1:
		return move_person(BOARD, seat_source, BOARD, seat)
	var reserve_source := person_slots.find(employee_id)
	if reserve_source == -1:
		return false
	return move_person(RESERVE, reserve_source, BOARD, seat)


## Recalls a seated salesperson into reserve; rejected when reserve is full.
func recall(seat: int) -> bool:
	if seat < 0 or seat >= FloorPlan.SEAT_COUNT or floor_plan.seats[seat].is_empty():
		return false
	var slot := first_free_person_slot()
	return slot != -1 and move_person(BOARD, seat, RESERVE, slot)


func person_at(kind: String, index: int) -> String:
	return _person_at(kind, index) if _valid_person_slot(kind, index) else ""


# --- Persistence -----------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_equipment := {}
	for employee_id: String in equipment:
		saved_equipment[employee_id] = (equipment[employee_id] as Array).duplicate(true)
	return {
		"items": item_slots.duplicate(true),
		"reserve": person_slots.duplicate(),
		"board": floor_plan.seats.duplicate(),
		"equipment": saved_equipment,
		"next_item_number": _next_item_number,
	}


func load_dict(data: Dictionary) -> bool:
	var items: Array = data.get("items", [])
	var reserve: Array = data.get("reserve", [])
	var board: Array = data.get("board", [])
	if items.size() != ITEM_SLOTS or reserve.size() != PERSON_SLOTS or board.size() != FloorPlan.SEAT_COUNT:
		return false
	var seen := {}
	for employee_id: String in reserve + board:
		if employee_id.is_empty():
			continue
		if floor_plan.profile(employee_id).is_empty() or seen.has(employee_id):
			return false
		seen[employee_id] = true
	for index in ITEM_SLOTS:
		item_slots[index] = (items[index] as Dictionary).duplicate()
	for index in PERSON_SLOTS:
		person_slots[index] = reserve[index]
	for index in FloorPlan.SEAT_COUNT:
		floor_plan.seats[index] = board[index]
	equipment = (data.get("equipment", {}) as Dictionary).duplicate(true)
	_next_item_number = int(data.get("next_item_number", 1))
	return true


# --- Internals -------------------------------------------------------------

func _valid_item_slot(slot: int) -> bool:
	return slot >= 0 and slot < ITEM_SLOTS


func _valid_person_slot(kind: String, index: int) -> bool:
	if kind == BOARD:
		return index >= 0 and index < FloorPlan.SEAT_COUNT
	return kind == RESERVE and index >= 0 and index < PERSON_SLOTS


func _person_at(kind: String, index: int) -> String:
	return floor_plan.seats[index] if kind == BOARD else person_slots[index]


func _set_person(kind: String, index: int, employee_id: String) -> void:
	if kind == BOARD:
		floor_plan.seats[index] = employee_id
	else:
		person_slots[index] = employee_id
