extends Resource
class_name EmployeeRoster
## Shared authoring data and base-stat interpretation for the planner and model.

# Scale the whole floor's handling pace without flattening employee differences.
const BASE_HANDLING_SECONDS := 18.0
const REAL_SECONDS_PER_GAME_HOUR := 3.0
const DEFAULT_STAMINA_HOURS := 4.0
## Temporary baseline until per-character upkeep is tuned in planning_roster.tres.
const DEFAULT_DAILY_UPKEEP := 100
const AUGMENTS: AugmentCatalog = preload("res://data/augment_catalog.tres")
const EFFECT_ENGINE = preload("res://scripts/augment_effect_engine.gd")

@export var employees: Array[Dictionary] = []


func profile(employee_id: String) -> Dictionary:
	for employee in employees:
		if employee["id"] == employee_id:
			return employee
	return {}


func is_recycler(employee_id: String) -> bool:
	return profile(employee_id).get("archetype", "") == "Recycler"


func stamina_hours(employee_id: String) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	return maxf(float(employee.get("stamina_hours", DEFAULT_STAMINA_HOURS)), 0.1)


func daily_upkeep(employee_id: String) -> int:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	return maxi(int(employee.get("daily_upkeep", DEFAULT_DAILY_UPKEEP)), 0)


static func format_game_duration(real_seconds: float) -> String:
	var game_minutes := maxi(1, roundi(real_seconds / REAL_SECONDS_PER_GAME_HOUR * 60.0))
	var hours := floori(game_minutes / 60.0)
	var minutes := game_minutes % 60
	return "%dh%02dm" % [hours, minutes] if hours > 0 else "%dm" % minutes


func handling_seconds(employee_id: String) -> float:
	return handling_seconds_with_augments(employee_id, [])


func handling_seconds_with_augments(employee_id: String, equipped_augments: Array[String]) -> float:
	var speed: float = float(modified_stats(employee_id, equipped_augments).get("speed", 0.0))
	return INF if speed <= 0.0 else BASE_HANDLING_SECONDS / float(speed)


func conversion_chance(employee_id: String) -> float:
	return conversion_chance_with_augments(employee_id, [])


func conversion_chance_with_augments(employee_id: String, equipped_augments: Array[String]) -> float:
	return float(modified_stats(employee_id, equipped_augments).get("conversion", 0.0)) / 100.0


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
	return upsell_chance_with_augments(employee_id, [])


func upsell_chance_with_augments(employee_id: String, equipped_augments: Array[String]) -> float:
	return float(modified_stats(employee_id, equipped_augments).get("upsell_chance", 0.0)) / 100.0


func upsell_multiplier(employee_id: String) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	return maxf(float(employee.get("upsell_multiplier", 1.0)), 1.0)


func modified_stats(employee_id: String, equipped_augments: Array = []) -> Dictionary:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	var engine = EFFECT_ENGINE.new()
	return engine.resolve_stats(self, employee_id, {employee_id: equipped_augments})
