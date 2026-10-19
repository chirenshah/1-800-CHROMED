extends SceneTree
## Godot --headless --path . --script res://tests/test_employee_stats.gd

const MODEL := preload("res://scripts/call_queue_simulation.gd")
const CATALOG := preload("res://data/planning_roster.tres")

var failures: Array[String] = []


func _initialize() -> void:
	_test_catalog()
	_test_speed()
	_test_conversion()
	_test_upsell()
	_test_discard_lifecycle()
	_test_recycler()
	_test_seeded_streams()
	if failures.is_empty():
		print("PASS: nineteen employee baselines, conversion probabilities, Recycler recovery, attribution, seeded outcomes, and independent arrival timing.")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _test_catalog() -> void:
	_check(CATALOG.employees.size() == 19, "All nineteen character concepts must be selectable.")
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
		if CATALOG.is_recycler(employee_id):
			_check(model.active.is_empty() and model.waiting.size() == 1,
				"A Recycler must not take an incoming call: " + employee_id)
			continue
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
			_check(model.sales == 0 and model.revenue == 0
				and model.get_discard_count() == 1000 and model.failed_interactions == 1000,
				"Zero Conversion must never close a sale and every failed lead must be discarded.")
		elif chance == 100:
			_check(model.sales == 1000 and model.revenue == total_value and model.get_discard_count() == 0,
				"Full Conversion must always close at the lead's unchanged value without discarding leads.")
		else:
			_check(model.sales > 440 and model.sales < 560, "Fifty percent Conversion must yield a representative seeded sale frequency.")
			_check(model.get_discard_count() == model.failed_interactions
				and model.get_discard_count() == model.handled - model.sales,
				"Only failed completed interactions may enter the discard pile.")


func _test_upsell() -> void:
	for upsell in [0, 100]:
		var data := EmployeeRoster.new()
		data.employees.append({"id": "seller", "speed": 5, "conversion": 100, "upsell_chance": upsell, "upsell_multiplier": 2.0})
		var model := MODEL.new()
		model.roster = data
		model.reset(["seller"], 77)
		model.next_arrival_seconds = INF
		var total_value := 0
		for call in range(100):
			model.receive_call()
			total_value += int(model.active[0]["value"])
			model.advance(model.roster.handling_seconds("seller"))
		var expected := total_value * 2 if upsell == 100 else total_value
		_check(model.revenue == expected and model.sales == 100,
			"Upsell chance must gate the multiplier without changing the sale count.")
	var no_sale := EmployeeRoster.new()
	no_sale.employees.append({"id": "seller", "speed": 5, "conversion": 0, "upsell_chance": 100, "upsell_multiplier": 3.0})
	var model := MODEL.new()
	model.roster = no_sale
	model.reset(["seller"], 5)
	model.next_arrival_seconds = INF
	model.receive_call()
	model.advance(model.roster.handling_seconds("seller"))
	_check(model.revenue == 0, "An upsell must never occur without a sale.")


func _test_discard_lifecycle() -> void:
	var data := EmployeeRoster.new()
	data.employees.append({"id": "first", "speed": 5, "conversion": 0})
	data.employees.append({"id": "second", "speed": 5, "conversion": 0})
	var model := MODEL.new()
	model.roster = data
	model.reset(["first", "second"], 19)
	model.next_arrival_seconds = INF
	model.receive_call()
	model.receive_call()
	var first_lead: Dictionary = model.active[0].duplicate(true)
	var second_lead: Dictionary = model.active[1].duplicate(true)
	model.advance(data.handling_seconds("first"))
	_check(model.failed_interactions == 2 and model.get_discard_count() == 2
		and model.sales == 0 and model.active.is_empty(),
		"Simultaneous failed interactions must each release their employee and enter the pile once.")
	_check(model.lead_discard_pile[0]["id"] == first_lead["id"]
		and model.lead_discard_pile[0]["value"] == first_lead["value"]
		and model.lead_discard_pile[0]["employee_id"] == "first"
		and model.lead_discard_pile[1]["id"] == second_lead["id"]
		and model.lead_discard_pile[1]["value"] == second_lead["value"]
		and model.completed_this_tick[0]["sold"] == false
		and model.completed_this_tick[1]["sold"] == false,
		"Discarded leads must retain identity and existing properties, marked as unsuccessful.")
	model.clear_discard_pile()
	_check(model.get_discard_count() == 0 and model.discarded_today == 2,
		"Clearing the live pile must preserve the daily discarded total for reporting.")
	model.reset(["first", "second"], 19)
	_check(model.get_discard_count() == 0 and model.discarded_today == 0
		and model.failed_interactions == 0 and model.normal_sales == 0
		and model.recovery_attempts == 0 and model.recovered == 0
		and model.failed_recoveries == 0 and model.recovered_revenue == 0,
		"A new workday must begin with an empty pile and fresh failure statistics.")


