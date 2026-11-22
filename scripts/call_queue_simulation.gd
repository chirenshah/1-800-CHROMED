extends RefCounted
class_name CallQueueSimulation
## The workday's sole clock-driven queue model. Presentation never advances work.

const TICK_SECONDS := 0.75
const PATIENCE_TICKS := 8
const MIN_ARRIVAL_SECONDS := 0.75
const MAX_ARRIVAL_SECONDS := 1.5
const TIME_EPSILON := 0.00000001
const BREAK_HOURS := 1.0
const BREAK_SECONDS := BREAK_HOURS * EmployeeRoster.REAL_SECONDS_PER_GAME_HOUR
const ASSIGNMENT := preload("res://scripts/lead_assignment.gd")
const EFFECT_ENGINE_SCRIPT := preload("res://scripts/augment_effect_engine.gd")

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
var sale_log: Array[Dictionary] = []
var last_dispatch := ""
var roster: EmployeeRoster = preload("res://data/planning_roster.tres")
var equipped_augments: Dictionary = {}
var equipped_instances: Dictionary = {}
var positions: Dictionary = {}
var temporary_effects: Array[Dictionary] = []
var event_log: Array[Dictionary] = []
var sale_settlement_callback := Callable()
var cash_effect_callback := Callable()
var financial_context_provider := Callable()
var _pending_root_events: Array[Dictionary] = []
var _chain_activations: Dictionary = {}
var _next_chain_id := 1
var _next_event_id := 1
var _effect_engine: AugmentEffectEngine
var _arrival_rng := RandomNumberGenerator.new()
var _conversion_rng := RandomNumberGenerator.new()
var _upsell_rng := RandomNumberGenerator.new()


func reset(lineup: Array[String], arrival_seed: int = -1, loadouts: Dictionary = {}) -> void:
	waiting.clear()
	active.clear()
	employees.assign(lineup)
	equipped_augments.clear()
	equipped_instances.clear()
	positions.clear()
	for seat in employees.size():
		var employee_id := employees[seat]
		if employee_id.is_empty():
			continue
		positions[employee_id] = seat
		var instances: Array = []
		var ids: Array[String] = []
		for slot in loadouts.get(employee_id, []):
			if slot is Dictionary:
				instances.append(slot.duplicate(true))
				ids.append(str(slot.get("augment_id", "")))
			else:
				var augment_id := str(slot)
				instances.append({"uid": "legacy_%s_%d" % [employee_id, instances.size()], "augment_id": augment_id})
				ids.append(augment_id)
		if not instances.is_empty():
			equipped_instances[employee_id] = instances
			equipped_augments[employee_id] = ids
	_effect_engine = EFFECT_ENGINE_SCRIPT.new()
	temporary_effects.clear()
	event_log.clear()
	_pending_root_events.clear()
	_chain_activations.clear()
	_next_chain_id = 1
	_next_event_id = 1
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
			"busy_ticks": 0.0, "idle_ticks": 0.0, "break_ticks": 0.0,
			"stamina_remaining_seconds": roster.stamina_hours(employee_id) * EmployeeRoster.REAL_SECONDS_PER_GAME_HOUR,
			"break_remaining_seconds": 0.0, "break_completed": false, "breaks_taken": 0,
			"sales": 0, "revenue": 0,
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
	revenue = 0
	sale_log.clear()
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
	var floor_stats := _effective_floor_stats()
	for seat in active:
		var employee_id: String = employees[seat]
		var speed := float(floor_stats.get(employee_id, {}).get("speed", 0.0))
		if speed > 0.0:
			var progress: float = active[seat].get("progress", 0.0)
			deadline = minf(deadline, elapsed_seconds + maxf(0.0, 1.0 - progress) * 18.0 / speed)
	for lead in waiting:
		deadline = minf(deadline, _patience_deadline(lead))
	for employee_id in employee_stats:
		var break_remaining := float(employee_stats[employee_id]["break_remaining_seconds"])
		if break_remaining > TIME_EPSILON:
			deadline = minf(deadline, elapsed_seconds + break_remaining)
	for effect: Dictionary in temporary_effects:
		if float(effect.get("expires_at", INF)) < INF:
			deadline = minf(deadline, float(effect["expires_at"]))
	return maxf(0.0, deadline - elapsed_seconds)


