extends SceneTree
## Godot --headless --path . --script res://tests/test_planning.gd
## Omit --headless and append -- --capture for /tmp/chromed-planning-*.png.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _unique_assignments(plan: FloorPlan) -> void:
	var seen: Array[String] = []
	_check(plan.seats.size() == 9, "Planning must preserve exactly nine seats.")
	for employee_id in plan.seats:
		if employee_id.is_empty():
			continue
		_check(not seen.has(employee_id), "An employee cannot occupy multiple seats.")
		_check(not plan.profile(employee_id).is_empty(), "Every seated employee must be in the roster.")
		seen.append(employee_id)


func _test_model() -> void:
	var plan := FloorPlan.new()
	_check(plan.roster.size() == 19 and plan.seats == ["nina", "zip", "ada", "", "", "", "", "", ""]
		and plan.occupied_seats() == [0, 1, 2],
		"Start with nineteen candidates, nine seats, and a three-person default lineup.")
	_unique_assignments(plan)
	# Keep move-to-empty and bench replacement behavior covered with a deliberately sparse lineup.
	var sparse_model_seats: Array[String] = ["nina", "zip", "", "victoria", "", "", "", "", ""]
	plan.seats = sparse_model_seats
	var before := plan.seats.duplicate()
	_check(not plan.assign(-1, "ada") and not plan.assign(9, "ada")
		and not plan.assign(2, "missing") and not plan.bench(-1)
		and not plan.bench(2) and plan.seats == before, "Invalid assignments must leave the floor intact.")
	_check(plan.assign(2, "ada") and plan.seats[2] == "ada", "A benched colleague can fill an empty seat.")
	_check(plan.assign(8, "nina") and plan.seats[0].is_empty(), "Moving to an empty seat must vacate the old one.")
	_check(plan.assign(1, "nina") and plan.seats[8] == "zip", "Moving to an occupied seat must swap its colleague.")
	_check(plan.assign(3, "dex") and not plan.seats.has("victoria"), "Replacing from the bench must return the occupant to the bench.")
	_check(plan.bench(3) and plan.profile("dex")["name"] == "Dex", "Benching must keep the employee in the available roster.")
	for seat in range(9):
		for employee in plan.roster:
			plan.assign(seat, employee["id"])
			_unique_assignments(plan)


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
		await process_frame
	await _settle()


func _choose_candidate(panel: PlanningPanel, employee_id: String) -> void:
	for index in panel.candidate_selector.item_count:
		if panel.candidate_selector.get_item_metadata(index) == employee_id:
			panel.candidate_selector.select(index)
			panel.candidate_selector.item_selected.emit(index)
			return
	_check(false, "Missing planning candidate: " + employee_id)


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/chromed-planning-%s.png" % name) == OK,
			"Could not capture planning screenshot.")


