extends SceneTree
## Godot --headless --path . --script res://tests/test_financial_gameplay.gd

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _test_ledger() -> void:
	var ledger := FinancialLedger.new()
	ledger.company_cash = 500
	ledger.reset_daily_revenue(1, 1000)
	ledger.begin_workday()
	var sale := ledger.settle_sale("rep", 600, 1.25)
	_check(ledger.daily_sales_revenue == 600 and ledger.company_cash == 500
		and sale["ledger"] == ["daily_sales_revenue"]
		and sale["sales_cash_credit"] == 0,
		"Below-goal sales count toward performance but do not add to opening Company Cash.")
	var day_one := ledger.settle(
		1, ledger.company_cash, ledger.daily_sales_revenue, 1000, false, 700, 300
	)
	_check(day_one["debt_remaining"] == 500 and day_one["ending_cash"] == 0
		and day_one["writeup_issued"] and day_one["failure_reasons"].size() == 2,
		"Existing cash does not count toward the revenue goal; payroll and goal failures issue one write-up.")
	ledger.reset_daily_revenue(2, 1000)
	ledger.begin_workday()
	ledger.settle_sale("rep", 600, 1.0)
	var surplus_sale := ledger.settle_sale("rep", 1400, 2.0)
	_check(ledger.daily_sales_revenue == 2000 and ledger.company_cash == 0
		and surplus_sale["sales_cash_credit"] == 0,
		"Sales during Play update revenue without changing cash before settlement.")
	var day_two := ledger.settle(
		2, ledger.company_cash, ledger.daily_sales_revenue, 1000, true, 700, 300
	)
	var surplus_recorded := false
	for transaction: Dictionary in ledger.transactions:
		if transaction.get("type", "") == "sales_surplus_credit" \
			and transaction.get("day", 0) == 2 \
			and transaction.get("company_cash_delta", 0) == 1000:
			surplus_recorded = true
	_check(day_two["debt_brought_forward"] == 500 and day_two["debt_remaining"] == 500
		and day_two["sales_cash_credited"] == 1000
		and day_two["cash_before_payroll"] == 1000
		and day_two["ending_cash"] == 0 and not day_two["writeup_issued"]
		and surplus_recorded,
		"Only over-goal surplus enters cash at settlement, covering current payroll before old debt.")
	ledger.reset_daily_revenue(3, 1000)
	ledger.begin_workday()
	ledger.settle_sale("rep", 2100, 1.0)
	var day_three := ledger.settle(
		3, ledger.company_cash, ledger.daily_sales_revenue, 300, true, 200, 100
	)
	_check(day_three["debt_remaining"] == 0 and day_three["ending_cash"] == 300
		and ledger.writeups == 1, "Surplus cash pays old debt before remaining as cash.")

	var payroll_only_ledger := FinancialLedger.new()
	payroll_only_ledger.company_cash = 0
	var payroll_only := payroll_only_ledger.settle(1, 0, 0, 100, true, 100, 0)
	_check(payroll_only["failure_reasons"] == ["current_upkeep_unpaid"]
		and payroll_only["writeup_issued"], "Payroll failure alone issues one write-up.")
	var goal_only := FinancialLedger.new().settle(1, 500, 0, 100, false, 100, 0)
	_check(goal_only["failure_reasons"] == ["revenue_goal_missed"]
		and goal_only["writeup_issued"], "Revenue-goal failure alone issues one write-up.")
	var empty_roster := FinancialLedger.new().settle(1, 0, 0, 0, true, 0, 0)
	_check(empty_roster["payroll_met"] and not empty_roster["writeup_issued"],
		"An empty roster creates no payroll write-up.")

	var penalty_ledger := FinancialLedger.new()
	penalty_ledger.company_cash = 20
	var penalty := penalty_ledger.apply_augment_cash_effect(
		"penalty", 50, "rep", "test_penalty", 3.0, 9
	)
	_check(penalty_ledger.company_cash == 0 and penalty_ledger.upkeep_debt == 0
		and penalty_ledger.daily_sales_revenue == 0 and penalty["applied_amount"] == 20,
		"A cash penalty is capped at available cash and never creates debt or changes sales.")
	var grant := penalty_ledger.apply_augment_cash_effect(
		"grant", 50, "rep", "test_grant", 4.0, 10
	)
	_check(penalty_ledger.company_cash == 50 and penalty_ledger.daily_sales_revenue == 0
		and grant["applied_amount"] == 50,
		"A cash grant affects Company Cash only, not Daily Sales Revenue.")

	var idempotent := FinancialLedger.new()
	idempotent.reset_daily_revenue(1, 1000)
	var first := idempotent.settle(1, 100, 0, 80, true, 80, 0)
	var repeated := idempotent.settle(1, 0, 0, 900, false, 0, 900)
	_check(first == repeated and idempotent.upkeep_debt == 0 and idempotent.writeups == 0,
		"Settling a completed day twice returns its original result without charging twice.")
	var restored := FinancialLedger.new()
	_check(restored.load_dict(idempotent.to_dict())
		and restored.settle(1, 0, 0, 900, false, 0, 900) == first,
		"Serialized settlement history prevents duplicate charges after restore.")
	_check(restored.company_cash == idempotent.company_cash
		and restored.daily_sales_goal == 1000
		and restored.transactions == idempotent.transactions,
		"Cash, the sales goal, and the auditable transaction log survive serialization.")
	var day_cap := FinancialLedger.new()
	day_cap.settle(60, 100, 0, 0, true, 0, 0, 60)
	day_cap.settle(61, 100, 0, 0, true, 0, 0, 60)
	_check(day_cap.settlements.size() == 2 and day_cap.next_settlement_id() == 62
		and day_cap.settlements[61]["day"] == 60,
		"Repeated display Day 60 still receives distinct idempotent settlement IDs.")

	var upkeep_data := EmployeeRoster.new()
	upkeep_data.employees.append({"id": "custom", "daily_upkeep": 275})
	_check(FloorPlan.CATALOG.daily_upkeep("nina") == EmployeeRoster.DEFAULT_DAILY_UPKEEP
		and upkeep_data.daily_upkeep("custom") == 275,
		"Daily upkeep uses authored per-employee data with the safe default for older records.")

	var termination := FinancialLedger.new()
	for day in 3:
		var result := termination.settle(day + 1, 0, 0, 0, false, 0, 0)
		_check(result["writeup_issued"] and result["total_writeups"] == day + 1,
			"Every missed-goal day increments the shared counter once.")
	_check(termination.writeups == 3 and termination.settlements[3]["terminated"],
		"Three cumulative write-ups terminate the run.")