func _account_interval(seconds: float) -> void:
	var ticks := seconds / TICK_SECONDS
	var floor_stats := _effective_floor_stats()
	for seat in employees.size():
		if employees[seat].is_empty():
			continue
		var stats: Dictionary = employee_stats[employees[seat]]
		if active.has(seat):
			stats["busy_ticks"] += ticks
			stats["stamina_remaining_seconds"] = maxf(0.0, float(stats["stamina_remaining_seconds"]) - seconds)
			var speed := float(floor_stats.get(employees[seat], {}).get("speed", 0.0))
			var active_lead: Dictionary = active[seat]
			active_lead["progress"] = minf(1.0, float(active_lead.get("progress", 0.0)) + speed / 18.0 * seconds)
			active_lead["remaining"] = 0.0 if speed <= 0.0 else maxf(
				0.0, (1.0 - float(active_lead["progress"])) * 18.0 / speed / TICK_SECONDS
			)
		elif float(stats["break_remaining_seconds"]) > TIME_EPSILON:
			stats["break_ticks"] += ticks
			stats["break_remaining_seconds"] = maxf(0.0, float(stats["break_remaining_seconds"]) - seconds)
			if float(stats["break_remaining_seconds"]) <= TIME_EPSILON:
				stats["break_completed"] = true
		else:
			stats["idle_ticks"] += ticks
	_expire_temporary_effects()


func _resolve_events() -> void:
	# Natural completions at one timestamp share the same pre-outcome stats.
	var ready_seats: Array[int] = []
	for seat in employees.size():
		if active.has(seat) and float(active[seat].get("progress", 0.0)) >= 1.0 - TIME_EPSILON:
			ready_seats.append(seat)
	if not ready_seats.is_empty():
		_pending_root_events.append_array(_complete_calls(ready_seats, _effective_floor_stats(), {}, true))

	# A completed break restores the full continuous-calling allowance.
	for employee_id in employee_stats:
		var stats: Dictionary = employee_stats[employee_id]
		if bool(stats["break_completed"]):
			stats["break_remaining_seconds"] = 0.0
			stats["break_completed"] = false
			stats["stamina_remaining_seconds"] = roster.stamina_hours(employee_id) * EmployeeRoster.REAL_SECONDS_PER_GAME_HOUR

	# A waiting lead leaves at its deadline, including a tie with a completion.
	# Filter every lead, preserving the relative FIFO order of survivors.
	var survivors: Array[Dictionary] = []
	for lead in waiting:
		if _patience_deadline(lead) <= elapsed_seconds + TIME_EPSILON:
			abandoned += 1
			abandoned_this_tick.append(lead.duplicate(true))
		else:
			survivors.append(lead)
	waiting.assign(survivors)

	if next_arrival_seconds <= elapsed_seconds + TIME_EPSILON:
		_enqueue_call()
		next_arrival_seconds += _arrival_delay()
	_dispatch_waiting()
	while true:
		if not _pending_root_events.is_empty():
			var roots := _pending_root_events.duplicate(true)
			_pending_root_events.clear()
			_process_event_waves(roots)
		_dispatch_waiting()
		if _pending_root_events.is_empty():
			break


