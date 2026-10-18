extends SceneTree
## Godot --headless --path . --script res://tests/test_employee_stats.gd

const MODEL := preload("res://scripts/call_queue_simulation.gd")
const CATALOG := preload("res://data/planning_roster.tres")

var failures: Array[String] = []


func _initialize() -> void:
	_test_catalog()
	_test_speed()
	_test_conversion()
	_test_seeded_streams()
	if failures.is_empty():
		print("PASS: eighteen persona baselines, fractional handling durations, conversion probabilities, attribution, seeded outcomes, and independent arrival timing.")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _test_catalog() -> void:
	_check(CATALOG.employees.size() == 18, "All eighteen character concepts must be selectable.")
	var seen := {}
	for employee in CATALOG.employees:
		var employee_id := str(employee["id"])
		_check(not seen.has(employee_id), "Named employees must have unique IDs.")
		seen[employee_id] = true
		_check(employee["speed"] is int and employee["speed"] >= 1 and employee["speed"] <= 5,
			"Every employee needs an integer Speed between one and five: " + employee_id)
		_check(employee["conversion"] is int and employee["conversion"] >= 0 and employee["conversion"] <= 100,
			"Every employee needs a Conversion percentage: " + employee_id)
		var model := MODEL.new()
		model.reset([employee_id], 123)
		model.next_arrival_seconds = INF
		model.receive_call()
		var duration := CATALOG.handling_seconds(employee_id)
		model.advance(duration - 0.001)
		_check(model.handled == 0 and model.active.size() == 1,
			"Calls must stay busy for the employee's full handling duration: " + employee_id)
		model.advance(0.001)
		_check(model.handled == 1 and model.active.is_empty(), "Every employee must finish their lead at the correct time: " + employee_id)
		_check(is_equal_approx(model.employee_stats[employee_id]["busy_ticks"] * MODEL.TICK_SECONDS, duration),
			"Busy time must reflect the actual employee handling duration: " + employee_id)
	_check(CATALOG.profile("zip")["speed"] > CATALOG.profile("nina")["speed"]
		and CATALOG.profile("nina")["speed"] > CATALOG.profile("victoria")["speed"],
		"Fast hustler, dependable workhorse, and patient closer must have distinct speeds.")
	_check(CATALOG.profile("victoria")["conversion"] > CATALOG.profile("nina")["conversion"]
		and CATALOG.profile("nina")["conversion"] > CATALOG.profile("zip")["conversion"],
		"Their Conversion values must reflect the persona tradeoff.")


func _test_speed() -> void:
	var model := MODEL.new()
	model.reset(["victoria", "zip"], 12)
	model.next_arrival_seconds = INF
	for call in range(3):
		model.receive_call()
	_check(model.active[0]["employee_id"] == "victoria" and model.active[0]["id"] == 1,
		"Slot priority must still give the slow first employee the first lead.")
	model.advance(3.6)
	_check(model.handled == 1 and model.completed_this_tick[1]["id"] == 2
		and model.active[1]["id"] == 3 and model.active[0]["id"] == 1,
		"Zip must finish in 3.6 seconds and pick up the waiting lead while Victoria stays busy.")
	_check(is_equal_approx(float(model.active[1]["duration"]), 4.8),
		"Fractional durations must not be rounded to a whole simulation tick.")
	model.advance(14.4)
	_check(model.completed_this_tick[0]["id"] == 1 and model.employee_stats["victoria"]["handled"] == 1,
		"Victoria must finish her first interaction at eighteen seconds.")


func _conversion_fixture(chance: int, run_seed: int) -> CallQueueSimulation:
	var data := EmployeeRoster.new()
	data.employees.append({"id": "seller", "speed": 5, "conversion": chance})
	var model := MODEL.new()
	model.roster = data
	model.reset(["seller"], run_seed)
	model.next_arrival_seconds = INF
	return model


func _test_conversion() -> void:
	for chance in [0, 50, 100]:
		var model := _conversion_fixture(chance, 991)
		var total_value := 0
		for call in range(1000):
			var sales_before := model.sales
			model.receive_call()
			_check(model.handled == call and model.sales == sales_before,
				"Starting a lead must never count as completion or generate a sale.")
			total_value += int(model.active[0]["value"])
			model.advance(model.roster.handling_seconds("seller"))
		_check(model.handled == 1000 and model.employee_stats["seller"]["handled"] == 1000,
			"Every completed interaction must be attributed once.")
		_check(model.sales == model.employee_stats["seller"]["sales"]
			and model.revenue == model.employee_stats["seller"]["revenue"],
			"Sale and revenue attribution must reconcile with aggregate results.")
		if chance == 0:
			_check(model.sales == 0 and model.revenue == 0, "Zero Conversion must never close a sale.")
		elif chance == 100:
			_check(model.sales == 1000 and model.revenue == total_value, "Full Conversion must always close at the lead's unchanged value.")
		else:
			_check(model.sales > 440 and model.sales < 560, "Fifty percent Conversion must yield a representative seeded sale frequency.")


func _test_seeded_streams() -> void:
	var first := MODEL.new()
	var second := MODEL.new()
	first.reset(["nina", "zip", "victoria"], 12345)
	second.reset(["nina", "zip", "victoria"], 12345)
	for step in range(100):
		first.advance()
		randf()
		second.advance()
		_check(var_to_str([first.active, first.waiting, first.employee_results(), first.sales, first.revenue])
			== var_to_str([second.active, second.waiting, second.employee_results(), second.sales, second.revenue]),
			"The same seed and lineup must reproduce handling and sale outcomes independently of global RNG.")
	first.reset(["zip"], 12345)
	second.reset(["victoria"], 12345)
	first.advance(30.0)
	second.advance(30.0)
	_check(first.received == second.received and is_equal_approx(first.next_arrival_seconds, second.next_arrival_seconds),
		"Different handling speeds and sales-roll counts must not change the seeded arrival schedule.")
	var replay := _conversion_fixture(50, 991)
	var reference := _conversion_fixture(50, 991)
	for call in range(10):
		replay.receive_call()
		replay.advance(replay.roster.handling_seconds("seller"))
	replay.reset(["seller"], 991)
	replay.next_arrival_seconds = INF
	for call in range(50):
		replay.receive_call()
		reference.receive_call()
		replay.advance(replay.roster.handling_seconds("seller"))
		reference.advance(reference.roster.handling_seconds("seller"))
	_check(replay.sales == reference.sales and replay.revenue == reference.revenue,
		"A daily reset with the same seed must reset the conversion stream as well as the queue.")
