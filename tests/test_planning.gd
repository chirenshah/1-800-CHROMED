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
	_check(plan.roster.size() == 19 and plan.seats == ["nina", "", "", "", "", "", "", "", ""]
		and plan.occupied_seats() == [0],
		"Start with nineteen candidates, nine seats, and only Nina on the floor.")
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


func _drop_rep(source_kind: String, source_index: int, target: Control) -> void:
	var payload := {"type": "person", "kind": source_kind, "index": source_index}
	if target._can_drop_data(Vector2.ZERO, payload):
		target._drop_data(Vector2.ZERO, payload)


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
	scene.first_day_complete = true
	scene._select_prepare_view(scene.PrepareView.STORE)
	_check(scene.prepare_view == scene.PrepareView.STORE and scene.store_panel.visible
		and scene.augment_manager.store_offers.size() == 7
		and scene.store_panel.augment_buy_buttons.size() == 5
		and scene.store_panel.employee_hire_buttons.size() == 2,
		"Prepare must open the fully stocked Store by default.")
	var day_store: Array = scene.augment_manager.store_offers.duplicate(true)
	scene._select_prepare_view(scene.PrepareView.FLOOR)
	await _settle()
	scene._select_prepare_view(scene.PrepareView.STORE)
	await _settle()
	_check(scene.augment_manager.store_offers == day_store,
		"Switching Prepare views preserves the current workday's store offerings.")
	scene._select_prepare_view(scene.PrepareView.FLOOR)
	await _settle()
	_check(scene.staffed_seats.size() == 1 and panel.summary_label.text == "1 / 9 seated"
		and scene.employee_cards.filter(func(card: EmployeeCard) -> bool: return card.staffed).size() == 1
		and scene.inventory.owned_count() == 1 and scene.primary_button.disabled == false
		and panel.views.current_tab == 0 and not panel.detail_scroll.visible
		and scene.inventory_panel.people_open(),
		"Prepare must start with Nina alone and show the reserve drop targets.")
	panel.views.current_tab = 1
	_check(panel.budget_label.visible and panel.equipment_label.visible,
		"The Augments view must expose cash, inventory, and equipment without duplicating the Store.")
	panel.views.current_tab = 2
	_check(panel.strength_label.visible and panel.tradeoff_label.visible,
		"Character descriptions must remain available in Details.")
	panel.views.current_tab = 0
	# The interaction steps below need empty seats for move-to-empty and bench coverage.
	var sparse_scene_seats: Array[String] = ["nina", "zip", "", "victoria", "", "", "", "", ""]
	scene.floor_plan.seats = sparse_scene_seats
	scene.inventory.person_slots[0] = "ada"
	scene.inventory.person_slots[1] = "echo"
	scene._sync_floor_plan()
	scene._refresh_augment_views()
	var reserve_stats: String = scene.inventory_panel.person_cells[0]._detail.text
	_check(reserve_stats.contains("Close 35% · SPD 2.00") and reserve_stats.contains("3h00m · Upsell 15%")
		and reserve_stats.contains("4h stam · $100/day"), "Reserve cards show the same core stats as floor cards.")
	_check(panel.visible and not scene.queue_panel.visible and panel.candidate_selector.item_count == 19,
		"Details must retain roster inspection.")
	for screen_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = screen_size
		await _settle()
		var screen := Rect2(Vector2.ZERO, Vector2(screen_size))
		for control: Control in [panel, panel.profile_label, scene.primary_button, scene.inventory_panel.person_cells[0]]:
			_check(screen.encloses(control.get_global_rect()), "Planning control is off screen at %s: %s" % [screen_size, control.name])
		var floor_scroll: ScrollContainer = scene.floor_grid.get_parent()
		var floor_view: Rect2 = floor_scroll.get_global_rect()
		for card in scene.employee_cards:
			_check(card.get_global_rect().position.x >= floor_view.position.x
				and card.get_global_rect().end.x <= floor_view.end.x,
				"Planning seat must fit the floor width at %s: %s" % [screen_size, card.seat_number])
		floor_scroll.ensure_control_visible(scene.employee_cards[8])
		await _settle()
		_check(floor_scroll.get_global_rect().encloses(scene.employee_cards[8].get_global_rect()),
			"The last planning row must be reachable by scrolling at %s." % screen_size)
		floor_scroll.scroll_vertical = 0
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
	scene.floor_grid.get_parent().ensure_control_visible(scene.employee_cards[2])
	await _settle()
	await _click(scene.employee_cards[2])
	_check(scene.selected_seat == 2 and panel.selected_seat == 2 and scene.employee_cards[2].selected,
		"Clicking an empty seat must select it in the planner.")
	_drop_rep(InventoryManager.RESERVE, 0, scene.employee_cards[2])
	_check(scene.floor_plan.seats[2] == "ada" and scene.employee_cards[2].employee_id == "ada"
		and scene.staffed_seats == [0, 1, 2, 3], "Dropping from reserve deploys the rep.")
	_drop_rep(InventoryManager.BOARD, 0, scene.employee_cards[1])
	_check(scene.floor_plan.seats[1] == "nina" and scene.floor_plan.seats[0] == "zip", "Dropping onto an occupied seat swaps reps.")
	_drop_rep(InventoryManager.BOARD, 1, scene.inventory_panel.person_cells[0])
	_check(scene.floor_plan.seats[1].is_empty() and scene.inventory.person_slots[0] == "nina",
		"Dropping onto an empty reserve slot recalls the rep.")
	_drop_rep(InventoryManager.RESERVE, 1, scene.employee_cards[1])
	_check(scene.floor_plan.seats[1] == "echo", "Any owned reserve rep can be deployed.")
	scene._hire_employee("dex")
	_check(scene.inventory.person_slots.has("dex") and not scene.floor_plan.seats.has("dex")
		and scene.augment_manager.budget == AugmentManager.STARTING_BUDGET - AugmentManager.HIRE_COST,
		"Hiring must place the salesperson in reserve and charge the hire cost.")
	_drop_rep(InventoryManager.RESERVE, 0, scene.employee_cards[4])
	_drop_rep(InventoryManager.RESERVE, 1, scene.employee_cards[5])
	_check(scene.staffed_seats.size() == 6 and scene.inventory.person_slots.count("") == InventoryManager.PERSON_SLOTS,
		"Owned reserve members must be deployable and leave no duplicates behind.")
	_unique_assignments(scene.floor_plan)
	# No empty-floor workday, including attempts to bypass the disabled button.
	for seat in range(9):
		var reserve_slot: int = scene.inventory.first_free_person_slot()
		if reserve_slot >= 0:
			_drop_rep(InventoryManager.BOARD, seat, scene.inventory_panel.person_cells[reserve_slot])
	_check(scene.primary_button.disabled and panel.summary_label.text == "0 / 9 seated", "Empty floors must explain that staffing is required.")
	scene._start_day()
	_check(scene.phase == scene.Phase.PREPARE and scene.day_timer.is_stopped(), "An empty floor cannot start through the controller.")
	_drop_rep(InventoryManager.RESERVE, scene.inventory.person_slots.find("nina"), scene.employee_cards[8])
	_check(not scene.primary_button.disabled, "Assigning a colleague must re-enable Start Workday.")
	var lineup: Array = scene.floor_plan.seats.duplicate()
	scene.augment_manager.budget = 1000
	scene._start_day()
	scene.day_timer.stop()
	scene.call_queue.receive_call()
	scene._simulate_tick(0.25)
	_check(scene.queue_panel.visible and not panel.visible and scene.call_queue.active.has(8),
		"Play must use the planned occupied seats and show its queue.")
	_drop_rep(InventoryManager.RESERVE, scene.inventory.person_slots.find("ada"), scene.employee_cards[0])
	_drop_rep(InventoryManager.BOARD, 8, scene.inventory_panel.person_cells[5])
	scene._select_seat(0)
	_check(scene.floor_plan.seats == lineup and not scene.employee_cards[8].planning_enabled,
		"Assignments must lock during Play, including direct controller calls.")
	scene._toggle_pause()
	_drop_rep(InventoryManager.RESERVE, scene.inventory.person_slots.find("dex"), scene.employee_cards[0])
	_check(scene.floor_plan.seats == lineup, "Pause must not unlock roster editing.")
	scene._finish_day()
	_drop_rep(InventoryManager.BOARD, 8, scene.inventory_panel.person_cells[5])
	_check(scene.floor_plan.seats == lineup and not panel.visible, "Report must preserve the planned lineup without editing.")
	scene._skip_reward()
	scene._prepare_next_day()
	scene._select_prepare_view(scene.PrepareView.FLOOR)
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
