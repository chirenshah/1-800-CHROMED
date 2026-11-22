extends SceneTree
## Godot --headless --path . --script res://tests/test_augment_implementation.gd

const ROSTER_SCRIPT := preload("res://scripts/employee_roster.gd")
const ENGINE_SCRIPT := preload("res://scripts/augment_effect_engine.gd")
const CATALOG_SCRIPT := preload("res://scripts/augment_catalog.gd")
const MODEL_SCRIPT := preload("res://scripts/call_queue_simulation.gd")
const MANAGER_SCRIPT := preload("res://scripts/augment_manager.gd")
const GRID := preload("res://scripts/grid_selector.gd")

var failures: Array[String] = []
var _finance_test_ledger: FinancialLedger


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	_test_stat_resolution()
	_test_financial_stat_resolution()
	_test_steal_and_grid()
	_test_live_progress_and_batches()
	_test_event_chains()
	_test_financial_effects()
	_test_rewards_and_installation()
	if failures.is_empty():
		print("PASS: dynamic stats, proportional theft, live progress, cascades, and reward ownership.")
	quit(0 if failures.is_empty() else 1)


func _instance(uid: String, augment_id: String) -> Dictionary:
	return {"uid": uid, "augment_id": augment_id}


func _custom_catalog(definitions: Array[Dictionary]) -> AugmentCatalog:
	var catalog: AugmentCatalog = CATALOG_SCRIPT.new()
	catalog.augments = definitions
	return catalog


func _test_stat_resolution() -> void:
	var roster: EmployeeRoster = ROSTER_SCRIPT.new()
	roster.employees.append({
		"id": "rep", "speed": 4.0, "conversion": 95.0,
		"upsell_chance": 40.0, "upsell_multiplier": 1.5,
	})
	var engine: AugmentEffectEngine = ENGINE_SCRIPT.new()
	var loadouts := {
		"rep": [
			_instance("flat_a", "AUG_001"),
			_instance("flat_b", "AUG_001"),
			_instance("speed_a", "AUG_002"),
			_instance("speed_b", "AUG_002"),
			_instance("leech", "AUG_007"),
		],
	}
	var stats: Dictionary = engine.resolve_floor_stats(roster, loadouts, {"rep": 0}, {})
	_check(is_equal_approx(float(stats["rep"]["speed"]), 5.2),
		"Duplicate speed percentages stack additively and preserve fractional stats.")
	_check(is_equal_approx(float(stats["rep"]["conversion"]), 115.0)
		and is_equal_approx(float(stats["rep"]["upsell_chance"]), 155.0),
		"Uncapped modified Conversion feeds Conversion Leech at its full value.")
	var single_bonus: Dictionary = engine.resolve_floor_stats(
		roster, {"rep": [_instance("single", "AUG_001")]}, {"rep": 0}, {}
	)
	_check(is_equal_approx(float(single_bonus["rep"]["conversion"]), 105.0),
		"A legacy catalog stat bonus is applied once, not once per resolution path.")

	var cyclic_catalog := _custom_catalog([
		{"id": "cycle_conversion", "effects": [
			{"type": "derived_stat", "source_stat": "conversion", "target_stat": "upsell_chance", "coefficient": 0.5, "duration": "continuous"},
		]},
		{"id": "cycle_upsell", "effects": [
			{"type": "derived_stat", "source_stat": "upsell_chance", "target_stat": "conversion", "coefficient": 0.5, "duration": "continuous"},
			{"type": "derived_stat", "source_stat": "upsell_chance", "target_stat": "upsell_multiplier", "coefficient": 0.1, "duration": "continuous"},
		]},
	])
	engine.catalog = cyclic_catalog
	var forward: Dictionary = engine.resolve_floor_stats(roster, {
		"rep": [_instance("a", "cycle_conversion"), _instance("b", "cycle_upsell")],
	}, {"rep": 0}, {})
	var reverse: Dictionary = engine.resolve_floor_stats(roster, {
		"rep": [_instance("b", "cycle_upsell"), _instance("a", "cycle_conversion")],
	}, {"rep": 0}, {})
	_check(is_equal_approx(float(forward["rep"]["conversion"]), 115.0)
		and is_equal_approx(float(forward["rep"]["upsell_chance"]), 87.5)
		and is_equal_approx(float(forward["rep"]["upsell_multiplier"]), 10.25),
		"Cycles use a shared pre-cycle snapshot while downstream effects read the resolved cycle.")
	_check(forward == reverse, "Equip order must not affect cyclic stat results.")


