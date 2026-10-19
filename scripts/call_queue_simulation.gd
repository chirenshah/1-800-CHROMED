extends RefCounted
class_name CallQueueSimulation
## The workday's sole clock-driven queue model. Presentation never advances work.

const TICK_SECONDS := 0.75
const PATIENCE_TICKS := 8
const MIN_ARRIVAL_SECONDS := 0.75
const MAX_ARRIVAL_SECONDS := 1.5
const TIME_EPSILON := 0.00000001
const ASSIGNMENT := preload("res://scripts/lead_assignment.gd")

var waiting: Array[Dictionary] = []
var active: Dictionary = {}
# Snapshot the Prepare lineup so daily attribution stays attached to employee IDs.
var employees: Array[String] = []
var employee_stats: Dictionary = {}
var assigned_this_tick: Array[Dictionary] = []
var completed_this_tick: Dictionary = {}
var abandoned_this_tick: Array[Dictionary] = []
var lead_discard_pile: Array[Dictionary] = []
var elapsed_ticks := 0
var elapsed_seconds := 0.0
var next_arrival_seconds := 0.0
var received := 0
var handled := 0
var abandoned := 0
var sales := 0
var normal_sales := 0
var failed_interactions := 0
var discarded_today := 0
var recovery_attempts := 0
var recovered := 0
var failed_recoveries := 0
var recovered_revenue := 0
var revenue := 0
var last_dispatch := ""
var roster: EmployeeRoster = preload("res://data/planning_roster.tres")
var equipped_augments: Dictionary = {}
var _arrival_rng := RandomNumberGenerator.new()
var _conversion_rng := RandomNumberGenerator.new()
var _upsell_rng := RandomNumberGenerator.new()


func reset(lineup: Array[String], arrival_seed: int = -1, loadouts: Dictionary = {}) -> void:
	waiting.clear()
	active.clear()
	employees.assign(lineup)
	equipped_augments = loadouts.duplicate(true)
	employee_stats.clear()
	assigned_this_tick.clear()
	completed_this_tick.clear()
	abandoned_this_tick.clear()
	clear_discard_pile()
	for seat in employees.size():
		var employee_id := employees[seat]
		if employee_id.is_empty():
			continue
		assert(not employee_stats.has(employee_id), "An employee may only occupy one slot.")
		employee_stats[employee_id] = {
			"employee_id": employee_id, "seat": seat, "assigned": 0, "handled": 0,
			"busy_ticks": 0.0, "idle_ticks": 0.0, "sales": 0, "revenue": 0,
		}
	elapsed_ticks = 0
	elapsed_seconds = 0.0
	if arrival_seed == -1:
		_arrival_rng.randomize()
		_conversion_rng.randomize()
		_upsell_rng.randomize()
	else:
		_arrival_rng.seed = arrival_seed
		# Separate streams keep sales rolls from changing incoming lead timing.
		_conversion_rng.seed = arrival_seed ^ 0x5EED
		_upsell_rng.seed = arrival_seed ^ 0x0B5E11
	next_arrival_seconds = _arrival_delay()
	received = 0
	handled = 0
	abandoned = 0
	sales = 0
	normal_sales = 0
	failed_interactions = 0
	discarded_today = 0
	recovery_attempts = 0
	recovered = 0
	failed_recoveries = 0
	recovered_revenue = 0
	last_dispatch = ""


func advance(seconds: float = TICK_SECONDS) -> void:
	assert(seconds >= 0.0, "Simulation time cannot move backwards.")
	assigned_this_tick.clear()
	completed_this_tick.clear()
	abandoned_this_tick.clear()
	var target_seconds := elapsed_seconds + seconds
	while elapsed_seconds < target_seconds:
		# Resolve arrivals and lifecycle deadlines at their exact time, even when
		# advancing a whole tick or catching up across more than one event.
		var interval := minf(target_seconds - elapsed_seconds, time_until_next_event())
		_account_interval(interval)
		elapsed_seconds += interval
		elapsed_ticks = floori((elapsed_seconds + TIME_EPSILON) / TICK_SECONDS)
		_resolve_events()


func time_until_next_event() -> float:
	# Tick boundaries still refresh progress and determine the workday length.
	var deadline := minf((elapsed_ticks + 1) * TICK_SECONDS, next_arrival_seconds)
	for call: Dictionary in active.values():
		deadline = minf(deadline, elapsed_seconds + float(call["remaining"]) * TICK_SECONDS)
	for call in waiting:
		deadline = minf(deadline, _patience_deadline(call))
	return maxf(0.0, deadline - elapsed_seconds)


func _account_interval(seconds: float) -> void:
	var ticks := seconds / TICK_SECONDS
	for seat in employees.size():
		if employees[seat].is_empty():
			continue
		var stats: Dictionary = employee_stats[employees[seat]]
		if active.has(seat):
			stats["busy_ticks"] += ticks
			active[seat]["remaining"] = maxf(0.0, float(active[seat]["remaining"]) - ticks)
		else:
			stats["idle_ticks"] += ticks


