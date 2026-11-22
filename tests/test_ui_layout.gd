extends SceneTree
## Godot --headless --path . --script res://tests/test_ui_layout.gd

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _settle() -> void:
	for frame in range(5):
		await process_frame


func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) < 1.0


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	await _settle()

	var header := scene.get_node("PageMargin/Page/Header") as Control
	var workspace := scene.get_node("PageMargin/Page/Workspace") as Control
	var main_content := scene.get_node("PageMargin/Page/Workspace/MainContent") as Control
	var bottom_panel := scene.get_node("PageMargin/Page/BottomPanel") as Control
	var header_rect := header.get_global_rect()
	var workspace_rect := workspace.get_global_rect()
	var content_rect := main_content.get_global_rect()
	var sidebar_rect := scene.prepare_sidebar.get_global_rect()
	var bottom_rect := bottom_panel.get_global_rect()
	_check(_near(header_rect.size.y, 72.0)
		and _near(workspace_rect.position.y, 72.0)
		and _near(workspace_rect.size.y, 488.0)
		and _near(content_rect.size.x, 1120.0)
		and _near(sidebar_rect.position.x, 1120.0)
		and _near(sidebar_rect.size.x, 160.0)
		and _near(bottom_rect.position.y, 560.0)
		and _near(bottom_rect.size.y, 160.0),
		"The 1280x720 screen must match the specified header, workspace, sidebar, and bottom regions.")
	_check(scene.prepare_view == scene.PrepareView.STORE and scene.store_panel.visible
		and scene.prepare_sidebar.visible and scene.inventory_panel.visible
		and scene.store_view_button.button_pressed
		and scene.inventory_panel.people_section.visible and scene.inventory_panel.items_section.visible,
		"Prepare must default to Store and keep both inventory sections visible.")
	var reserve_rect := scene.inventory_panel.people_section.get_global_rect()
	var items_rect := scene.inventory_panel.items_section.get_global_rect()
	_check(reserve_rect.position.x < items_rect.position.x
		and _near(reserve_rect.size.x, items_rect.size.x),
		"Reserve Employees must occupy the left half and Augments & Items the equal-width right half.")
	_check(scene.daily_goal_label.text == "GOAL  $1000"
		and scene.writeups_label.text == "WRITE-UPS  0/3",
		"The header must show the live daily goal and write-up count.")

	scene._select_prepare_view(scene.PrepareView.FLOOR)
	await _settle()
	var first_card_prepare: Rect2 = scene.employee_cards[0].get_global_rect()
	var last_card_prepare: Rect2 = scene.employee_cards[8].get_global_rect()
	scene._select_prepare_view(scene.PrepareView.CALENDAR)
	scene.calendar_panel.next_month()
	scene.calendar_panel.next_month()
	scene.calendar_panel.next_month()
	_check(scene.calendar_panel.display_month == 3
		and scene.calendar_panel._next_button.disabled
		and scene.calendar_panel._boss_label.text.contains("QUARTERLY FINAL BOSS")
		and scene.calendar_panel._challenge_label.text.contains("Coming soon"),
		"Calendar month navigation must stop at month three and show progression placeholders.")
	scene.calendar_panel.previous_month()
	_check(scene.calendar_panel.display_month == 2,
		"Calendar navigation must move between months without changing the current workday.")
	scene.begin_workday_button.pressed.emit()
	scene.day_timer.stop()
	await _settle()
	_check(scene.phase == scene.Phase.PLAY and scene.prepare_view == scene.PrepareView.FLOOR
		and scene.scoreboard.visible and not scene.prepare_sidebar.visible
		and scene.queue_panel.visible and not scene.inventory_panel.visible
		and scene.floor_grid.get_parent().visible,
		"Begin Workday must open the Sales Floor, scoreboard, and lead queue.")
	var first_card_workday: Rect2 = scene.employee_cards[0].get_global_rect()
	var last_card_workday: Rect2 = scene.employee_cards[8].get_global_rect()
	_check(first_card_prepare.position.is_equal_approx(first_card_workday.position)
		and first_card_prepare.size.is_equal_approx(first_card_workday.size)
		and last_card_prepare.position.is_equal_approx(last_card_workday.position)
		and last_card_prepare.size.is_equal_approx(last_card_workday.size),
		"The Sales Floor cards must keep the same position and scale across the phase change.")
	scene.call_queue.revenue = 500
	scene._refresh_floor()
	_check(scene.revenue_label.text == "$500"
		and _near(scene.scoreboard.progress_bar.value, 50.0)
		and scene.target_label.text == "GOAL $1000",
		"The live scoreboard must reflect simulation revenue and progress toward the goal.")
	_check(scene.queue_panel.get_global_rect().position.is_equal_approx(bottom_rect.position)
		and scene.queue_panel.get_global_rect().size.is_equal_approx(bottom_rect.size),
		"The Workday lead queue must occupy the same full-width bottom region as inventory.")

	root.size = Vector2i(960, 540)
	await _settle()
	var compact_header := header.get_global_rect()
	var compact_workspace := workspace.get_global_rect()
	var compact_sidebar := scene.scoreboard.get_global_rect()
	var compact_bottom := scene.queue_panel.get_global_rect()
	_check(_near(compact_header.size.y, 54.0)
		and _near(compact_workspace.size.y, 366.0)
		and _near(compact_sidebar.size.x, 120.0)
		and _near(compact_bottom.size.y, 120.0),
		"The UI regions must scale proportionally at the supported 960x540 size.")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: screen regions, Prepare navigation and inventory, Calendar, Workday scoreboard, queue, and floor stability.")
	quit(0 if failures.is_empty() else 1)
