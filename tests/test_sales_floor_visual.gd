extends SceneTree
## Godot --headless --path . --script res://tests/test_sales_floor_visual.gd

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _settle() -> void:
	for _frame in 5:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var music_player := root.get_node("MusicPlayer") as AudioStreamPlayer
	music_player.stop()
	music_player.stream = null
	var workday: Variant = load("res://scenes/workday.tscn").instantiate()
	root.add_child(workday)
	await _settle()

	var office_background := workday.get_node("OfficeBackground") as TextureRect
	var background_image: Image = office_background.texture.get_image()
	var floor_scroll := workday.floor_grid.get_parent() as ScrollContainer
	_check(background_image.get_width() == 1280 and background_image.get_height() == 720
		and background_image.get_pixel(0, 0).a == 1.0,
		"The office background must be an opaque 1280x720 image.")
	_check(office_background.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and office_background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"The background must preserve its aspect ratio without intercepting input.")
	_check(floor_scroll.horizontal_scroll_mode == 0 and floor_scroll.vertical_scroll_mode == 0,
		"The sales floor must not introduce scrollbars.")

	var rows: Array = workday.sales_floor_art.get_children()
	var expected_names: Array[String] = ["BackRow", "MiddleRow", "FrontRow"]
	var expected_y := [68.0, 203.0, 338.0]
	_check(rows.size() == 3 and workday.employee_cards.size() == 9,
		"The sales floor must contain exactly three desk rows and nine employee slots.")
	for row_index in mini(rows.size(), expected_names.size()):
		var row := rows[row_index] as Control
		var slots := row.get_node("EmployeeSlots") as Control
		var desk := row.get_node("DeskForeground") as TextureRect
		var desk_image: Image = desk.texture.get_image()
		_check(row.name == expected_names[row_index]
			and is_equal_approx(row.position.y, expected_y[row_index])
			and row.size == Vector2(700, 150),
			"Desk rows must be sized and ordered back-to-front within the sales floor.")
		_check(slots.get_child_count() == 3
			and slots.get_index() < desk.get_index()
			and desk.size == Vector2(670, 150)
			and desk_image.get_pixel(0, 0).a < 1.0
			and desk.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Each transparent desk foreground must overlay three interactive slots.")

	for seat in workday.employee_cards.size():
		var card: EmployeeCard = workday.employee_cards[seat]
		var expected_row := floori(float(seat) / 3.0)
		var expected_column := seat % 3
		var slots := rows[expected_row].get_node("EmployeeSlots") as Control
		_check(card.seat_number == seat + 1 and card.get_parent() == slots
			and card.drop_validator.is_valid(),
			"Seat %d must remain attached to its row with drag-and-drop enabled." % (seat + 1))
		_check(is_equal_approx(
			card.position.x,
			15.0 + [112.0, 335.0, 558.0][expected_column] - 67.0
		), "Seat %d must use its configured desk anchor." % (seat + 1))
		if not card.staffed:
			_check(not card.seat_label.visible and not card.name_label.visible
				and not card.role_label.visible and not card.stats_label.visible
				and not card.status_label.visible,
				"An unstaffed desk must show only its artwork until it is selected.")

	var art_rect: Rect2 = workday.sales_floor_art.get_global_rect()
	_check(floor_scroll.get_global_rect().encloses(art_rect),
		"The scaled sales floor must fit inside the viewport.")
	workday._select_prepare_view(workday.PrepareView.FLOOR)
	await _settle()
	var prepare_rects: Array[Rect2] = []
	for card: EmployeeCard in workday.employee_cards:
		prepare_rects.append(card.get_global_rect())
	workday._start_day()
	workday.day_timer.stop()
	await _settle()
	var phase_positions_stable := workday.phase == workday.Phase.PLAY
	for seat in workday.employee_cards.size():
		var current_rect: Rect2 = workday.employee_cards[seat].get_global_rect()
		if not prepare_rects[seat].position.is_equal_approx(current_rect.position) \
			or not prepare_rects[seat].size.is_equal_approx(current_rect.size):
			phase_positions_stable = false
	_check(phase_positions_stable,
		"Employee slots must keep their desk positions when entering the Workday phase.")

	root.size = Vector2i(960, 540)
	await _settle()
	var compact_view := floor_scroll.get_global_rect()
	var compact_floor := workday.sales_floor_art.get_global_rect()
	_check(compact_view.encloses(compact_floor),
		"The sales floor must scale into the supported compact viewport.")
	for card: EmployeeCard in workday.employee_cards:
		_check(compact_view.encloses(card.get_global_rect()),
			"Every employee slot must remain visible at 960x540.")

	workday.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: office art dimensions, floor rows/anchors, input transparency, phase stability, and compact layout.")
	quit(0 if failures.is_empty() else 1)
