extends SceneTree
## Godot --headless --path . --script res://tests/test_lead_assignment.gd

const MODEL := preload("res://scripts/call_queue_simulation.gd")
const ROUTING := preload("res://scripts/lead_assignment.gd")
const PLAN := preload("res://scripts/floor_plan.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_test_routing()
	_test_simultaneous_completion()
	_test_abandonment()
	_test_employee_attribution()
	_test_repeatability_and_accounting()
	if failures.is_empty():
		print("PASS: fixed slot routing, simultaneous availability, FIFO, abandonment deadlines, employee workload, resets, and deterministic accounting.")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _test_routing() -> void:
	var lineup: Array[String] = ["", "zip", "", "nina", "", "", "", "", "dex"]
	var busy := {3: {"id": 1}}
	var before := var_to_str([lineup, busy])
	_check(ROUTING.next_available_seat(lineup, busy) == 1, "The earliest eligible slot wins regardless of busy dictionary order.")
	_check(before == var_to_str([lineup, busy]), "Routing must be a pure selection function.")
	busy[1] = {"id": 2}
	_check(ROUTING.next_available_seat(lineup, busy) == 8, "Skip busy and empty slots through position nine.")
	busy[8] = {"id": 3}
	_check(ROUTING.next_available_seat(lineup, busy) == -1, "All busy means no assignment.")
	_check(ROUTING.next_available_seat([], {}) == -1, "An empty floor has no eligible employee.")
	var plan := PLAN.new()
	var model := MODEL.new()
	model.reset(plan.seats)
	model.advance()
	_check(model.active[0]["employee_id"] == "nina", "Initial lead must reach the employee in slot one.")
	plan.assign(0, "zip")
	model.reset(plan.seats)
	model.advance()
	_check(model.active[0]["employee_id"] == "zip" and model.active[1]["employee_id"] == "nina",
		"A Prepare swap must change who receives the first two leads.")
	plan.bench(0)
	_check(model.employees[0] == "zip", "A live day must own a copy of its starting lineup.")


func _test_simultaneous_completion() -> void:
	var model := MODEL.new()
	model.reset(["nina", "zip", "", "", "", "", "", "", ""])
	model.advance()
	# Reverse insertion order: availability must still resolve by fixed slot order.
	model.active = {1: model.active[1], 0: model.active[0]}
	for step in range(3):
		model.advance()
		_check(model.active[0]["id"] == 1 and model.active[1]["id"] == 2,
			"Busy employees cannot receive another concurrent lead.")
	model.advance()
	_check(model.completed_this_tick.size() == 2 and model.handled == 2,
		"All same-time completions must finish before routing starts.")
	_check(model.active[0]["id"] == 3 and model.active[1]["id"] == 4
		and model.waiting[0]["id"] == 5, "Queued leads must refill simultaneous vacancies by FIFO and slot priority.")
	_check(model.employee_stats["nina"]["busy_ticks"] == 4 and model.employee_stats["nina"]["idle_ticks"] == 1,
		"Workload counts elapsed intervals, including work completed on the current tick.")


func _test_abandonment() -> void:
	var model := MODEL.new()
	model.reset(["", "", "", "", "", "", "", "", ""])
	for step in range(MODEL.PATIENCE_TICKS):
		model.advance()
	_check(model.abandoned == 0 and model.waiting[0]["id"] == 1, "Waiting leads stay until their actual patience deadline.")
	model.advance()
	_check(model.abandoned == 2 and model.abandoned_this_tick[0]["id"] == 1
		and model.waiting[0]["id"] == 3 and model.active.is_empty(),
		"All-empty floors must expire leads without assigning or losing other callers.")
	model.reset(["nina", "", "", "", "", "", "", "", ""])
	model.advance()
	model.waiting[0]["patience_ticks"] = 4
	model.active[0]["patience_ticks"] = 1
	for step in range(4):
		model.advance()
	_check(model.handled == 1 and model.completed_this_tick[0]["id"] == 1,
		"An active interaction must never abandon due to queue patience.")
	_check(model.abandoned == 1 and model.abandoned_this_tick[0]["id"] == 2
		and model.active[0]["id"] == 3,
		"At a tied deadline/completion, expire the waiting lead before dispatching the next survivor.")
	model.reset(["nina", "", "", "", "", "", "", "", ""])
	model.advance()
	model.advance()
	model.waiting[1]["patience_ticks"] = 1
	model.advance()
	_check(model.abandoned == 1 and model.abandoned_this_tick[0]["id"] == 3
		and model.waiting[0]["id"] == 2 and model.waiting[1]["id"] == 4,
		"A non-head lead may abandon without changing the surviving FIFO order.")


func _test_employee_attribution() -> void:
	var model := MODEL.new()
	model.reset(["", "", "", "", "", "", "", "", "dex"])
	for step in range(5):
		model.advance()
	var result: Dictionary = model.employee_results()[0]
	_check(result["employee_id"] == "dex" and result["seat"] == 8
		and result["assigned"] == 2 and result["handled"] == 1
		and result["sales"] == 1 and result["revenue"] == 195,
		"The employee in slot nine must receive measured assignment, completion, and sale attribution.")
	result["assigned"] = 999
	_check(model.employee_stats["dex"]["assigned"] == 2, "Report snapshots must not mutate the simulation.")
	model.reset(["nina", "", "", "", "", "", "", "", ""])
	_check(model.elapsed_ticks == 0 and model.abandoned == 0 and model.handled == 0
		and model.sales == 0 and model.revenue == 0 and model.received == 0
		and model.waiting.is_empty() and model.active.is_empty() and model.last_dispatch.is_empty()
		and model.assigned_this_tick.is_empty() and model.completed_this_tick.is_empty()
		and model.abandoned_this_tick.is_empty() and not model.employee_stats.has("dex")
		and model.employee_stats["nina"]["assigned"] == 0,
		"A new day must clear busy states, events, counters, and old employee attribution.")
	model.advance()
	_check(model.active[0]["id"] == 1, "The next day must start with fresh leads and available employees.")


func _snapshot(model: CallQueueSimulation) -> String:
	return var_to_str([model.elapsed_ticks, model.received, model.handled, model.abandoned,
		model.sales, model.revenue, model.active, model.waiting, model.employee_results(),
		model.assigned_this_tick, model.completed_this_tick, model.abandoned_this_tick])


func _test_repeatability_and_accounting() -> void:
	for count in range(10):
		var lineup: Array[String] = []
		for seat in range(9):
			lineup.append("employee_%d" % seat if seat < count else "")
		var first := MODEL.new()
		var second := MODEL.new()
		seed(1800)
		first.reset(lineup)
		seed(1800)
		second.reset(lineup)
		var assigned_ids := {}
		var terminal_ids := {}
		for step in range(100):
			first.advance()
			second.advance()
			_check(_snapshot(first) == _snapshot(second), "Identical initial states and seeds must reproduce every tick.")
			_check(first.received == first.handled + first.abandoned + first.active.size() + first.waiting.size(),
				"Every received lead must occupy exactly one queue lifecycle state.")
			for call in first.assigned_this_tick:
				_check(not assigned_ids.has(call["id"]) and not terminal_ids.has(call["id"]), "A lead may only be assigned once.")
				assigned_ids[call["id"]] = true
			for call: Dictionary in first.completed_this_tick.values():
				_check(assigned_ids.has(call["id"]) and not terminal_ids.has(call["id"]), "Only an assigned, unfinished lead can complete.")
				terminal_ids[call["id"]] = true
			for call in first.abandoned_this_tick:
				_check(not assigned_ids.has(call["id"]) and not terminal_ids.has(call["id"]), "Only an unassigned waiting lead can abandon once.")
				terminal_ids[call["id"]] = true
			var seen := {}
			for call: Dictionary in first.active.values():
				_check(not seen.has(call["id"]) and not terminal_ids.has(call["id"]), "Active leads must be unique and unfinished.")
				seen[call["id"]] = true
			var previous_id := 0
			for call in first.waiting:
				_check(call["id"] > previous_id and not seen.has(call["id"]) and not terminal_ids.has(call["id"]), "The live queue must preserve FIFO and distinct lead identities.")
				previous_id = call["id"]
				seen[call["id"]] = true
			var total_assigned := 0
			var total_handled := 0
			var total_sales := 0
			var total_revenue := 0
			for result in first.employee_results():
				_check(result["busy_ticks"] + result["idle_ticks"] == first.elapsed_ticks,
					"Every employee's busy and idle time must cover exactly the elapsed workday.")
				total_assigned += int(result["assigned"])
				total_handled += int(result["handled"])
				total_sales += int(result["sales"])
				total_revenue += int(result["revenue"])
			_check(total_assigned == first.handled + first.active.size() and total_handled == first.handled
				and total_sales == first.sales and total_revenue == first.revenue,
				"Employee workload and sale totals must reconcile with the existing aggregate metrics.")
