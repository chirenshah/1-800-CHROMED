extends SceneTree
## Godot --headless --path . --script res://tests/test_lead_assignment.gd

const MODEL := preload("res://scripts/call_queue_simulation.gd")
const ROUTING := preload("res://scripts/lead_assignment.gd")
const PLAN := preload("res://scripts/floor_plan.gd")

class LifecycleRoster extends EmployeeRoster:
	func handling_seconds(_employee_id: String) -> float:
		return 3.0


var failures: Array[String] = []


func _initialize() -> void:
	_test_routing()
	_test_simultaneous_completion()
	_test_abandonment()
	_test_employee_attribution()
	_test_arrivals()
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
	model.reset(plan.seats, 100)
	model.next_arrival_seconds = INF
	model.receive_call()
	_check(model.active[0]["employee_id"] == "nina", "Initial lead must reach the employee in slot one.")
	plan.assign(0, "zip")
	model.reset(plan.seats, 100)
	model.next_arrival_seconds = INF
	model.receive_call()
	model.receive_call()
	_check(model.active[0]["employee_id"] == "zip" and model.active[1]["employee_id"] == "nina",
		"A Prepare swap must change who receives the first two leads.")
	plan.bench(0)
	_check(model.employees[0] == "zip", "A live day must own a copy of its starting lineup.")


func _fixture(lineup: Array[String], count: int) -> CallQueueSimulation:
	var model := MODEL.new()
	# Isolate lifecycle/priority fixtures from the game's tunable employee balance.
	var fixture_roster := LifecycleRoster.new()
	for employee_id in lineup:
		if not employee_id.is_empty():
			fixture_roster.employees.append({"id": employee_id, "speed": 2, "conversion": 100})
	model.roster = fixture_roster
	model.reset(lineup, 123)
	model.next_arrival_seconds = INF
	for index in range(count):
		model.receive_call()
	return model


func _test_simultaneous_completion() -> void:
	var model := _fixture(["nina", "zip", "", "", "", "", "", "", ""], 5)
	_check(model.assigned_this_tick.size() == 2, "Injected calls must dispatch immediately and append assignment events.")
	# Reverse insertion order: availability must still resolve by fixed slot order.
	model.active = {1: model.active[1], 0: model.active[0]}
	model.advance(2.9)
	_check(model.active[0]["id"] == 1 and model.active[1]["id"] == 2,
		"Busy employees cannot receive another concurrent lead before three seconds.")
	_check(model.assigned_this_tick.is_empty(), "Each advance must clear prior assignment events.")
	model.advance(0.1)
	_check(model.completed_this_tick.size() == 2 and model.handled == 2,
		"All same-time completions must finish at exactly three seconds before routing starts.")
	_check(model.active[0]["id"] == 3 and model.active[1]["id"] == 4
		and model.waiting[0]["id"] == 5, "Queued leads must refill simultaneous vacancies by FIFO and slot priority.")
	_check(is_equal_approx(model.employee_stats["nina"]["busy_ticks"], 4.0)
		and is_zero_approx(model.employee_stats["nina"]["idle_ticks"]),
		"Workload must include fractional elapsed intervals and work completed at the deadline.")


func _test_abandonment() -> void:
	var model := _fixture([], 2)
	model.advance(5.9)
	_check(model.abandoned == 0 and model.waiting[0]["id"] == 1, "Waiting leads stay until their actual patience deadline.")
	model.advance(0.1)
	_check(model.abandoned == 2 and model.abandoned_this_tick[0]["id"] == 1
		and model.waiting.is_empty() and model.active.is_empty(),
		"All-empty floors must expire all leads at exactly six seconds.")
	model = _fixture(["nina"], 3)
	model.waiting[0]["patience_ticks"] = 4
	model.active[0]["patience_ticks"] = 1
	model.advance(3.0)
	_check(model.handled == 1 and model.completed_this_tick[0]["id"] == 1,
		"An active interaction must never abandon due to queue patience.")
	_check(model.abandoned == 1 and model.abandoned_this_tick[0]["id"] == 2
		and model.active[0]["id"] == 3,
		"At a tied deadline/completion, expire the waiting lead before dispatching the next survivor.")
	model = _fixture(["nina"], 4)
	model.waiting[1]["patience_ticks"] = 1
	model.advance()
	_check(model.abandoned == 1 and model.abandoned_this_tick[0]["id"] == 3
		and model.waiting[0]["id"] == 2 and model.waiting[1]["id"] == 4,
		"A non-head lead may abandon without changing the surviving FIFO order.")


func _test_employee_attribution() -> void:
	var model := _fixture(["", "", "", "", "", "", "", "", "dex"], 2)
	model.advance(3.0)
	var result: Dictionary = model.employee_results()[0]
	_check(result["employee_id"] == "dex" and result["seat"] == 8
		and result["assigned"] == 2 and result["handled"] == 1
		and result["sales"] == 1 and result["revenue"] == 195,
		"The employee in slot nine must receive measured assignment, completion, and sale attribution.")
	result["assigned"] = 999
	_check(model.employee_stats["dex"]["assigned"] == 2, "Report snapshots must not mutate the simulation.")
	model.roster = PLAN.CATALOG
	model.reset(["nina"], 123)
	_check(model.elapsed_ticks == 0 and is_zero_approx(model.elapsed_seconds)
		and model.abandoned == 0 and model.handled == 0
		and model.sales == 0 and model.revenue == 0 and model.received == 0
		and model.waiting.is_empty() and model.active.is_empty() and model.last_dispatch.is_empty()
		and model.assigned_this_tick.is_empty() and model.completed_this_tick.is_empty()
		and model.abandoned_this_tick.is_empty() and not model.employee_stats.has("dex")
		and model.employee_stats["nina"]["assigned"] == 0,
		"A new day must clear busy states, events, counters, and old employee attribution.")
	model.receive_call()
	_check(model.active[0]["id"] == 1, "The next day must start with fresh leads and available employees.")


