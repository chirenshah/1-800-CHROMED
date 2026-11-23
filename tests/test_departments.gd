extends SceneTree

const WORKDAY := preload("res://scenes/workday.tscn")

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _run() -> void:
	var old_save_path := RunSave.save_path
	RunSave.save_path = "/tmp/chromed-departments-%d.save" % OS.get_process_id()
	RunSave.session_active = true
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 540)
	var workday := WORKDAY.instantiate()
	root.add_child(workday)
	await process_frame

	workday.hr_tab.pressed.emit()
	_check(workday.hr_panel.visible and not workday.marketing_panel.visible, "HR opens during first-day Planning.")
	await process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(screen.encloses(workday.hr_panel.get_global_rect()), "HR fits the minimum viewport.")
	workday.hr_panel.hire_requested.emit("zip")
	_check(workday.inventory.person_slots.has("zip"), "HR hires into the reserve.")
	workday.floor_view_tab.pressed.emit()
	workday._select_seat(1)
	workday._on_transfer_requested(
		{"type": "person", "kind": InventoryManager.RESERVE, "index": workday.inventory.person_slots.find("zip")},
		InventoryManager.BOARD, 1
	)
	_check(workday.floor_plan.seats[1] == "zip", "First-day hires can be seated.")
	workday.hr_tab.pressed.emit()
	workday.hr_panel.fire_requested.emit("zip")
	workday._fire_confirmation.confirmed.emit()
	workday._fire_confirmation.hide()
	_check(not workday.inventory.owns("zip"), "Confirmed HR firing frees the rep's seat.")

	workday.hr_panel.commission_changed.emit("nina", 20)
	workday.marketing_tab.pressed.emit()
	await process_frame
	_check(screen.encloses(workday.marketing_panel.get_global_rect()), "Marketing fits the minimum viewport.")
	workday.marketing_panel.plan_changed.emit("referrals", 100)
	_check(workday.department_start.disabled, "An unaffordable campaign blocks shift start.")
	workday.marketing_panel.plan_changed.emit("referrals", 8)
	var opening_cash: int = workday.financial_ledger.company_cash
	workday.department_start.pressed.emit()
	workday.day_timer.stop()
	_check(workday.phase == workday.Phase.PLAY, "An affordable campaign applies on the upcoming shift.")
	_check(workday.financial_ledger.company_cash == opening_cash - 240, "Lead cost is charged once at shift start.")
	_check(not workday.department_nav.visible, "Departments are available only in Planning.")
	workday.call_queue.reset(workday.floor_plan.seats, 100, workday.augment_manager.equipment_instances, workday._lead_campaign())
	workday._simulate_tick(36.0)
	var finance: Dictionary = workday.report_snapshot["finance"]
	var revenue := int(finance["gross_revenue"])
	var commission := roundi(revenue * 0.2)
	_check(revenue > 0 and int(finance["commission"]) == commission, "Commission comes from actual closed sales.")
	_check(int(finance["lead_cost"]) == 240 and int(finance["base_payroll"]) == 100
		and int(finance["ending_cash"]) == opening_cash - 240 + revenue - 100 - commission,
		"Cash Flow reconciles revenue, acquisition cost, base salary, and commission.")
	_check(int(finance["rep_pay"]["nina"]["paid"]) == 100 + commission, "Rep pay includes salary and commission.")

	workday._skip_reward()
	workday._prepare_next_day()
	var saved := RunSave.load()
	workday.queue_free()
	await process_frame
	var resumed := WORKDAY.instantiate()
	root.add_child(resumed)
	_check(resumed.load_saved_run(saved), "A Planning checkpoint can resume.")
	_check(resumed.lead_source == "referrals" and resumed.lead_quantity == 8
		and resumed._commission_rate("nina") == 20 and resumed.rep_experience["nina"] == 1,
		"Campaign, commission rate, and experience survive save/resume.")

	resumed.rep_experience["nina"] = 3
	_check(resumed._earnings_expectation("nina") == 105, "Experience increases the rep's pay expectation.")
	var augment_id := str(AugmentManager.CATALOG.augments[0]["id"])
	_check(resumed.inventory.install_augment("nina", augment_id, 0, 1)
		and resumed._earnings_expectation("nina") == 120, "Installed augments increase the rep's pay expectation.")
	resumed._hire_employee("ada")
	resumed._set_lead_plan("cold_list", 0)
	resumed._start_day()
	resumed.day_timer.stop()
	resumed._simulate_tick(36.0)
	var last_finance: Dictionary = resumed.report_snapshot["finance"]
	var departures: Array = last_finance["departures"]
	_check(int(last_finance["commission"]) == 0 and not resumed.inventory.owns("nina")
		and departures.size() == 1, "A rep who earns below their expectation quits at close.")
	_check(resumed.report_panel.outcome_label.text.contains("Nina quit"), "The cash report explains the departure.")
	var results: ReportPanel = resumed.report_panel
	var content: Node = results.finance_summary.get_parent()
	_check(content.get_node("FinanceHeading").get_index() < content.get_node("MetricsHeading").get_index(),
		"Results opens with Cash Flow ahead of Shift Metrics.")
	_check(results.employee_rows.get_child_count() == 2
		and results.employee_rows.get_child(0).text.contains("Nina")
		and results.employee_rows.get_child(1).text.contains("Reserve · Ada")
		and results.employee_rows.get_child(1).text.contains("Commission $0"),
		"Results includes reps who quit at close and reserve reps with no calls.")

	resumed.queue_free()
	await process_frame
	DirAccess.remove_absolute(RunSave.save_path)
	RunSave.save_path = old_save_path
	RunSave.session_active = false
	if not failed:
		print("PASS: Planning departments, paid campaigns, commissions, retention, and resume.")
	quit(1 if failed else 0)