func _complete_calls(
		seats: Array[int],
		stats_snapshot: Dictionary,
		causal_chains_by_seat: Dictionary,
		natural_roots: bool,
		causal_parents_by_seat: Dictionary = {}
	) -> Array[Dictionary]:
	var outcome_events: Array[Dictionary] = []
	var sales_to_settle: Array[Dictionary] = []
	for seat in seats:
		if not active.has(seat):
			continue
		var employee_id: String = employees[seat]
		var stats: Dictionary = employee_stats[employee_id]
		var lead: Dictionary = active[seat]
		var is_recovery: bool = lead.get("recovery", false)
		if not is_recovery:
			handled += 1
		stats["handled"] += 1
		var effective: Dictionary = stats_snapshot.get(employee_id, {})
		lead["progress"] = 1.0
		lead["sold"] = _makes_sale(employee_id, lead, effective)
		lead["upsold"] = false
		if lead["sold"]:
			var payout := int(lead["value"])
			if _rolls_upsell(employee_id, effective):
				lead["upsold"] = true
				payout = roundi(payout * float(effective.get("upsell_multiplier", 1.0)))
			lead["payout"] = payout
			sales += 1
			if is_recovery:
				recovered += 1
				recovered_revenue += payout
			else:
				normal_sales += 1
			revenue += payout
			var sale_record := {
				"id": lead["id"],
				"value": payout,
				"employee_id": employee_id,
				"recovery": is_recovery,
				"timestamp": elapsed_seconds,
			}
			sale_log.append(sale_record)
			sales_to_settle.append(sale_record)
			stats["sales"] += 1
			stats["revenue"] += payout
		else:
			if is_recovery:
				failed_recoveries += 1
			else:
				failed_interactions += 1
		completed_this_tick[seat] = lead.duplicate(true)
		active.erase(seat)
		if not lead["sold"] and not is_recovery:
			discard_lead(lead)
		if float(stats["stamina_remaining_seconds"]) <= TIME_EPSILON:
			stats["break_remaining_seconds"] = BREAK_SECONDS
			stats["breaks_taken"] += 1
		_expire_next_call_effects(employee_id)
		var chains: Array[int] = []
		chains.assign(causal_chains_by_seat.get(seat, []))
		if natural_roots or chains.is_empty():
			chains = [_next_chain_id]
			_next_chain_id += 1
		var parents: Array[int] = []
		parents.assign(causal_parents_by_seat.get(seat, []))
		var outcome_event := _make_event(
			"conversion" if lead["sold"] else "failure", employee_id, seat, lead, chains,
			0 if parents.is_empty() else parents[0]
		)
		if lead["sold"]:
			sale_log.back()["event_id"] = int(outcome_event["event_id"])
			sales_to_settle.back()["event_id"] = int(outcome_event["event_id"])
		outcome_events.append(outcome_event)
		var followup_trigger := "upsell" if lead["upsold"] else "call_completed_without_upsell"
		outcome_events.append(_make_event(
			followup_trigger, employee_id, seat, lead, chains, int(outcome_event["event_id"])
		))
	for sale: Dictionary in sales_to_settle:
		if sale_settlement_callback.is_valid():
			sale_settlement_callback.call(sale)
	return outcome_events


func _process_event_waves(initial_events: Array[Dictionary]) -> void:
	var wave := initial_events
	while not wave.is_empty():
		var operations: Array[Dictionary] = []
		for event: Dictionary in wave:
			event_log.append(event.duplicate(true))
			for chain_id in event["chain_ids"]:
				var activations: Array[Dictionary] = _effect_engine.trigger_effects(
					event["type"], employees, equipped_instances, _chain_activations,
					int(chain_id), positions, _financial_context()
				)
				for activation in activations:
					activation["event_id"] = event["event_id"]
					operations.append(activation)
		wave = _apply_effect_batch(operations)


