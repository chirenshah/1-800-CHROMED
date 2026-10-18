extends RefCounted
class_name CallQueueSimulation
## The workday's sole clock-driven queue model. Presentation never advances work.

const TICK_SECONDS := 0.75
const HANDLING_TICKS := 4
const PATIENCE_TICKS := 8
const ASSIGNMENT := preload("res://scripts/lead_assignment.gd")

var waiting: Array[Dictionary] = []
var active: Dictionary = {}
# Snapshot the Prepare lineup so daily attribution stays attached to employee IDs.
var employees: Array[String] = []
var employee_stats: Dictionary = {}
var assigned_this_tick: Array[Dictionary] = []
var completed_this_tick: Dictionary = {}
var abandoned_this_tick: Array[Dictionary] = []
var elapsed_ticks := 0
var received := 0
var handled := 0
var abandoned := 0
var sales := 0
var revenue := 0
var last_dispatch := ""


func reset(lineup: Array[String]) -> void:
	waiting.clear()
	active.clear()
	employees.assign(lineup)
	employee_stats.clear()
	assigned_this_tick.clear()
	completed_this_tick.clear()
	abandoned_this_tick.clear()
	for seat in employees.size():
		var employee_id := employees[seat]
		if employee_id.is_empty():
			continue
		assert(not employee_stats.has(employee_id), "An employee may only occupy one slot.")
		employee_stats[employee_id] = {
			"employee_id": employee_id, "seat": seat, "assigned": 0, "handled": 0,
			"busy_ticks": 0, "idle_ticks": 0, "sales": 0, "revenue": 0,
		}
	elapsed_ticks = 0
	received = 0
	handled = 0
	abandoned = 0
	sales = 0
	revenue = 0
	last_dispatch = ""


func advance() -> void:
	elapsed_ticks += 1
	assigned_this_tick.clear()
	completed_this_tick.clear()
	abandoned_this_tick.clear()
	# Account for the elapsed interval, then finish ALL calls before routing.
	# Explicit slot order also keeps completion events deterministic.
	for seat in employees.size():
		if employees[seat].is_empty():
			continue
		var stats: Dictionary = employee_stats[employees[seat]]
		if not active.has(seat):
			stats["idle_ticks"] += 1
			continue
		stats["busy_ticks"] += 1
		var call: Dictionary = active[seat]
		call["remaining"] -= 1
		if call["remaining"] <= 0:
			handled += 1
			stats["handled"] += 1
			if _makes_sale(employees[seat], call):
				sales += 1
				revenue += int(call["value"])
				stats["sales"] += 1
				stats["revenue"] += int(call["value"])
			completed_this_tick[seat] = call.duplicate(true)
			active.erase(seat)

	# A waiting lead leaves at its deadline, including a tie with a completion.
	# Filter every lead, preserving the relative FIFO order of survivors.
	var survivors: Array[Dictionary] = []
	for call in waiting:
		if elapsed_ticks - int(call["arrived_tick"]) >= int(call["patience_ticks"]):
			abandoned += 1
			abandoned_this_tick.append(call.duplicate(true))
		else:
			survivors.append(call)
	waiting.assign(survivors)

	# Retain the starter's 2 / 3 / 1 arrival rhythm, now as individual calls.
	for arrival in range(1 + elapsed_ticks % 3):
		received += 1
		waiting.append({
			"id": received, "value": 180 + received * 15,
			"arrived_tick": elapsed_ticks, "patience_ticks": PATIENCE_TICKS,
		})

	while not waiting.is_empty():
		var seat := ASSIGNMENT.next_available_seat(employees, active)
		if seat == -1:
			break
		var call: Dictionary = waiting.pop_front()
		call["employee_id"] = employees[seat]
		call["seat"] = seat
		call["duration"] = maxi(1, _handling_ticks(employees[seat], call))
		call["remaining"] = call["duration"]
		active[seat] = call
		employee_stats[employees[seat]]["assigned"] += 1
		assigned_this_tick.append(call.duplicate(true))
		last_dispatch = "Call #%03d → Seat %02d" % [call["id"], seat + 1]


func employee_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for employee_id in employees:
		if not employee_id.is_empty():
			results.append(employee_stats[employee_id].duplicate(true))
	return results


# Behavior hooks are separate from routing. All colleagues share these prototype
# rules today; future durations/outcomes can use employee_id without changing intake.
func _handling_ticks(_employee_id: String, _call: Dictionary) -> int:
	return HANDLING_TICKS


func _makes_sale(_employee_id: String, call: Dictionary) -> bool:
	return int(call["id"]) % 3 != 0