func _test_arrivals() -> void:
	var first := MODEL.new()
	var second := MODEL.new()
	first.reset([], 31)
	second.reset([], 72)
	var original_delay: float = first.next_arrival_seconds
	_check(is_equal_approx(MODEL.MIN_ARRIVAL_SECONDS, 0.75)
		and is_equal_approx(MODEL.MAX_ARRIVAL_SECONDS, 3.0), "Arrival bounds must remain 0.75 to 3 seconds.")
	_check(first.received == 0 and original_delay >= 0.75 and original_delay <= 3.0,
		"Reset must schedule a fresh bounded delay without receiving a call.")
	_check(not is_equal_approx(original_delay, second.next_arrival_seconds), "Different seeds must produce different arrival schedules.")
	first.advance(original_delay - 0.001)
	_check(first.received == 0, "No call may arrive before its sampled deadline.")
	first.advance(0.001)
	_check(first.received == 1 and is_equal_approx(first.waiting[0]["arrived_tick"], original_delay / MODEL.TICK_SECONDS),
		"The first deadline must create exactly one call with its precise fractional arrival time.")
	var intervals := {}
	for index in range(30):
		var deadline: float = first.next_arrival_seconds
		var delay: float = deadline - first.elapsed_seconds
		_check(delay >= MODEL.MIN_ARRIVAL_SECONDS and delay <= MODEL.MAX_ARRIVAL_SECONDS,
			"Each newly sampled interval must stay within the arrival bounds.")
		intervals[snappedf(delay, 0.0001)] = true
		var before: int = first.received
		var next_tick: float = (first.elapsed_ticks + 1) * MODEL.TICK_SECONDS - first.elapsed_seconds
		var patience: float = 6.0 - (first.elapsed_seconds - float(first.waiting[0]["arrived_tick"]) * MODEL.TICK_SECONDS)
		_check(is_equal_approx(first.time_until_next_event(), minf(next_tick, minf(delay, patience))),
			"The next-event delay must include arrivals, display ticks, and waiting patience deadlines.")
		first.advance(delay)
		_check(first.received == before + 1, "Each arrival deadline must generate one call.")
		_check(first.elapsed_ticks == int(floor(first.elapsed_seconds / MODEL.TICK_SECONDS)),
			"Whole elapsed ticks must be derived from exact elapsed seconds.")
	_check(intervals.size() > 1, "Arrival intervals must vary within a seeded run.")
	first.reset([], 31)
	_check(first.received == 0 and is_zero_approx(first.elapsed_seconds)
		and is_equal_approx(first.next_arrival_seconds, original_delay), "Seeded reset must reproduce a fresh first-arrival delay.")
	first.advance(0.25)
	first.receive_call()
	_check(is_equal_approx(first.waiting[0]["arrived_tick"], 0.25 / MODEL.TICK_SECONDS)
		and is_equal_approx(first.next_arrival_seconds, original_delay), "Manual injection must use current time and preserve the scheduled arrival.")
	var whole := MODEL.new()
	var split := MODEL.new()
	whole.reset(["nina"], 44)
	split.reset(["nina"], 44)
	whole.advance(30.0)
	for index in range(120):
		split.advance(0.25)
	_check([whole.received, whole.handled, whole.abandoned, whole.active.size(), whole.waiting.size()]
		== [split.received, split.handled, split.abandoned, split.active.size(), split.waiting.size()],
		"Advancing across many event deadlines must preserve the same lifecycle as smaller steps.")
	_check(is_equal_approx(whole.employee_stats["nina"]["busy_ticks"], split.employee_stats["nina"]["busy_ticks"])
		and is_equal_approx(whole.employee_stats["nina"]["idle_ticks"], split.employee_stats["nina"]["idle_ticks"]),
		"Event-time workload must be independent of advance step size.")


func _snapshot(model: CallQueueSimulation) -> String:
	return var_to_str([model.elapsed_seconds, model.next_arrival_seconds, model.elapsed_ticks, model.received, model.handled, model.abandoned,
		model.sales, model.revenue, model.active, model.waiting, model.employee_results(),
		model.assigned_this_tick, model.completed_this_tick, model.abandoned_this_tick])


func _test_repeatability_and_accounting() -> void:
	for count in range(10):
		var lineup: Array[String] = []
		for seat in range(9):
			lineup.append(str(PLAN.CATALOG.employees[seat]["id"]) if seat < count else "")
		var first := MODEL.new()
		var second := MODEL.new()
		first.reset(lineup, 1800)
		second.reset(lineup, 1800)
		var assigned_ids := {}
		var terminal_ids := {}
		for step in range(100):
			first.advance()
			# Global RNG use must not perturb either model’s independent stream.
			randf()
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
				_check(is_equal_approx(result["busy_ticks"] + result["idle_ticks"], first.elapsed_seconds / MODEL.TICK_SECONDS),
					"Every employee's busy and idle time must cover exactly the elapsed workday.")
				total_assigned += int(result["assigned"])
				total_handled += int(result["handled"])
				total_sales += int(result["sales"])
				total_revenue += int(result["revenue"])
			_check(total_assigned == first.handled + first.active.size() and total_handled == first.handled
				and total_sales == first.sales and total_revenue == first.revenue,
				"Employee workload and sale totals must reconcile with the existing aggregate metrics.")
