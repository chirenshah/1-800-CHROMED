extends RefCounted
class_name SalesSlamScenarios
## Shared scenario data for the standalone test scene and the automated tests.


static func _sales(values: Array) -> Array[Dictionary]:
	var sales: Array[Dictionary] = []
	for index in values.size():
		sales.append({"value": int(values[index]), "employee_id": ["nina", "zip", "ada"][index % 3]})
	return sales


static func _crowded() -> Array[Dictionary]:
	var values: Array = []
	for index in 80:
		values.append(30 + (index * 37) % 150)
	return _sales(values)


static func all() -> Array[Dictionary]:
	var crowded := _crowded()
	var crowded_total := SalesSlamPlan.new().total(crowded)
	return [
		{"name": "No sales", "goal": 1000, "sales": _sales([])},
		{"name": "One sale", "goal": 1000, "sales": _sales([250])},
		{"name": "Many small sales", "goal": 1000, "sales": _sales([60, 55, 70, 65, 50, 80, 75, 60])},
		{"name": "One very large sale", "goal": 1000, "sales": _sales([1500])},
		{"name": "Below quota", "goal": 1000, "sales": _sales([220, 180, 260, 140])},
		{"name": "Exactly equal", "goal": 1000, "sales": _sales([400, 350, 250])},
		{"name": "Barely exceeding", "goal": 1000, "sales": _sales([400, 350, 251])},
		{"name": "Greatly exceeding", "goal": 1000, "sales": _sales([300, 450, 600, 900, 700, 550])},
		{"name": "Near miss", "goal": 1000, "sales": _sales([480, 300, 180])},
		{"name": "Many crowded sales (barely over)", "goal": crowded_total - 5, "sales": crowded},
	]


static func named(scenario_name: String) -> Dictionary:
	for scenario in all():
		if scenario["name"] == scenario_name:
			return scenario
	return {}