func _test_employee_fire() -> void:
	var inventory := InventoryManager.new()
	_check(inventory.add_item("AUG_001").size() > 0
		and inventory.equip_item("nina", 0, 1), "Fixture equips an augment to the starter.")
	_check(inventory.hire("zip"), "Fixture hires a reserve employee.")
	_check(inventory.add_item("AUG_002").size() > 0, "Fixture keeps an uninstalled augment in inventory.")
	_check(inventory.add_item("AUG_003").size() > 0
		and inventory.equip_item("zip", 1, 1), "Fixture equips an augment to the reserve employee.")

	var fired_starter := inventory.fire_employee("nina")
	_check(fired_starter["location"] == InventoryManager.BOARD
		and inventory.floor_plan.seats.count("nina") == 0
		and not inventory.equipment.has("nina")
		and inventory.fired_employee_ids.has("nina")
		and not inventory.can_hire("nina"),
		"Firing from the active board clears the seat, destroys installed augments and blocks rehire.")
	_check(inventory.item_count() == 1 and inventory.item_augment_ids() == ["AUG_002"],
		"Firing preserves uninstalled items.")

	var fired_bench := inventory.fire_employee("zip")
	_check(fired_bench["location"] == InventoryManager.RESERVE
		and inventory.person_slots.count("zip") == 0
		and not inventory.equipment.has("zip")
		and not inventory.can_hire("zip"),
		"Firing from reserve removes the employee and installed augment permanently.")
	var restored := InventoryManager.new()
	_check(restored.load_dict(inventory.to_dict()) and restored.fired_employee_ids.size() == 2
		and not restored.can_hire("nina") and not restored.can_hire("zip"),
		"Fired unique IDs survive inventory serialization and cannot be rehired.")