func _test_steal_and_grid() -> void:
	var roster: EmployeeRoster = ROSTER_SCRIPT.new()
	roster.employees = [
		{"id": "left", "speed": 2.0, "conversion": 0.0},
		{"id": "victim", "speed": 4.0, "conversion": 0.0},
		{"id": "right", "speed": 2.0, "conversion": 0.0},
		{"id": "diagonal", "speed": 2.0, "conversion": 0.0},
	]
	var occupants: Array[String] = ["left", "victim", "right", "", "", "", "", "", "diagonal"]
	_check(GRID.select("adjacent", 1, occupants) == ["left", "right"],
		"Orthogonal adjacency includes only up, down, left, and right cells.")
	var catalog := _custom_catalog([
		{"id": "leech", "effects": [
			{"type": "steal_stat_percent", "stat": "speed", "selector": "adjacent", "fraction": 0.8, "duration": "continuous"},
		]},
	])
	var engine: AugmentEffectEngine = ENGINE_SCRIPT.new()
	engine.catalog = catalog
	var stats: Dictionary = engine.resolve_floor_stats(roster, {
		"left": [_instance("left-leech", "leech")],
		"victim": [],
		"right": [_instance("right-leech", "leech")],
		"diagonal": [],
	}, {"left": 0, "victim": 1, "right": 2, "diagonal": 8}, {})
	_check(is_equal_approx(float(stats["victim"]["speed"]), 0.0)
		and is_equal_approx(float(stats["left"]["speed"]), 4.0)
		and is_equal_approx(float(stats["right"]["speed"]), 4.0),
		"Contending thieves split the victim's available stat proportionally without creating value.")

	roster.employees = [
		{"id": "thief", "speed": 0.0, "conversion": 10.0, "upsell_chance": 10.0},
		{"id": "victim", "speed": 0.0, "conversion": 100.0, "upsell_chance": 10.0},
	]
	engine.catalog = _custom_catalog([
		{"id": "conversion_thief", "effects": [
			{"type": "steal_stat_percent", "stat": "conversion", "selector": "adjacent", "fraction": 0.5, "duration": "continuous"},
			{"type": "derived_stat", "source_stat": "conversion", "target_stat": "upsell_chance", "coefficient": 0.5, "duration": "continuous"},
		]},
	])
	stats = engine.resolve_floor_stats(roster, {
		"thief": [_instance("conversion-thief", "conversion_thief")],
		"victim": [],
	}, {"thief": 0, "victim": 1}, {})
	_check(is_equal_approx(float(stats["thief"]["conversion"]), 60.0)
		and is_equal_approx(float(stats["thief"]["upsell_chance"]), 40.0)
		and is_equal_approx(float(stats["victim"]["conversion"]), 50.0),
		"Derived stats recalculate from the post-transfer stat values.")


