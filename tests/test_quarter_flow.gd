extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _settle() -> void:
	for frame in 4:
		await process_frame


func _new_workday() -> Control:
	var scene: Control = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	return scene


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	RunSave.save_path = "user://quarter-flow-test.save"
	RunSave.session_active = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RunSave.save_path))
	RunSave.pending_resume.clear()
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _settle()
	_check(menu.resume_button.disabled, "Resume is disabled before a completed-day save exists.")
	menu.queue_free()
	await _settle()
	var isolated := _new_workday()
	await _settle()
	isolated._start_day()
	isolated.day_timer.stop()
	isolated._finish_day()
	_check(not RunSave.has_save(), "Direct developer scenes cannot overwrite a player's autosave.")
	isolated.queue_free()
	await _settle()
	RunSave.session_active = true
	var first := _new_workday()
	await _settle()
	_check(first.day == 1 and first.floor_plan.seats[0] == "nina", "First quarter begins with Nina.")
	_check(first.prepare_view == first.PrepareView.FLOOR and first.store_view_tab.visible == false
		and first.planning_panel.visible == false and first.tutorial_panel.visible,
		"First view teaches the floor before the Store.")
	_check(first.tutorial_body.text.contains("Nina") and first.main_menu_button.visible,
		"The first run explains Nina and offers a return to the main menu.")
	root.size = Vector2i(960, 540)
	await _settle()
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(screen.encloses(first.tutorial_panel.get_global_rect())
		and screen.encloses(first.main_menu_button.get_global_rect()),
		"Orientation and Main Menu fit the minimum supported viewport.")
	root.size = Vector2i(1280, 720)
	await _settle()
	first.tutorial_button.pressed.emit()
	_check(first.tutorial_body.text.contains("target"), "Orientation explains the sales target.")
	first.tutorial_button.pressed.emit()
	_check(first.tutorial_body.text.contains("12 in-game hours"), "Orientation explains the shift and report.")
	_check(not RunSave.has_save(), "A new quarter has no completed-day autosave.")
	first._start_day()
	first.day_timer.stop()
	first._request_main_menu()
	_check(first.paused and first._leave_confirmation.visible,
		"Returning to Main Menu from Play warns and pauses the shift.")
	first._leave_confirmation.hide()
	first._cancel_main_menu()
	_check(not first.paused, "Canceling Main Menu resumes the shift.")
	first._finish_day()
	await _settle()
	_check(first.phase == first.Phase.REPORT and first.first_day_complete,
		"Completing day one opens its report.")
	_check(RunSave.has_save(), "Completed day creates an autosave.")
	menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _settle()
	_check(not menu.resume_button.disabled, "Resume is available after autosave.")
	menu.queue_free()
	await _settle()
	var pending: Dictionary = first.augment_manager.pending_reward.duplicate(true)
	_check(not pending.is_empty(), "Completed report has a pending reward.")
	var saved_cash: int = first.financial_ledger.company_cash
	first.queue_free()
	await _settle()

	RunSave.pending_resume = RunSave.load()
	var resumed := _new_workday()
	await _settle()
	_check(resumed.phase == resumed.Phase.REPORT and resumed.report_snapshot.get("day") == 1,
		"Resume restores the completed report.")
	_check(resumed.augment_manager.pending_reward == pending,
		"Resume preserves the same reward offer.")
	_check(resumed.financial_ledger.company_cash == saved_cash,
		"Resume preserves company cash.")
	resumed._select_reward_option(1)
	_check(int(RunSave.load().get("augments", {}).get("pending_reward", {}).get("selected_index", -1)) == 1,
		"Changing the reward choice updates the checkpoint.")
	resumed._skip_reward()
	_check(RunSave.load().get("augments", {}).get("pending_reward", { }).is_empty(),
		"Resolving a reward updates the autosave.")
	resumed._prepare_next_day()
	_check(resumed.day == 2 and resumed.phase == resumed.Phase.PREPARE
		and resumed.store_view_tab.visible, "The next day opens normal preparation.")
	resumed._hire_employee("zip")
	_check(RunSave.load().get("inventory", {}).get("reserve", []).has("zip"),
		"Management changes after an autosaved day persist.")
	var pre_shift_cash: int = int(RunSave.load().get("finance", {}).get("company_cash", -1))
	resumed._start_day()
	resumed.day_timer.stop()
	resumed.financial_ledger.settle_sale("nina", 100, 1.0)
	resumed._toggle_inventory(true)
	_check(int(RunSave.load().get("finance", {}).get("company_cash", -1)) == pre_shift_cash,
		"A UI refresh during Play cannot save partial shift revenue.")
	resumed.queue_free()
	await _settle()

	RunSave.pending_resume = RunSave.load()
	var next_day := _new_workday()
	await _settle()
	_check(next_day.day == 2 and next_day.phase == next_day.Phase.PREPARE,
		"Resume restores the next Prepare checkpoint.")
	_check(next_day.augment_manager.pending_reward.is_empty(),
		"A claimed or skipped reward cannot be offered again.")
	_check(next_day.inventory.person_slots.has("zip"), "Resume preserves later hires.")
	next_day.queue_free()
	await _settle()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RunSave.save_path))
	var terminal := _new_workday()
	await _settle()
	terminal.financial_ledger.writeups = 2
	terminal._start_day()
	terminal.day_timer.stop()
	terminal._finish_day()
	_check(terminal.phase == terminal.Phase.TERMINATED and RunSave.has_save(),
		"The final report is saved when the third write-up ends the quarter.")
	terminal.queue_free()
	await _settle()
	RunSave.pending_resume = RunSave.load()
	var resumed_terminal := _new_workday()
	await _settle()
	_check(resumed_terminal.phase == resumed_terminal.Phase.TERMINATED
		and resumed_terminal.report_panel.termination_label.visible,
		"Resume restores the terminal report without restarting the quarter.")
	resumed_terminal._request_main_menu()
	await _settle()
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main_menu.tscn",
		"The in-game Main Menu action returns to the menu.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RunSave.save_path))
	RunSave.save_path = RunSave.SAVE_PATH
	RunSave.session_active = false
	if failures.is_empty():
		print("PASS: guided first day, autosave, report reward and next-day resume.")
	quit(0 if failures.is_empty() else 1)
