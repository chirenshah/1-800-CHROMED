extends RefCounted
class_name AugmentEffectEngine

const CATALOG: AugmentCatalog = preload("res://data/augment_catalog.tres")

var debug_trace: Array[Dictionary] = []
var catalog: AugmentCatalog = CATALOG


func resolve_stats(
		roster: EmployeeRoster,
		employee_id: String,
		loadouts: Dictionary,
		positions: Dictionary = {},
		_active_calls: Dictionary = {},
		temporary_effects: Array[Dictionary] = [],
		resolve_dependencies := true,
		financial_context: Dictionary = {}
	) -> Dictionary:
	var employee := roster.profile(employee_id)
	if employee.is_empty():
		return {}
	var stats := {
		"speed": maxf(0.0, float(employee.get("speed", 0.0))),
		"conversion": maxf(0.0, float(employee.get("conversion", 0.0))),
		"upsell_chance": maxf(0.0, float(employee.get("upsell_chance", 0.0))),
		"upsell_multiplier": maxf(0.0, float(employee.get("upsell_multiplier", 1.0))),
		"daily_upkeep": maxf(
			0.0, float(employee.get("daily_upkeep", EmployeeRoster.DEFAULT_DAILY_UPKEEP))
		),
	}
	var flat_adds := {}
	var percent_adds := {}
	for stat in stats:
		flat_adds[stat] = 0.0
		percent_adds[stat] = 0.0
	var derived_edges: Array[Dictionary] = []
	var position_overrides: Array[Dictionary] = []
	var conditional_effects: Array[Dictionary] = []
	var installed: Array = loadouts.get(employee_id, [])
	for instance in installed:
		var augment := catalog.profile(_augment_id(instance))
		if augment.is_empty():
			continue
		for effect: Dictionary in _effects(augment):
			if not _condition_met(effect, stats, financial_context):
				continue
			var effect_type: String = effect.get("type", "")
			var stat: String = effect.get("stat", "")
			match effect_type:
				"stat_add":
					if flat_adds.has(stat):
						flat_adds[stat] += float(effect.get("value", 0.0))
				"stat_percent":
					if percent_adds.has(stat):
						percent_adds[stat] += float(effect.get("value", 0.0))
				"cash_scaled_stat":
					if flat_adds.has(stat):
						var input_name: String = str(effect.get("input", "company_cash"))
						var input_value := float(
							financial_context.get(input_name, stats.get(input_name, 0.0))
						)
						flat_adds[stat] += input_value * float(effect.get("coefficient", 0.0))
				"derived_stat":
					derived_edges.append({
						"source": "%s:%s" % [employee_id, effect.get("source_stat", "")],
						"target": "%s:%s" % [employee_id, effect.get("target_stat", "")],
						"coefficient": float(effect.get("coefficient", 1.0)),
						"instance_id": _instance_id(instance),
					})
				"position_stat":
					position_overrides.append(effect)
				"conditional_stat":
					var conditional := effect.duplicate(true)
					conditional["_instance_id"] = _instance_id(instance)
					conditional_effects.append(conditional)
				"steal_stat_percent", "steal_stat_points":
					pass
	for stat in stats:
		stats[stat] += flat_adds[stat] + float(employee.get(stat, 0.0)) * percent_adds[stat]
	_apply_conditional_stats(stats, conditional_effects, financial_context)
	for effect in position_overrides:
		var seat := int(positions.get(employee_id, -1))
		var values: Array = effect.get("values", [])
		if seat >= 0 and seat < values.size():
			stats[effect.get("stat", "speed")] = float(values[seat])

	for effect in temporary_effects:
		if effect.get("employee_id", "") == employee_id and stats.has(effect.get("stat", "")):
			stats[effect["stat"]] += float(effect.get("value", 0.0))
	if resolve_dependencies:
		_resolve_derived_stats(stats, employee_id, derived_edges)
	for stat in stats:
		stats[stat] = maxf(0.0, float(stats[stat]))
	return stats