func _test_financial_stat_resolution() -> void:
	var roster: EmployeeRoster = ROSTER_SCRIPT.new()
	roster.employees = [
		{"id": "rep", "speed": 2.0, "conversion": 10.0, "upsell_multiplier": 1.5, "daily_upkeep": 100},
		{"id": "neighbor", "speed": 1.0, "conversion": 10.0, "upsell_multiplier": 1.0, "daily_upkeep": 100},
	]
	var engine: AugmentEffectEngine = ENGINE_SCRIPT.new()
	engine.catalog = _custom_catalog([
		{"id": "cash_reader", "effects": [
			{"type": "conditional_stat", "stat": "conversion", "operation": "add", "value": 30.0,
				"condition": {"input": "company_cash", "operator": "lt", "value": 500}, "duration": "continuous"},
			{"type": "cash_scaled_stat", "input": "company_cash", "stat": "speed", "coefficient": 0.001,
				"duration": "continuous"},
			{"type": "derived_stat", "source_stat": "daily_upkeep", "target_stat": "upsell_multiplier",
				"coefficient": 0.01, "duration": "continuous"},
		]},
		{"id": "parachute", "effects": [
			{"type": "conditional_stat", "stat": "daily_upkeep", "operation": "set", "value": 0.0,
				"condition": {"input": "company_cash", "operator": "lt", "value": 500}, "duration": "continuous"},
			{"type": "conditional_stat", "stat": "daily_upkeep", "operation": "multiply", "value": 3.0,
				"condition": {"input": "company_cash", "operator": "gte", "value": 500}, "duration": "continuous"},
		]},
		{"id": "upkeep_transfer", "effects": [
			{"type": "steal_stat_percent", "stat": "daily_upkeep", "selector": "adjacent",
				"fraction": 0.25, "duration": "continuous"},
		]},
	])
	var loadouts := {"rep": [_instance("cash-reader", "cash_reader")]}
	var low_cash: Dictionary = engine.resolve_floor_stats(
		roster, loadouts, {"rep": 0}, {}, [], {"company_cash": 499}
	)
	var threshold: Dictionary = engine.resolve_floor_stats(
		roster, loadouts, {"rep": 0}, {}, [], {"company_cash": 500}
	)
	_check(is_equal_approx(float(low_cash["rep"]["conversion"]), 40.0)
		and is_equal_approx(float(low_cash["rep"]["speed"]), 2.499)
		and is_equal_approx(float(threshold["rep"]["conversion"]), 10.0)
		and is_equal_approx(float(threshold["rep"]["speed"]), 2.5),
		"Cash thresholds and cash scaling recalculate from current cash without an equipment change.")
	_check(is_equal_approx(float(low_cash["rep"]["upsell_multiplier"]), 2.5),
		"Derived stats can read effective daily upkeep.")

	var low_upkeep: Dictionary = engine.resolve_floor_stats(
		roster, {"rep": [_instance("parachute", "parachute")]}, {"rep": 0}, {}, [],
		{"company_cash": 499}
	)
	var high_upkeep: Dictionary = engine.resolve_floor_stats(
		roster, {"rep": [_instance("parachute", "parachute")]}, {"rep": 0}, {}, [],
		{"company_cash": 500}
	)
	_check(is_equal_approx(float(low_upkeep["rep"]["daily_upkeep"]), 0.0)
		and is_equal_approx(float(high_upkeep["rep"]["daily_upkeep"]), 300.0),
		"Conditional upkeep has a zero floor and responds at the cash threshold.")

	var transferred: Dictionary = engine.resolve_floor_stats(roster, {
		"rep": [_instance("transfer", "upkeep_transfer")],
		"neighbor": [],
	}, {"rep": 0, "neighbor": 1}, {})
	_check(is_equal_approx(float(transferred["rep"]["daily_upkeep"]), 125.0)
		and is_equal_approx(float(transferred["neighbor"]["daily_upkeep"]), 75.0),
		"Position-based upkeep transfer preserves the total owed.")


func _test_live_progress_and_batches() -> void:
	var roster: EmployeeRoster = ROSTER_SCRIPT.new()
	roster.employees.append({"id": "seller", "speed": 3.0, "conversion": 100.0})
	var model: CallQueueSimulation = MODEL_SCRIPT.new()
	model.roster = roster
	model.reset(["seller"], 13)
	model.next_arrival_seconds = INF
	model.receive_call()
	model.advance(3.0)
	_check(is_equal_approx(float(model.active[0]["progress"]), 0.5),
		"Speed 3 advances a call by half over three seconds.")
	roster.employees[0]["speed"] = 6.0
	model.advance(1.49)
	_check(model.active.has(0), "Mid-call speed changes do not reset existing progress.")
	model.advance(0.02)
	_check(model.sales == 1, "The increased speed accelerates only the remaining call progress.")

	roster.employees[0]["speed"] = 0.0
	model.reset(["seller"], 14)
	model.next_arrival_seconds = INF
	model.receive_call()
	model.advance(1.0)
	_check(is_equal_approx(float(model.active[0]["progress"]), 0.0),
		"Speed zero pauses natural call progress.")
	model.active[0]["progress"] = 0.95
	var positive: Dictionary = _progress_operation("seller", 0, 0.1, 21)
	var operations: Array[Dictionary] = [positive]
	model._apply_effect_batch(operations)
	_check(model.sales == 1 and not model.active.has(0),
		"Direct progress can complete a call even when natural Speed is zero.")

	roster.employees.append({"id": "neighbor", "speed": 0.0, "conversion": 100.0})
	model.reset(["seller", "neighbor"], 15)
	model.next_arrival_seconds = INF
	model.receive_call()
	model.receive_call()
	model.active[1]["progress"] = 0.9
	operations = [
		_progress_operation("neighbor", 1, 0.2, 22),
		_progress_operation("neighbor", 1, -0.3, 23),
	]
	model._apply_effect_batch(operations)
	_check(is_equal_approx(float(model.active[1]["progress"]), 0.8)
		and model.sales == 0,
		"Simultaneous progress adjustments are summed before clamping or committing completion.")