func _test_scene() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	var panel: PlanningPanel = scene.planning_panel
	_check(scene.staffed_seats.size() == 3 and panel.summary_label.text == "3 / 9 seated"
		and scene.employee_cards.filter(func(card: EmployeeCard) -> bool: return card.staffed).size() == 3,
		"Prepare must start with three staffed seats out of nine.")
	# The interaction steps below need empty seats for move-to-empty and bench coverage.
	var sparse_scene_seats: Array[String] = ["nina", "zip", "", "victoria", "", "", "", "", ""]
	scene.floor_plan.seats = sparse_scene_seats
	scene.inventory.person_slots[0] = "ada"
	scene.inventory.person_slots[1] = "echo"
	scene._sync_floor_plan()
	_check(panel.visible and not scene.queue_panel.visible and panel.candidate_selector.item_count == 19,
		"Prepare must show all nineteen candidates in its planner.")
	for screen_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = screen_size
		await _settle()
		var screen := Rect2(Vector2.ZERO, Vector2(screen_size))
		for control: Control in [panel, panel.candidate_selector, panel.profile_label, panel.assign_button, panel.bench_button, scene.primary_button]:
			_check(screen.encloses(control.get_global_rect()), "Planning control is off screen at %s: %s" % [screen_size, control.name])
		var floor_view: Rect2 = scene.floor_grid.get_parent().get_global_rect()
		for card in scene.employee_cards:
			_check(floor_view.encloses(card.get_global_rect()), "All nine planning seats should fit at %s: %s" % [screen_size, card.seat_number])
		await _capture(str(screen_size.x))
	root.size = Vector2i(1280, 720)
	await _settle()
	scene.employee_cards[4].grab_focus()
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	root.push_input(accept, true)
	accept = InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = false
	root.push_input(accept, true)
	await _settle()
	_check(scene.selected_seat == 4, "Keyboard activation must select a focused workstation.")
	await _click(scene.employee_cards[2])
	_check(scene.selected_seat == 2 and panel.selected_seat == 2 and scene.employee_cards[2].selected,
		"Clicking an empty seat must select it in the planner.")
	_choose_candidate(panel, "ada")
	_check(panel.strength_label.text.contains("Conversion") and panel.tradeoff_label.text.contains("weak personal output"),
		"Candidate inspection must show the source character's strength and tradeoff.")
	_check(panel.profile_label.text == "Speed: 2/5 · Conversion: 35%\nUpsell: 15% · Multiplier: ×1.5",
		"The planner must show the active numerical base stats for each candidate.")
	await _capture("ada-preview")
	await _click(panel.assign_button)
	_check(scene.floor_plan.seats[2] == "ada" and scene.employee_cards[2].employee_id == "ada"
		and scene.staffed_seats == [0, 1, 2, 3], "Assignment must update the floor and simulation's staffing input.")
	await _click(scene.employee_cards[1])
	_choose_candidate(panel, "nina")
	await _click(panel.assign_button)
	_check(scene.floor_plan.seats[1] == "nina" and scene.floor_plan.seats[0] == "zip", "Assignment must swap two seated employees.")
	await _click(panel.bench_button)
	_check(scene.floor_plan.seats[1].is_empty() and not scene.employee_cards[1].staffed, "Bench button must open the selected workstation.")
	# The final candidate must be inspectable and assignable beyond the nine seats.
	_choose_candidate(panel, "echo")
	_check(panel.profile_label.text == "Speed: 2/5 · Conversion: 45%\nUpsell: 10% · Multiplier: ×1.5", "The last roster entry must expose its own stats.")
	await _click(panel.assign_button)
	_check(scene.floor_plan.seats[1] == "echo", "Candidates beyond the first nine must be assignable.")
	# Hiring: an unowned candidate is hired into reserve, never deployed, and charged once.
	_choose_candidate(panel, "dex")
	_check(panel.assign_button.text.begins_with("Hire") and not scene.inventory.owns("dex"),
		"Unowned candidates must offer hiring instead of assignment.")
	await _click(panel.assign_button)
	_check(scene.inventory.person_slots.has("dex") and not scene.floor_plan.seats.has("dex")
		and scene.augment_manager.budget == AugmentManager.STARTING_BUDGET - AugmentManager.HIRE_COST,
		"Hiring must place the salesperson in reserve and charge the hire cost.")
	scene._assign_employee(4, "nina")
	scene._assign_employee(5, "dex")
	_check(scene.staffed_seats.size() == 6 and scene.inventory.person_slots.count("") == InventoryManager.PERSON_SLOTS,
		"Owned reserve members must be deployable and leave no duplicates behind.")
	scene._assign_employee(8, "scrap")
	_check(not scene.floor_plan.seats.has("scrap"), "Unhired salespeople cannot be deployed directly.")
	_unique_assignments(scene.floor_plan)
	# No empty-floor workday, including attempts to bypass the disabled button.
	for seat in range(9):
		scene._bench_employee(seat)
	_check(scene.primary_button.disabled and panel.summary_label.text == "0 / 9 seated", "Empty floors must explain that staffing is required.")
	scene._start_day()
	_check(scene.phase == scene.Phase.PREPARE and scene.day_timer.is_stopped(), "An empty floor cannot start through the controller.")
	scene._assign_employee(8, "nina")
	_check(not scene.primary_button.disabled, "Assigning a colleague must re-enable Start Workday.")
	var lineup: Array = scene.floor_plan.seats.duplicate()
	scene._start_day()
	scene.day_timer.stop()
	scene.call_queue.receive_call()
	scene._simulate_tick(0.25)
	_check(scene.queue_panel.visible and not panel.visible and scene.call_queue.active.has(8),
		"Play must use the planned occupied seats and show its queue.")
	scene._assign_employee(0, "ada")
	scene._bench_employee(8)
	scene._select_seat(0)
	_check(scene.floor_plan.seats == lineup and not scene.employee_cards[8].planning_enabled,
		"Assignments must lock during Play, including direct controller calls.")
	scene._toggle_pause()
	scene._assign_employee(0, "dex")
	_check(scene.floor_plan.seats == lineup, "Pause must not unlock roster editing.")
	scene._finish_day()
	scene._bench_employee(8)
	_check(scene.floor_plan.seats == lineup and not panel.visible, "Report must preserve the planned lineup without editing.")
	scene._prepare_next_day()
	await _settle()
	_check(scene.floor_plan.seats == lineup and panel.visible and scene.call_queue.received == 0
		and scene.employee_cards[8].planning_enabled, "Next day must retain seating, reset calls, and reopen planning.")
	_unique_assignments(scene.floor_plan)
	scene.queue_free()
	await process_frame


func _run() -> void:
	_test_model()
	await _test_scene()
	if failures.is_empty():
		print("PASS: planning roster, mouse selection/assignment, moves/swaps/bench, phase locks, staffing, next-day persistence, and layout.")
	quit(0 if failures.is_empty() else 1)