func _apply_effect_batch(operations: Array[Dictionary]) -> Array[Dictionary]:
	var progress_deltas := {}
	var progress_chains := {}
	var progress_parents := {}
	var progress_transfers := {}
	var progress_snapshot := {}
	for seat in active:
		progress_snapshot[seat] = float(active[seat].get("progress", 0.0))
	for operation: Dictionary in operations:
		var effect: Dictionary = operation["effect"]
		var effect_type: String = effect.get("type", "")
		var target_ids := _effect_targets(operation, str(effect.get("selector", "self")))
		match effect_type:
			"call_progress":
				for employee_id in target_ids:
					var seat := _seat_for_employee(employee_id)
					if seat == -1 or not active.has(seat):
						continue
					progress_deltas[seat] = float(progress_deltas.get(seat, 0.0)) + float(effect.get("value", 0.0))
					_add_causal_chain(progress_chains, seat, int(operation["chain_id"]))
					_add_parent_event(progress_parents, seat, int(operation["event_id"]))
					_log_effect(operation, employee_id, float(effect.get("value", 0.0)))
			"progress_transfer":
				_collect_progress_transfer(operation, progress_transfers, progress_snapshot)
			"stat_buff":
				for employee_id in target_ids:
					_add_temporary_effect(employee_id, effect, operation)
					_log_effect(operation, employee_id, float(effect.get("value", 0.0)))
			"cash_effect":
				var action: String = str(effect.get("action", "penalty"))
				var progress_targets: Array[String] = []
				if action == "spend_for_progress":
					for employee_id in target_ids:
						var target_seat := _seat_for_employee(employee_id)
						if target_seat >= 0 and active.has(target_seat):
							progress_targets.append(employee_id)
					if progress_targets.is_empty():
						continue
				var requested := maxi(roundi(float(effect.get("value", 0.0))), 0)
				var cash_action := "spend" if action == "spend_for_progress" else action
				var applied := 0
				if cash_effect_callback.is_valid():
					applied = int(cash_effect_callback.call(
						cash_action, requested, str(operation["employee_id"]),
						str(operation["augment_id"]), elapsed_seconds, int(operation["event_id"])
					))
				else:
					push_error("A cash-effect augment fired without a ledger callback.")
				_log_effect(operation, str(operation["employee_id"]),
					float(applied) if action == "grant" else -float(applied))
				if action == "spend_for_progress" and requested > 0:
					for employee_id in progress_targets:
						var seat := _seat_for_employee(employee_id)
						var delta := float(applied) * float(effect.get("progress_per_dollar", 0.0))
						progress_deltas[seat] = float(progress_deltas.get(seat, 0.0)) + delta
						_add_causal_chain(progress_chains, seat, int(operation["chain_id"]))
						_add_parent_event(progress_parents, seat, int(operation["event_id"]))
						_log_effect(operation, employee_id, delta)
	for source_seat in progress_transfers:
		var requests: Array[Dictionary] = []
		requests.assign(progress_transfers[source_seat])
		var total_requested := 0.0
		for request: Dictionary in requests:
			total_requested += float(request["requested"])
		var available: float = progress_snapshot[source_seat]
		var scale := minf(1.0, available / total_requested) if total_requested > 0.0 else 0.0
		for request: Dictionary in requests:
			var amount := float(request["requested"]) * scale
			var holder_seat: int = request["holder_seat"]
			progress_deltas[source_seat] = float(progress_deltas.get(source_seat, 0.0)) - amount
			progress_deltas[holder_seat] = float(progress_deltas.get(holder_seat, 0.0)) + amount
			_add_causal_chain(progress_chains, source_seat, int(request["chain_id"]))
			_add_causal_chain(progress_chains, holder_seat, int(request["chain_id"]))
			_add_parent_event(progress_parents, source_seat, int(request["event_id"]))
			_add_parent_event(progress_parents, holder_seat, int(request["event_id"]))
			_log_effect(request["operation"], employees[source_seat], -amount)
			_log_effect(request["operation"], employees[holder_seat], amount)
	var newly_completed: Array[int] = []
	for seat in progress_deltas:
		if not active.has(seat):
			continue
		var active_lead: Dictionary = active[seat]
		var old_progress := float(active_lead.get("progress", 0.0))
		active_lead["progress"] = clampf(old_progress + float(progress_deltas[seat]), 0.0, 1.0)
		var speed := float(_effective_floor_stats().get(employees[seat], {}).get("speed", 0.0))
		active_lead["remaining"] = 0.0 if speed <= 0.0 else maxf(
			0.0, (1.0 - float(active_lead["progress"])) * 18.0 / speed / TICK_SECONDS
		)
		if float(active_lead["progress"]) >= 1.0 and old_progress < 1.0:
			newly_completed.append(int(seat))
	if newly_completed.is_empty():
		return []
	return _complete_calls(newly_completed, _effective_floor_stats(), progress_chains, false, progress_parents)


func _collect_progress_transfer(
		operation: Dictionary,
		requests_by_source: Dictionary,
		progress_snapshot: Dictionary
	) -> void:
	var effect: Dictionary = operation["effect"]
	var holder_seat: int = operation["seat"]
	if holder_seat < 0 or not active.has(holder_seat):
		return
	for target_id in _effect_targets(operation, str(effect.get("selector", "adjacent"))):
		var source_seat := _seat_for_employee(target_id)
		if source_seat == -1 or not active.has(source_seat):
			continue
		var available: float = progress_snapshot[source_seat]
		var requested := minf(available, maxf(0.0, float(effect.get("value", 0.0))))
		if requested <= 0.0:
			continue
		if not requests_by_source.has(source_seat):
			requests_by_source[source_seat] = []
		requests_by_source[source_seat].append({
			"requested": requested,
			"holder_seat": holder_seat,
			"chain_id": operation["chain_id"],
			"event_id": operation["event_id"],
			"operation": operation,
		})


func _effect_targets(operation: Dictionary, selector: String) -> Array[String]:
	var employee_id: String = operation["employee_id"]
	var seat: int = int(operation["seat"])
	if selector == "self":
		return [employee_id]
	return GridSelector.select(selector, seat, employees)