func resolve_floor_stats(
		roster: EmployeeRoster,
		loadouts: Dictionary,
		positions: Dictionary,
		active_calls: Dictionary,
		temporary_effects: Array[Dictionary] = [],
		financial_context: Dictionary = {}
	) -> Dictionary:
	debug_trace.clear()
	var floor_stats := {}
	var employee_ids: Array[String] = []
	for employee_id: String in loadouts:
		employee_ids.append(employee_id)
	for employee_id: String in positions:
		if not employee_ids.has(employee_id):
			employee_ids.append(employee_id)
	employee_ids.sort()
	for employee_id in employee_ids:
		floor_stats[employee_id] = resolve_stats(
			roster, employee_id, loadouts, positions, active_calls, temporary_effects, true,
			financial_context
		)
	var transfer_deltas := _calculate_floor_transfers(
		floor_stats, loadouts, positions, financial_context
	)
	if not transfer_deltas.is_empty():
		for employee_id in employee_ids:
			floor_stats[employee_id] = resolve_stats(
				roster, employee_id, loadouts, positions, active_calls, temporary_effects, false,
				financial_context
			)
		for key: String in transfer_deltas:
			var employee_id: String = key.get_slice(":", 0)
			var stat: String = key.get_slice(":", 1)
			if floor_stats.has(employee_id) and floor_stats[employee_id].has(stat):
				floor_stats[employee_id][stat] += float(transfer_deltas[key])
		for employee_id in employee_ids:
			_resolve_derived_stats(
				floor_stats[employee_id], employee_id,
				_derived_edges_for(employee_id, loadouts, financial_context, floor_stats[employee_id])
			)
	for employee_id in floor_stats:
		for stat in floor_stats[employee_id]:
			floor_stats[employee_id][stat] = maxf(0.0, float(floor_stats[employee_id][stat]))
	return floor_stats


func _derived_edges_for(
		employee_id: String,
		loadouts: Dictionary,
		financial_context: Dictionary,
		stats: Dictionary
	) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for instance in loadouts.get(employee_id, []):
		var augment := catalog.profile(_augment_id(instance))
		for effect: Dictionary in _effects(augment):
			if effect.get("type", "") == "derived_stat" \
				and _condition_met(effect, stats, financial_context):
				edges.append({
					"source": "%s:%s" % [employee_id, effect.get("source_stat", "")],
					"target": "%s:%s" % [employee_id, effect.get("target_stat", "")],
					"coefficient": float(effect.get("coefficient", 1.0)),
					"instance_id": _instance_id(instance),
				})
	return edges


func _resolve_derived_stats(stats: Dictionary, employee_id: String, edges: Array[Dictionary]) -> void:
	var base_snapshot := stats.duplicate(true)
	var node_names: Array[String] = []
	for stat in stats:
		node_names.append("%s:%s" % [employee_id, stat])
	var graph := {}
	for node in node_names:
		graph[node] = []
	for edge in edges:
		if graph.has(edge["source"]) and graph.has(edge["target"]):
			graph[edge["source"]].append(edge["target"])
	var cyclic_edges := {}
	for edge_index in edges.size():
		var edge: Dictionary = edges[edge_index]
		if _reachable(graph, edge["target"], edge["source"]):
			cyclic_edges[edge_index] = true
		debug_trace.append({
			"type": "derived_stat",
			"source": edge["source"],
			"target": edge["target"],
			"coefficient": edge["coefficient"],
			"cycle_snapshot": cyclic_edges.has(edge_index),
		})
	var incoming := {}
	for edge_index in edges.size():
		var edge: Dictionary = edges[edge_index]
		if not incoming.has(edge["target"]):
			incoming[edge["target"]] = []
		incoming[edge["target"]].append(edge_index)
	var resolving := {}
	var resolved := {}
	var resolve_node := func(node: String) -> float: return _resolve_stat_node(
		node, edges, incoming, cyclic_edges, base_snapshot, stats, resolving, resolved
	)
	for node in node_names:
		resolve_node.call(node)