func _test_event_chains() -> void:
	var roster: EmployeeRoster = ROSTER_SCRIPT.new()
	for employee_id in ["a", "b", "c", "up", "left", "listener", "target"]:
		roster.employees.append({"id": employee_id, "speed": 0.0, "conversion": 100.0})
	var model: CallQueueSimulation = MODEL_SCRIPT.new()
	model.roster = roster
	model.reset(["a", "b", "c"], 16, {
		"a": [_instance("relay-a", "AUG_008")],
		"b": [_instance("relay-b", "AUG_008")],
	})
	model.next_arrival_seconds = INF
	model.receive_call()
	model.receive_call()
	model.receive_call()
	model.active[1]["progress"] = 0.8
	model.active[2]["progress"] = 0.8
	var root_event: Dictionary = model._make_event("conversion", "a", 0, {"id": 100}, [42])
	var roots: Array[Dictionary] = [root_event]
	model._process_event_waves(roots)
	_check(model.sales == 2 and not model.active.has(1) and not model.active.has(2),
		"An A→B→C progress-triggered conversion cascade resolves without a depth limit.")

	model.reset(["a", "b", "c"], 17, {
		"a": [_instance("relay-copy-1", "AUG_008"), _instance("relay-copy-2", "AUG_008")],
	})
	model.next_arrival_seconds = INF
	model.receive_call()
	model.receive_call()
	model.active[1]["progress"] = 0.3
	root_event = model._make_event("conversion", "a", 0, {"id": 101}, [50])
	roots = [root_event]
	model._process_event_waves(roots)
	_check(is_equal_approx(float(model.active[1]["progress"]), 0.7),
		"Two installed copies activate independently in one chain and add 40 percentage points.")

	model.reset(["", "up", "", "left", "listener", "", "", "target", ""], 18, {
		"listener": [_instance("listener-relay", "AUG_008")],
	})
	model.next_arrival_seconds = INF
	model.active[7] = {"id": 200, "employee_id": "target", "progress": 0.3, "value": 100}
	var first_root: Dictionary = model._make_event("conversion", "up", 1, {"id": 201}, [60])
	var second_root: Dictionary = model._make_event("conversion", "left", 3, {"id": 202}, [61])
	roots = [first_root, second_root]
	model._process_event_waves(roots)
	_check(is_equal_approx(float(model.active[7]["progress"]), 0.7),
		"Independent same-time roots retain distinct chains and both activate the same listener.")
	model.reset(["", "up", "", "left", "listener", "", "", "target", ""], 19, {
		"listener": [_instance("listener-relay", "AUG_008")],
	})
	model.next_arrival_seconds = INF
	model.active[7] = {"id": 200, "employee_id": "target", "progress": 0.9, "value": 100}
	first_root = model._make_event("conversion", "up", 1, {"id": 201}, [70])
	second_root = model._make_event("conversion", "left", 3, {"id": 202}, [71])
	roots = [first_root, second_root]
	model._process_event_waves(roots)
	var joint_roots: Array = []
	for event: Dictionary in model.event_log:
		if event.get("type", "") == "conversion" and event.get("call_id", -1) == 200:
			joint_roots = event.get("chain_ids", [])
	_check(joint_roots == [70, 71],
		"A call jointly completed by independent roots carries their sorted union for downstream chains.")

	var effect_engine: AugmentEffectEngine = ENGINE_SCRIPT.new()
	effect_engine.catalog = _custom_catalog([{
		"id": "reserve_listener",
		"effects": [{
			"type": "stat_buff", "trigger": "failure", "selector": "self",
			"stat": "speed", "value": 1.0, "duration": "timed", "seconds": 3.0,
		}],
	}])
	var active_employees: Array[String] = ["active"]
	var reserve_operations: Array[Dictionary] = effect_engine.trigger_effects(
		"failure", active_employees, {"reserve": [_instance("reserve-listener", "reserve_listener")]},
		{}, 72, {}
	)
	_check(reserve_operations.is_empty(),
		"Employees outside the active floor lineup must not trigger their equipped augments.")


