extends SceneTree
## Godot --headless --path . --script res://tests/test_inventory_panel_layout.gd

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


func _check_cell_sizes(panel: InventoryPanel) -> void:
	var size_source := panel.get_parent() as Control
	var available_width := maxf(0.0, size_source.size.x - 32.0)
	var cell_width := maxf(64.0, (available_width / 2.0 - 30.0) / 6.0)
	var available_height := maxf(0.0, size_source.size.y - 42.0)
	var expected_person_size := Vector2(cell_width, maxf(52.0, available_height))
	var expected_item_size := Vector2(cell_width, maxf(34.0, (available_height - 6.0) / 2.0))
	var person_sizes_match := true
	for cell in panel.person_cells:
		if not cell.custom_minimum_size.is_equal_approx(expected_person_size):
			person_sizes_match = false
			break
	_check(person_sizes_match,
		"Reserve cells must match %s; first cell is %s at panel size %s." % [
			expected_person_size, panel.person_cells[0].custom_minimum_size, size_source.size,
		])
	var item_sizes_match := true
	for cell in panel.item_cells:
		if not cell.custom_minimum_size.is_equal_approx(expected_item_size):
			item_sizes_match = false
			break
	_check(item_sizes_match,
		"Item cells must match %s; first cell is %s at panel size %s." % [
			expected_item_size, panel.item_cells[0].custom_minimum_size, size_source.size,
		])


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var music_player := root.get_node("MusicPlayer") as AudioStreamPlayer
	music_player.stop()
	music_player.stream = null
	var workday: Control = load("res://scenes/workday.tscn").instantiate()
	root.add_child(workday)
	await _settle()
	var panel := workday.get_node("PageMargin/Page/BottomPanel/InventoryPanel") as InventoryPanel
	_check(panel.visible, "Prepare must show the inventory panel.")
	_check_cell_sizes(panel)

	for viewport_size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = viewport_size
		await _settle()
		_check_cell_sizes(panel)
		panel.hide_all()
		panel.show_all()
		await _settle()

	await create_timer(12.0).timeout
	_check_cell_sizes(panel)
	workday.queue_free()
	await process_frame
	panel = null
	workday = null
	await process_frame
	if failures.is_empty():
		print("PASS: Inventory sizing remains stable through phase visibility changes, viewport resizes, and a 12-second idle soak.")
	quit(0 if failures.is_empty() else 1)