func _resolve_stat_node(
		node: String,
		edges: Array[Dictionary],
		incoming: Dictionary,
		cyclic_edges: Dictionary,
		base_snapshot: Dictionary,
		stats: Dictionary,
		resolving: Dictionary,
		resolved: Dictionary
	) -> float:
	var stat := node.get_slice(":", 1)
	if resolved.has(node):
		return float(stats[stat])
	if resolving.has(node):
		return float(base_snapshot[stat])
	resolving[node] = true
	var value := float(base_snapshot[stat])
	for edge_index in incoming.get(node, []):
		var edge: Dictionary = edges[edge_index]
		var source_stat: String = str(edge["source"]).get_slice(":", 1)
		var source_value := float(base_snapshot[source_stat])
		if not cyclic_edges.has(edge_index):
			source_value = _resolve_stat_node(
				edge["source"], edges, incoming, cyclic_edges, base_snapshot, stats, resolving, resolved
			)
		value += source_value * float(edge["coefficient"])
	resolving.erase(node)
	stats[stat] = value
	resolved[node] = true
	return value


func _reachable(graph: Dictionary, from_node: String, to_node: String) -> bool:
	var pending: Array[String] = [from_node]
	var visited := {}
	while not pending.is_empty():
		var node: String = pending.pop_front()
		if node == to_node:
			return true
		if visited.has(node):
			continue
		visited[node] = true
		for neighbor: String in graph.get(node, []):
			pending.append(neighbor)
	return false


func _condition_met(effect: Dictionary, stats: Dictionary, financial_context: Dictionary) -> bool:
	var condition: Variant = effect.get("condition", {})
	if not condition is Dictionary or condition.is_empty():
		return true
	var input_name: String = str(condition.get("input", "company_cash"))
	var value := float(financial_context.get(input_name, stats.get(input_name, 0.0)))
	var threshold := float(condition.get("value", 0.0))
	match condition.get("operator", "lt"):
		"lt":
			return value < threshold
		"lte":
			return value <= threshold
		"gt":
			return value > threshold
		"gte":
			return value >= threshold
		"eq":
			return is_equal_approx(value, threshold)
		"neq":
			return not is_equal_approx(value, threshold)
	return false


func _apply_conditional_stats(
		stats: Dictionary,
		effects: Array[Dictionary],
		financial_context: Dictionary
	) -> void:
	var additions := {}
	var multipliers := {}
	var assignments := {}
	for stat in stats:
		additions[stat] = 0.0
		multipliers[stat] = 1.0
	for effect in effects:
		var stat: String = effect.get("stat", "")
		if not stats.has(stat) or not _condition_met(effect, stats, financial_context):
			continue
		var operation: String = effect.get("operation", "add")
		var value := float(effect.get("value", 0.0))
		match operation:
			"add":
				additions[stat] += value
			"multiply":
				multipliers[stat] *= value
			"set":
				var source_id: String = effect.get("_instance_id", "")
				var existing: Dictionary = assignments.get(stat, {})
				if existing.is_empty() or source_id < str(existing.get("_instance_id", "")):
					assignments[stat] = effect
			_:
				push_error("Unknown conditional stat operation: " + operation)
	for stat in stats:
		stats[stat] = (float(stats[stat]) + float(additions[stat])) * float(multipliers[stat])
	for stat: String in assignments:
		stats[stat] = float(assignments[stat].get("value", 0.0))