func _add_causal_chain(chains_by_seat: Dictionary, seat: int, chain_id: int) -> void:
	if not chains_by_seat.has(seat):
		chains_by_seat[seat] = []
	if not chains_by_seat[seat].has(chain_id):
		chains_by_seat[seat].append(chain_id)
		chains_by_seat[seat].sort()


func _add_parent_event(parents_by_seat: Dictionary, seat: int, event_id: int) -> void:
	if not parents_by_seat.has(seat):
		parents_by_seat[seat] = []
	if not parents_by_seat[seat].has(event_id):
		parents_by_seat[seat].append(event_id)
		parents_by_seat[seat].sort()


func _add_temporary_effect(employee_id: String, effect: Dictionary, operation: Dictionary) -> void:
	var duration: String = effect.get("duration", "")
	if duration not in ["timed", "until_end_of_workday", "next_call"]:
		return
	var expires_at: float = elapsed_seconds + float(effect.get("seconds", 0.0)) if duration == "timed" else INF
	temporary_effects.append({
		"employee_id": employee_id,
		"stat": effect.get("stat", ""),
		"value": float(effect.get("value", 0.0)),
		"duration": duration,
		"expires_at": expires_at,
		"source_instance_id": operation["instance_id"],
		"chain_id": operation["chain_id"],
		"stacking": effect.get("stacking", "additive"),
	})


func _expire_temporary_effects() -> void:
	var remaining: Array[Dictionary] = []
	for effect in temporary_effects:
		if float(effect.get("expires_at", INF)) <= elapsed_seconds + TIME_EPSILON:
			event_log.append({"type": "effect_expired", "source_instance_id": effect.get("source_instance_id", "")})
		else:
			remaining.append(effect)
	temporary_effects.assign(remaining)


func _expire_next_call_effects(employee_id: String) -> void:
	var remaining: Array[Dictionary] = []
	for effect in temporary_effects:
		if effect.get("employee_id", "") == employee_id and effect.get("duration", "") == "next_call":
			continue
		remaining.append(effect)
	temporary_effects.assign(remaining)


func _effective_floor_stats() -> Dictionary:
	return _effect_engine.resolve_floor_stats(
		roster, equipped_instances, positions, active, temporary_effects, _financial_context()
	)


func _financial_context() -> Dictionary:
	if not financial_context_provider.is_valid():
		return {}
	var value: Variant = financial_context_provider.call()
	return value if value is Dictionary else {}


func _seat_for_employee(employee_id: String) -> int:
	return employees.find(employee_id)


func _make_event(
		trigger: String,
		employee_id: String,
		seat: int,
		lead: Dictionary,
		chains: Array[int],
		parent_event_id: int = 0
	) -> Dictionary:
	var event := {
		"event_id": _next_event_id,
		"parent_event_id": parent_event_id,
		"timestamp": elapsed_seconds,
		"type": trigger,
		"employee_id": employee_id,
		"seat": seat,
		"call_id": int(lead.get("id", -1)),
		"chain_ids": chains.duplicate(),
	}
	_next_event_id += 1
	return event


func _log_effect(operation: Dictionary, target_id: String, value: float) -> void:
	event_log.append({
		"type": "augment_effect",
		"event_id": operation["event_id"],
		"parent_event_id": operation["event_id"],
		"chain_id": operation["chain_id"],
		"augment_instance_id": operation["instance_id"],
		"augment_id": operation["augment_id"],
		"target": target_id,
		"effect": operation["effect"].get("type", ""),
		"value": value,
		"timestamp": elapsed_seconds,
	})


func receive_call() -> void:
	_enqueue_call()
	_dispatch_waiting()
	if not _pending_root_events.is_empty():
		var roots := _pending_root_events.duplicate(true)
		_pending_root_events.clear()
		_process_event_waves(roots)


func discard_lead(lead: Dictionary) -> void:
	for discarded_call in lead_discard_pile:
		assert(discarded_call["id"] != lead["id"], "A lead may only enter the discard pile once.")
	lead_discard_pile.append(lead)
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


func _patience_deadline(lead: Dictionary) -> float:
	return (float(lead["arrived_tick"]) + float(lead["patience_ticks"])) * TICK_SECONDS