func _test_workday_finances() -> void:
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	for frame in range(3):
		await process_frame
	scene.slam_board.audio.enabled = false
	_check(scene.inventory.hire("zip"), "Workday fixture adds a bench employee.")
	var before_move := scene._payroll_snapshot()
	scene.inventory.deploy(1, "zip")
	var after_move := scene._payroll_snapshot()
	_check(before_move["total"] == after_move["total"]
		and before_move["active"] == 100 and before_move["bench"] == 100
		and after_move["active"] == 200 and after_move["bench"] == 0,
		"Active and bench employees cost equally; moving a hire preserves projected upkeep.")

	# Return Zip to the bench to verify the report's active/bench split.
	scene.inventory.recall(1)
	scene._sync_floor_plan()
	scene._start_day()
	scene.day_timer.stop()
	scene.call_queue.revenue = 1500
	scene.call_queue.sale_log.append({"id": 1, "value": 1500, "employee_id": "nina", "recovery": false})
	var cash_before := scene.augment_manager.budget
	scene._settle_sale({"employee_id": "nina", "value": 1500, "timestamp": 1.0})
	_check(scene.augment_manager.budget == cash_before
		and scene.financial_ledger.daily_sales_revenue == scene.call_queue.revenue,
		"Sales update revenue during Play while Company Cash stays available at its opening amount.")
	scene._finish_day()
	_check(scene.financial_ledger.settlements[1]["active_upkeep"] == 100
		and scene.financial_ledger.settlements[1]["bench_upkeep"] == 100
		and scene.financial_ledger.settlements[1]["current_upkeep"] == 200
		and scene.augment_manager.budget == cash_before + 500 - 200,
		"End-of-day payroll includes the bench and settles the sales surplus exactly once.")
	_check(scene.report_panel.finance_label.text.contains("DAILY SALES  $1,500 / GOAL $1,000")
		and scene.report_panel.finance_label.text.contains("SURPLUS TO CASH  +$500")
		and scene.report_panel.finance_label.text.contains("Floor $100 · Bench $100")
		and scene.report_panel.finance_label.text.contains("ENDING CASH")
		and scene.report_panel.discipline_label.text.contains("Total: 0 / 3"),
		"The report shows payroll subtotals, cash, goal result and write-up status.")
	var settled_cash: int = scene.augment_manager.budget
	scene._finish_day()
	_check(scene.augment_manager.budget == settled_cash
		and scene.financial_ledger.settlements.size() == 1,
		"Re-entering the end-day handler cannot settle twice.")
	scene.queue_free()
	await process_frame


func _test_firing_ui_and_termination() -> void:
	var play_scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(play_scene)
	for frame in range(3):
		await process_frame
	play_scene._start_day()
	play_scene._request_fire_employee("nina")
	_check(play_scene._pending_fire_id.is_empty() and not play_scene._fire_confirmation.visible
		and play_scene.inventory.owns("nina"),
		"Firing is rejected during Play.")
	play_scene.queue_free()
	await process_frame

	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	for frame in range(3):
		await process_frame
	scene.slam_board.audio.enabled = false
	scene.inventory.add_item("AUG_001")
	scene.inventory.equip_item("nina", 0, 1)
	scene.inventory.add_item("AUG_002")
	scene.financial_ledger.upkeep_debt = 175
	var debt_before: int = scene.financial_ledger.upkeep_debt
	var cash_before := scene.augment_manager.budget
	scene._request_fire_employee("nina")
	_check(scene._fire_confirmation.visible and scene._pending_fire_id == "nina",
		"Prepare firing requires an explicit confirmation.")
	scene._confirm_fire_employee()
	_check(scene.inventory.floor_plan.seats.count("nina") == 0
		and not scene.inventory.equipment.has("nina")
		and scene.inventory.item_augment_ids() == ["AUG_002"]
		and scene._payroll_snapshot()["total"] == 0
		and scene.financial_ledger.upkeep_debt == debt_before
		and scene.augment_manager.budget == cash_before
		and not scene.inventory.can_hire("nina"),
		"Confirmed firing removes the employee and implants without refund or debt change.")
	scene._hire_employee("nina")
	_check(not scene.inventory.owns("nina"), "The workday controller rejects rehire after firing.")
	scene.queue_free()
	await process_frame

	var terminal = load("res://scenes/workday.tscn").instantiate()
	root.add_child(terminal)
	for frame in range(3):
		await process_frame
	terminal.slam_board.audio.enabled = false
	for day_index in 3:
		if day_index > 0:
			terminal._prepare_next_day()
		terminal._start_day()
		terminal.day_timer.stop()
		terminal.call_queue.revenue = 0
		terminal._finish_day()
		_check(terminal.financial_ledger.writeups == day_index + 1,
			"Each workday failure produces at most one cumulative write-up.")
	_check(terminal.phase == terminal.Phase.TERMINATED
		and not terminal.report_panel.next_day_button.visible,
		"The third write-up shows the final report and prevents another day.")
	terminal._prepare_next_day()
	_check(terminal.day == 3 and terminal.phase == terminal.Phase.TERMINATED,
		"Direct next-day calls cannot bypass termination.")
	terminal.queue_free()
	await process_frame


func _run() -> void:
	_test_ledger()
	_test_employee_fire()
	await _test_workday_finances()
	await _test_firing_ui_and_termination()
	if failures.is_empty():
		print("PASS: payroll, carried debt, shared write-ups, termination, employee firing, permanent augments, and daily accounting.")
	quit(0 if failures.is_empty() else 1)
