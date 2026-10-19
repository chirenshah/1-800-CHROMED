extends Resource
class_name EmployeeRoster
## Shared authoring data and base-stat interpretation for the planner and model.

# Scale the whole floor's handling pace without flattening employee differences.
const BASE_HANDLING_SECONDS := 18.0
const AUGMENTS: AugmentCatalog = preload("res://data/augment_catalog.tres")

@export var employees: Array[Dictionary] = []


func profile(employee_id: String) -> Dictionary:
	for employee in employees:
		if employee["id"] == employee_id:
			return employee
	return {}


func is_recycler(employee_id: String) -> bool:
	return profile(employee_id).get("archetype", "") == "Recycler"


func handling_seconds(employee_id: String) -> float:
	return handling_seconds_with_augments(employee_id, [])


func handling_seconds_with_augments(employee_id: String, equipped_augments: Array[String]) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	var speed_bonus := augment_bonus(equipped_augments, "speed") / 100.0
	return BASE_HANDLING_SECONDS / clampf(float(employee["speed"]), 1.0, 5.0) / (1.0 + speed_bonus)


func conversion_chance(employee_id: String) -> float:
	return conversion_chance_with_augments(employee_id, [])


func conversion_chance_with_augments(employee_id: String, equipped_augments: Array[String]) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	var conversion_bonus := augment_bonus(equipped_augments, "conversion")
	return clampf((float(employee["conversion"]) + conversion_bonus) / 100.0, 0.0, 1.0)


func augment_bonus(equipped_augments: Array[String], stat: String) -> float:
	var total := 0.0
	for augment_id in equipped_augments:
		var augment := AUGMENTS.profile(augment_id)
		if augment.is_empty():
			assert(false, "Unknown augment: " + augment_id)
			continue
		if augment["stat"] == stat:
			total += float(augment["bonus"])
	return total


func upsell_chance(employee_id: String) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	return clampf(float(employee.get("upsell_chance", 0)) / 100.0, 0.0, 1.0)


func upsell_multiplier(employee_id: String) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	return maxf(float(employee.get("upsell_multiplier", 1.0)), 1.0)