func _dispatch_waiting() -> void:
	# Normal sales representatives only take incoming leads; Recyclers never do.
	var takes_incoming := func(employee_id: String) -> bool: return not roster.is_recycler(employee_id) and not is_on_break(employee_id)
	while not waiting.is_empty():
		var seat := ASSIGNMENT.next_available_seat(employees, active, takes_incoming)
		if seat == -1:
			break
		var lead: Dictionary = waiting.pop_front()
		lead["employee_id"] = employees[seat]
		lead["seat"] = seat
		var speed := float(_effective_floor_stats().get(employees[seat], {}).get("speed", 0.0))
		lead["duration"] = INF if speed <= 0.0 else 18.0 / speed / TICK_SECONDS
		lead["remaining"] = lead["duration"]
		lead["progress"] = 0.0
		active[seat] = lead
		employee_stats[employees[seat]]["assigned"] += 1
		assigned_this_tick.append(lead.duplicate(true))
		last_dispatch = "Call #%03d → Seat %02d" % [lead["id"], seat + 1]
		_queue_root_event("call_started", employees[seat], seat, lead)
	_dispatch_recoveries()


# Recyclers claim leads from the discard pile in slot order. The lead leaves the
# pile immediately, which guarantees a single recovery attempt.
func _dispatch_recoveries() -> void:
	var takes_discards := func(employee_id: String) -> bool: return roster.is_recycler(employee_id) and not is_on_break(employee_id)
	while not lead_discard_pile.is_empty():
		var seat := ASSIGNMENT.next_available_seat(employees, active, takes_discards)
		if seat == -1:
			break
		var lead := take_discarded_lead()
		lead.erase("sold")
		lead.erase("upsold")
		lead.erase("payout")
		lead["recovery"] = true
		lead["employee_id"] = employees[seat]
		lead["seat"] = seat
		var speed := float(_effective_floor_stats().get(employees[seat], {}).get("speed", 0.0))
		lead["duration"] = INF if speed <= 0.0 else 18.0 / speed / TICK_SECONDS
		lead["remaining"] = lead["duration"]
		lead["progress"] = 0.0
		active[seat] = lead
		recovery_attempts += 1
		employee_stats[employees[seat]]["assigned"] += 1
		assigned_this_tick.append(lead.duplicate(true))
		last_dispatch = "Discard #%03d → Seat %02d" % [lead["id"], seat + 1]
		_queue_root_event("call_started", employees[seat], seat, lead)


func employee_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for employee_id in employees:
		if not employee_id.is_empty():
			results.append(employee_stats[employee_id].duplicate(true))
	return results


func is_on_break(employee_id: String) -> bool:
	return employee_stats.has(employee_id) and float(employee_stats[employee_id]["break_remaining_seconds"]) > TIME_EPSILON


func effective_stats_snapshot() -> Dictionary:
	return _effective_floor_stats()


# Base stats affect handling only. Future conditional behaviors can extend these
# hooks while intake continues to use fixed slot priority.
func _handling_ticks(employee_id: String, _lead: Dictionary) -> float:
	var loadout: Array[String] = []
	loadout.assign(equipped_augments.get(employee_id, []))
	if loadout.is_empty():
		return roster.handling_seconds(employee_id) / TICK_SECONDS
	return roster.handling_seconds_with_augments(employee_id, loadout) / TICK_SECONDS


func _rolls_upsell(employee_id: String, effective_stats: Dictionary = {}) -> bool:
	var roll := _upsell_rng.randf()
	var stats: Dictionary = effective_stats \
		if not effective_stats.is_empty() else _effective_floor_stats().get(employee_id, {})
	var chance := clampf(float(stats.get("upsell_chance", 0.0)) / 100.0, 0.0, 1.0)
	return roll < chance


func _makes_sale(employee_id: String, _lead: Dictionary, effective_stats: Dictionary = {}) -> bool:
	var roll := _conversion_rng.randf()
	var stats: Dictionary = effective_stats \
		if not effective_stats.is_empty() else _effective_floor_stats().get(employee_id, {})
	var chance := clampf(float(stats.get("conversion", 0.0)) / 100.0, 0.0, 1.0)
	return roll < chance


func _queue_root_event(trigger: String, employee_id: String, seat: int, lead: Dictionary) -> void:
	var chain_id := _next_chain_id
	_next_chain_id += 1
	_pending_root_events.append(_make_event(trigger, employee_id, seat, lead, [chain_id]))