func _recycler_fixture(seller_conversion: int, recycler_conversion: int, lineup: Array[String], run_seed: int = 21) -> CallQueueSimulation:
	var data := EmployeeRoster.new()
	data.employees.append({"id": "seller", "archetype": "Hustler", "speed": 5, "conversion": seller_conversion})
	data.employees.append({"id": "recycler", "archetype": "Recycler", "speed": 5, "conversion": recycler_conversion,
		"upsell_chance": 100, "upsell_multiplier": 2.0})
	data.employees.append({"id": "recycler2", "archetype": "Recycler", "speed": 5, "conversion": recycler_conversion,
		"upsell_chance": 100, "upsell_multiplier": 2.0})
	var model := MODEL.new()
	model.roster = data
	model.reset(lineup, run_seed)
	model.next_arrival_seconds = INF
	return model


func _test_recycler() -> void:
	# Recyclers never take incoming leads, and idle with an empty pile.
	var model := _recycler_fixture(0, 100, ["recycler"])
	model.receive_call()
	_check(model.active.is_empty() and model.waiting.size() == 1 and model.get_discard_count() == 0,
		"A Recycler must never receive a lead from the incoming queue.")
	model.advance(1.0)
	_check(model.employee_stats["recycler"]["assigned"] == 0, "A Recycler must stay idle while the discard pile is empty.")

	# A failed normal sale is claimed immediately and recovered for revenue.
	model = _recycler_fixture(0, 100, ["seller", "recycler"])
	model.receive_call()
	var lead_value := int(model.active[0]["value"])
	model.advance(model.roster.handling_seconds("seller"))
	_check(model.get_discard_count() == 0 and model.active.has(1) and model.active[1]["recovery"]
		and model.active[1]["id"] == 1 and model.recovery_attempts == 1 and model.discarded_today == 1,
		"A Recycler must claim a discarded lead as soon as it enters the pile.")
	model.advance(model.roster.handling_seconds("recycler"))
	_check(model.recovered == 1 and model.recovery_attempts == 1 and model.sales == 1
		and model.normal_sales == 0 and model.revenue == lead_value * 2
		and model.recovered_revenue == lead_value * 2 and model.handled == 1
		and model.failed_interactions == 1 and model.employee_stats["recycler"]["sales"] == 1
		and model.get_discard_count() == 0,
		"A recovered lead must use normal upsells, count as revenue, be attributed to the Recycler, and never return to the pile.")

	# A failed recovery is final: one attempt per lead.
	model = _recycler_fixture(0, 0, ["seller", "recycler", "recycler2"])
	model.receive_call()
	model.advance(model.roster.handling_seconds("seller"))
	model.advance(model.roster.handling_seconds("recycler"))
	_check(model.recovery_attempts == 1 and model.failed_recoveries == 1
		and model.recovered == 0 and model.sales == 0
		and model.get_discard_count() == 0 and model.active.is_empty() and model.waiting.is_empty()
		and model.employee_stats["recycler2"]["assigned"] == 0,
		"A failed recovery must permanently remove the lead.")
	model.advance(5.0)
	_check(model.recovery_attempts == 1 and model.failed_recoveries == 1,
		"A lead must never receive a second recovery attempt.")

	# An unfinished recovery remains an unfinished interaction and earns nothing.
	model = _recycler_fixture(0, 100, ["seller", "recycler"])
	model.receive_call()
	model.advance(model.roster.handling_seconds("seller"))
	model.advance(model.roster.handling_seconds("recycler") / 2.0)
	_check(model.recovery_attempts == 1 and model.recovered == 0
		and model.failed_recoveries == 0 and model.revenue == 0
		and model.active.has(1) and model.active[1].get("recovery", false),
		"An unfinished recovery must not be counted as a success or earn revenue.")

	# Several discarded leads are shared by slot priority; no lead goes to two Recyclers.
	model = _recycler_fixture(0, 100, ["recycler", "recycler2"])
	model.discard_lead({"id": 7, "value": 285})
	model.discard_lead({"id": 8, "value": 300})
	model.discard_lead({"id": 9, "value": 315})
	model.receive_call()
	_check(model.active[0]["id"] == 7 and model.active[1]["id"] == 8
		and model.lead_discard_pile.size() == 1 and model.lead_discard_pile[0]["id"] == 9,
		"Available Recyclers must claim distinct discarded leads in fixed slot order.")

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