func _calculate_floor_transfers(
		floor_stats: Dictionary,
		loadouts: Dictionary,
		positions: Dictionary,
		financial_context: Dictionary
	) -> Dictionary:
	var snapshot: Dictionary = floor_stats.duplicate(true)
	var deltas := {}
	for employee_id: String in loadouts:
		var source_seat := int(positions.get(employee_id, -1))
		if source_seat < 0:
			continue
		for instance in loadouts[employee_id]:
			var augment := catalog.profile(_augment_id(instance))
			for effect: Dictionary in _effects(augment):
				if not _condition_met(effect, snapshot[employee_id], financial_context):
					continue
				if effect.get("type", "") not in ["steal_stat_percent", "steal_stat_points"]:
					continue
				for target_id in GridSelector.select(str(effect.get("selector", "adjacent")), source_seat, _seat_occupants(positions)):
					var target_stats: Dictionary = snapshot.get(target_id, {})
					var stat: String = effect.get("stat", "")
					if not target_stats.has(stat):
						continue
					var available := maxf(0.0, float(target_stats[stat]))
					var request := available * float(effect.get("fraction", 0.0)) \
						if effect.get("type") == "steal_stat_percent" else float(effect.get("value", 0.0))
					request = minf(available, maxf(0.0, request))
					var key := "%s:%s" % [target_id, stat]
					if not deltas.has(key):
						deltas[key] = {"target": target_id, "stat": stat, "requested": 0.0, "thieves": []}
					deltas[key]["requested"] += request
					deltas[key]["thieves"].append({"employee_id": employee_id, "request": request})
	var applied_deltas := {}
	for key: String in deltas:
		var transfer_data: Dictionary = deltas[key]
		var source_stats: Dictionary = snapshot[transfer_data["target"]]
		var available := maxf(0.0, float(source_stats[transfer_data["stat"]]))
		var requested := float(transfer_data["requested"])
		var scale := minf(1.0, available / requested) if requested > 0.0 else 0.0
		var moved := 0.0
		for thief: Dictionary in transfer_data["thieves"]:
			var amount := float(thief["request"]) * scale
			moved += amount
			var thief_key: String = "%s:%s" % [thief["employee_id"], transfer_data["stat"]]
			applied_deltas[thief_key] = float(applied_deltas.get(thief_key, 0.0)) + amount
		var target_id: String = transfer_data["target"]
		var target_key: String = "%s:%s" % [target_id, transfer_data["stat"]]
		applied_deltas[target_key] = float(applied_deltas.get(target_key, 0.0)) - moved
		debug_trace.append({"type": "stat_transfer", "target": target_id, "stat": transfer_data["stat"], "lost": moved})
	return applied_deltas


func trigger_effects(
		trigger: String,
		employees: Array[String],
		loadouts: Dictionary,
		already_activated: Dictionary,
		chain_id: int,
		positions: Dictionary,
		financial_context: Dictionary = {}
	) -> Array[Dictionary]:
	var operations: Array[Dictionary] = []
	var employee_ids: Array[String] = []
	for employee_id: String in loadouts:
		if employees.has(employee_id):
			employee_ids.append(employee_id)
	employee_ids.sort()
	for employee_id in employee_ids:
		var seat := int(positions.get(employee_id, -1))
		for instance in loadouts[employee_id]:
			var augment := catalog.profile(_augment_id(instance))
			var instance_id := _instance_id(instance)
			if already_activated.get(instance_id, {}).get(chain_id, false):
				continue
			var matching_effects: Array[Dictionary] = []
			for effect: Dictionary in _effects(augment):
				if effect.get("trigger", "") == trigger \
					and _condition_met(effect, {}, financial_context):
					matching_effects.append(effect)
			if matching_effects.is_empty():
				continue
			if not already_activated.has(instance_id):
				already_activated[instance_id] = {}
			already_activated[instance_id][chain_id] = true
			for effect in matching_effects:
				operations.append({
					"employee_id": employee_id,
					"seat": seat,
					"instance_id": instance_id,
					"augment_id": augment.get("id", ""),
					"chain_id": chain_id,
					"effect": effect.duplicate(true),
				})
	return operations


func _effects(augment: Dictionary) -> Array:
	if augment.is_empty():
		return []
	if augment.has("effects"):
		return augment["effects"]
	var effects: Array[Dictionary] = []
	if augment.has("stat") and augment.has("bonus"):
		effects.append({
			"type": "stat_add" if augment["stat"] == "conversion" else "stat_percent",
			"stat": augment["stat"],
			"value": float(augment["bonus"]) if augment["stat"] == "conversion" else float(augment["bonus"]) / 100.0,
			"duration": "continuous",
			"stacking": "additive",
		})
	return effects


func _augment_id(instance: Variant) -> String:
	return str(instance.get("augment_id", "")) if instance is Dictionary else str(instance)


func _instance_id(instance: Variant) -> String:
	return str(instance.get("uid", "")) if instance is Dictionary else str(instance)


func _seat_occupants(positions: Dictionary) -> Array[String]:
	var seats: Array[String] = ["", "", "", "", "", "", "", "", ""]
	for employee_id: String in positions:
		var seat := int(positions[employee_id])
		if seat >= 0 and seat < seats.size():
			seats[seat] = employee_id
	return seats