func _test_financial_effects() -> void:
	var roster: EmployeeRoster = ROSTER_SCRIPT.new()
	roster.employees = [
		{"id": "rep", "speed": 0.0, "conversion": 0.0, "upsell_chance": 0.0, "daily_upkeep": 100},
		{"id": "holder", "speed": 0.0, "conversion": 100.0, "daily_upkeep": 100},
		{"id": "target", "speed": 0.0, "conversion": 100.0, "daily_upkeep": 100},
	]
	var catalog := _custom_catalog([
		{"id": "illegal_firmware", "effects": [
			{"type": "cash_effect", "trigger": "failure", "action": "penalty", "value": 25,
				"duration": "instant", "stacking": "additive"},
		]},
		{"id": "liquidation", "effects": [
			{"type": "cash_effect", "trigger": "conversion", "selector": "adjacent",
				"action": "spend_for_progress", "value": 100, "progress_per_dollar": 0.001,
				"duration": "instant", "stacking": "additive"},
		]},
		{"id": "commission", "effects": [
			{"type": "cash_effect", "trigger": "upsell", "action": "grant", "value": 25,
				"duration": "instant", "stacking": "additive"},
			{"type": "cash_effect", "trigger": "call_completed_without_upsell",
				"action": "penalty", "value": 25, "duration": "instant", "stacking": "additive"},
		]},
	])
	_finance_test_ledger = FinancialLedger.new()
	_finance_test_ledger.company_cash = 10
	var model: CallQueueSimulation = MODEL_SCRIPT.new()
	model.roster = roster
	model.reset(["rep"], 29, {
		"rep": [_instance("illegal", "illegal_firmware")],
	})
	model._effect_engine.catalog = catalog
	model.cash_effect_callback = Callable(self, "_test_apply_financial_effect")
	model.financial_context_provider = Callable(self, "_test_financial_context")
	var failed_call := model._make_event("failure", "rep", 0, {"id": 700}, [70])
	model._process_event_waves([failed_call])
	_check(_finance_test_ledger.company_cash == 0
		and _finance_test_ledger.daily_sales_revenue == 0
		and _finance_test_ledger.upkeep_debt == 0
		and _finance_test_ledger.transactions.back()["requested_amount"] == 25
		and _finance_test_ledger.transactions.back()["applied_amount"] == 10,
		"Event-triggered cash penalties use the ledger, cap at available cash, and create no debt.")

	_finance_test_ledger = FinancialLedger.new()
	_finance_test_ledger.company_cash = 10
	_finance_test_ledger.reset_daily_revenue(30, 1000)
	model.reset(["rep"], 30, {
		"rep": [_instance("commission", "commission")],
	})
	model._effect_engine.catalog = catalog
	model.cash_effect_callback = Callable(self, "_test_apply_financial_effect")
	model.financial_context_provider = Callable(self, "_test_financial_context")
	model.sale_settlement_callback = Callable(self, "_test_settle_sale")
	model.active[0] = {
		"id": 702, "employee_id": "rep", "value": 100, "recovery": false, "progress": 1.0,
	}
	var outcomes: Array[Dictionary] = model._complete_calls([0], {
		"rep": {"conversion": 100.0, "upsell_chance": 100.0, "upsell_multiplier": 2.0},
	}, {}, true)
	_check(outcomes.size() == 2 and outcomes[0]["type"] == "conversion"
		and outcomes[1]["type"] == "upsell",
		"Upsold calls emit a separate event after completing their sale outcome.")
	model._process_event_waves(outcomes)
	_check(_finance_test_ledger.company_cash == 35
		and _finance_test_ledger.daily_sales_revenue == 200
		and model.revenue == 200,
		"Below-goal sale and upsell revenue do not add cash; triggered grants affect Company Cash only.")

	_finance_test_ledger = FinancialLedger.new()
	_finance_test_ledger.company_cash = 100
	_finance_test_ledger.reset_daily_revenue(32, 1000)
	model.reset(["rep"], 32, {
		"rep": [_instance("commission-no-upsell", "commission")],
	})
	model._effect_engine.catalog = catalog
	model.cash_effect_callback = Callable(self, "_test_apply_financial_effect")
	model.sale_settlement_callback = Callable(self, "_test_settle_sale")
	model.active[0] = {
		"id": 703, "employee_id": "rep", "value": 100, "recovery": false, "progress": 1.0,
	}
	outcomes = model._complete_calls([0], {
		"rep": {"conversion": 100.0, "upsell_chance": 0.0, "upsell_multiplier": 2.0},
	}, {}, true)
	_check(outcomes.size() == 2 and outcomes[1]["type"] == "call_completed_without_upsell",
		"Completed calls without an upsell emit the corresponding financial trigger.")
	model._process_event_waves(outcomes)
	_check(_finance_test_ledger.company_cash == 75
		and _finance_test_ledger.daily_sales_revenue == 100,
		"A below-goal sale is performance-only and a no-upsell penalty reduces cash without altering revenue.")

	_finance_test_ledger = FinancialLedger.new()
	_finance_test_ledger.company_cash = 40
	model.reset(["holder", "target"], 33, {
		"holder": [_instance("liquidator", "liquidation")],
	})
	model._effect_engine.catalog = catalog
	model.cash_effect_callback = Callable(self, "_test_apply_financial_effect")
	model.financial_context_provider = Callable(self, "_test_financial_context")
	model.next_arrival_seconds = INF
	model.receive_call()
	model.receive_call()
	model.active[1]["progress"] = 0.5
	var conversion := model._make_event("conversion", "holder", 0, {"id": 701}, [71])
	model._process_event_waves([conversion])
	_check(_finance_test_ledger.company_cash == 0
		and is_equal_approx(float(model.active[1]["progress"]), 0.54)
		and _finance_test_ledger.transactions.back()["requested_amount"] == 100
		and _finance_test_ledger.transactions.back()["applied_amount"] == 40,
		"Cash-limited progress effects scale from actual spend and do not credit sales revenue.")