func _resolve_events() -> void:
	# Finish ALL calls before routing any newly available employee.
	# Explicit slot order also keeps completion events deterministic.
	for seat in employees.size():
		if not active.has(seat):
			continue
		var stats: Dictionary = employee_stats[employees[seat]]
		var call: Dictionary = active[seat]
		if float(call["remaining"]) <= TIME_EPSILON:
			var is_recovery: bool = call.get("recovery", false)
			# Recovery interactions are tracked separately so each lead still counts once in `handled`.
			if not is_recovery:
				handled += 1
			stats["handled"] += 1
			call["sold"] = _makes_sale(employees[seat], call)
			call["upsold"] = false
			if call["sold"]:
				var payout := int(call["value"])
				# Upsell rolls only happen after a sale, so conversion rolls stay unchanged.
				if _rolls_upsell(employees[seat]):
					call["upsold"] = true
					payout = roundi(payout * roster.upsell_multiplier(employees[seat]))
				call["payout"] = payout
				sales += 1
				if is_recovery:
					recovered += 1
					recovered_revenue += payout
				else:
					normal_sales += 1
				revenue += payout
				stats["sales"] += 1
				stats["revenue"] += payout
			else:
				if is_recovery:
					failed_recoveries += 1
				else:
					failed_interactions += 1
			completed_this_tick[seat] = call.duplicate(true)
			active.erase(seat)
			# A failed recovery is its lead's final outcome and never returns to the pile.
			if not call["sold"] and not is_recovery:
				discard_lead(call)

	# A waiting lead leaves at its deadline, including a tie with a completion.
	# Filter every lead, preserving the relative FIFO order of survivors.
	var survivors: Array[Dictionary] = []
	for call in waiting:
		if _patience_deadline(call) <= elapsed_seconds + TIME_EPSILON:
			abandoned += 1
			abandoned_this_tick.append(call.duplicate(true))
		else:
			survivors.append(call)
	waiting.assign(survivors)

	if next_arrival_seconds <= elapsed_seconds + TIME_EPSILON:
		_enqueue_call()
		next_arrival_seconds += _arrival_delay()
	_dispatch_waiting()


func receive_call() -> void:
	_enqueue_call()
	_dispatch_waiting()


func discard_lead(call: Dictionary) -> void:
	for discarded_call in lead_discard_pile:
		assert(discarded_call["id"] != call["id"], "A lead may only enter the discard pile once.")
	lead_discard_pile.append(call)
	discarded_today += 1


func get_discard_count() -> int:
	return lead_discard_pile.size()


func take_discarded_lead() -> Dictionary:
	if lead_discard_pile.is_empty():
		return {}
	return lead_discard_pile.pop_front()


func clear_discard_pile() -> void:
	lead_discard_pile.clear()


func _enqueue_call() -> void:
	received += 1
	waiting.append({
		"id": received, "value": 180 + received * 15,
		"arrived_tick": elapsed_seconds / TICK_SECONDS, "patience_ticks": PATIENCE_TICKS,
	})


func _arrival_delay() -> float:
	return _arrival_rng.randf_range(MIN_ARRIVAL_SECONDS, MAX_ARRIVAL_SECONDS)


func _patience_deadline(call: Dictionary) -> float:
	return (float(call["arrived_tick"]) + float(call["patience_ticks"])) * TICK_SECONDS


func _dispatch_waiting() -> void:
	# Normal sales representatives only take incoming leads; Recyclers never do.
	var takes_incoming := func(employee_id: String) -> bool: return not roster.is_recycler(employee_id)
	while not waiting.is_empty():
		var seat := ASSIGNMENT.next_available_seat(employees, active, takes_incoming)
		if seat == -1:
			break
		var call: Dictionary = waiting.pop_front()
		call["employee_id"] = employees[seat]
		call["seat"] = seat
		call["duration"] = _handling_ticks(employees[seat], call)
		call["remaining"] = call["duration"]
		active[seat] = call
		employee_stats[employees[seat]]["assigned"] += 1
		assigned_this_tick.append(call.duplicate(true))
		last_dispatch = "Call #%03d → Seat %02d" % [call["id"], seat + 1]
	_dispatch_recoveries()


# Recyclers claim leads from the discard pile in slot order. The lead leaves the
# pile immediately, which guarantees a single recovery attempt.
func _dispatch_recoveries() -> void:
	var takes_discards := func(employee_id: String) -> bool: return roster.is_recycler(employee_id)
	while not lead_discard_pile.is_empty():
		var seat := ASSIGNMENT.next_available_seat(employees, active, takes_discards)
		if seat == -1:
			break
		var call := take_discarded_lead()
		call.erase("sold")
		call.erase("upsold")
		call.erase("payout")
		call["recovery"] = true
		call["employee_id"] = employees[seat]
		call["seat"] = seat
		call["duration"] = _handling_ticks(employees[seat], call)
		call["remaining"] = call["duration"]
		active[seat] = call
		recovery_attempts += 1
		employee_stats[employees[seat]]["assigned"] += 1
		assigned_this_tick.append(call.duplicate(true))
		last_dispatch = "Discard #%03d → Seat %02d" % [call["id"], seat + 1]


func employee_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for employee_id in employees:
		if not employee_id.is_empty():
			results.append(employee_stats[employee_id].duplicate(true))
	return results


# Base stats affect handling only. Future conditional behaviors can extend these
# hooks while intake continues to use fixed slot priority.
func _handling_ticks(employee_id: String, _call: Dictionary) -> float:
	var loadout: Array[String] = []
	loadout.assign(equipped_augments.get(employee_id, []))
	if loadout.is_empty():
		return roster.handling_seconds(employee_id) / TICK_SECONDS
	return roster.handling_seconds_with_augments(employee_id, loadout) / TICK_SECONDS


func _rolls_upsell(employee_id: String) -> bool:
	var roll := _upsell_rng.randf()
	var chance := roster.upsell_chance(employee_id)
	return chance >= 1.0 or roll < chance


func _makes_sale(employee_id: String, _call: Dictionary) -> bool:
	var roll := _conversion_rng.randf()
	var loadout: Array[String] = []
	loadout.assign(equipped_augments.get(employee_id, []))
	if loadout.is_empty():
		var base_chance := roster.conversion_chance(employee_id)
		return base_chance >= 1.0 or roll < base_chance
	var chance := roster.conversion_chance_with_augments(employee_id, loadout)
	return chance >= 1.0 or roll < chance
