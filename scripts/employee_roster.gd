extends Resource
class_name EmployeeRoster
## Shared authoring data and base-stat interpretation for the planner and model.

# Scale the whole floor's handling pace without flattening employee differences.
const BASE_HANDLING_SECONDS := 18.0

@export var employees: Array[Dictionary] = []


func profile(employee_id: String) -> Dictionary:
	for employee in employees:
		if employee["id"] == employee_id:
			return employee
	return {}


func handling_seconds(employee_id: String) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	return BASE_HANDLING_SECONDS / clampf(float(employee["speed"]), 1.0, 5.0)


func conversion_chance(employee_id: String) -> float:
	var employee := profile(employee_id)
	assert(not employee.is_empty(), "Unknown employee: " + employee_id)
	return clampf(float(employee["conversion"]) / 100.0, 0.0, 1.0)