func _test_apply_financial_effect(
		action: String,
		requested_amount: int,
		employee_id: String,
		augment_id: String,
		timestamp: float,
		event_id: int
	) -> int:
	var transaction := _finance_test_ledger.apply_augment_cash_effect(
		action, requested_amount, employee_id, augment_id, timestamp, event_id
	)
	return int(transaction["applied_amount"])


func _test_settle_sale(sale: Dictionary) -> void:
	_finance_test_ledger.settle_sale(
		str(sale.get("employee_id", "")), int(sale.get("value", 0)),
		float(sale.get("timestamp", 0.0)), "", int(sale.get("event_id", 0))
	)


func _test_financial_context() -> Dictionary:
	return {"company_cash": _finance_test_ledger.company_cash}


func _test_rewards_and_installation() -> void:
	var manager: AugmentManager = MANAGER_SCRIPT.new()
	var reward: Dictionary = manager.generate_daily_reward()
	var choices: Array = reward["choices"]
	_check(choices.size() == 3 and choices[0] != choices[1] and choices[0] != choices[2] and choices[1] != choices[2],
		"A daily reward contains three distinct augment definitions.")
	manager.select_reward_option(2)
	_check(manager.generate_daily_reward() == reward or manager.pending_reward["selected_index"] == 2,
		"Reopening a reward does not reroll choices and preserves the selected option.")
	while not manager.bag.is_item_full():
		manager.bag.add_item("AUG_001")
	_check(not manager.claim_reward_to_inventory(2) and not manager.pending_reward.is_empty(),
		"A full inventory cannot claim into inventory and does not erase the pending reward.")
	_check(manager.install_reward(2, "nina", 0) and manager.pending_reward.is_empty()
		and manager.bag.item_count() == InventoryManager.ITEM_SLOTS,
		"Direct installation bypasses full inventory and consumes only the selected reward.")

	var replacement_manager: AugmentManager = MANAGER_SCRIPT.new()
	replacement_manager.bag.add_item("AUG_001")
	replacement_manager.equip_slot("nina", 0)
	var old_uid: String = replacement_manager.bag.equipped_instances("nina")[0]["uid"]
	replacement_manager.generate_daily_reward()
	var balance_before: int = replacement_manager.budget
	_check(replacement_manager.install_reward(0, "nina", 0)
		and replacement_manager.budget == balance_before
		and replacement_manager.bag.equipped_instances("nina")[0]["uid"] != old_uid,
		"Destructive replacement is permanent and has no additional surgery fee.")

	var shop_manager: AugmentManager = MANAGER_SCRIPT.new()
	shop_manager.store_offers[1] = {
		"kind": "augment", "tier": "standard", "status": "available",
		"rarity": "Common", "augment_id": "AUG_002",
	}
	_check(shop_manager.purchase_store_augment(1)
		and shop_manager.budget == 375 and shop_manager.bag.item_count() == 1
		and shop_manager.loadout("nina").is_empty(),
		"Store purchases enter shared item inventory and never auto-equip.")


func _progress_operation(employee_id: String, seat: int, value: float, event_id: int) -> Dictionary:
	return {
		"employee_id": employee_id,
		"seat": seat,
		"instance_id": "test_instance",
		"augment_id": "test",
		"chain_id": 1,
		"event_id": event_id,
		"effect": {"type": "call_progress", "selector": "self", "value": value, "duration": "instant"},
	}
