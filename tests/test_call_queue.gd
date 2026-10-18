extends SceneTree
## Run with: Godot --headless --path . --script res://tests/test_call_queue.gd
## Omit --headless and append -- --capture to save UI snapshots in /tmp.

const MODEL := preload("res://scripts/call_queue_simulation.gd")
const WORKDAY := preload("res://scenes/workday.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	_test_model()
	await _test_scene()
	if failures.is_empty():
		print("PASS: queue accounting, FIFO and seat priority, pause, closing report, next day, and responsive layout.")
	quit(0 if failures.is_empty() else 1)


func _test_model() -> void:
	var model := MODEL.new()
	model.reset([3, 1, 0])
	model.advance()
	_check(model.active[0]["id"] == 1 and model.active[1]["id"] == 2,
		"The oldest callers must reach the earliest available staffed seats.")
	_check(model.handled == 0, "Assigning a call must not count it as handled.")
	model.advance()
	_check(model.active[3]["id"] == 3 and model.waiting[0]["id"] == 4,
		"Busy seats must be skipped while older callers keep their place.")
	for step in range(100):
		model.advance()
		_check(model.received == model.handled + model.active.size() + model.waiting.size(),
			"Every received call must be handled, active, or waiting exactly once.")
		var ids: Array[int] = []
		for seat in model.active:
			_check(seat in [0, 1, 3], "An unstaffed seat must never receive a call.")
			_check(model.active[seat]["remaining"] > 0, "Finished calls must leave active seats.")
			ids.append(model.active[seat]["id"])
		var previous_id := 0
		for call in model.waiting:
			_check(call["id"] > previous_id, "Waiting callers must retain FIFO order.")
			previous_id = call["id"]
			_check(not ids.has(call["id"]), "A caller must not be both waiting and active.")
			ids.append(call["id"])
		_check(model.sales <= model.handled, "Only a completed interaction can produce a sale.")
	model.reset([])
	_check(model.received == 0 and model.handled == 0 and model.revenue == 0
		and model.sales == 0 and model.active.is_empty() and model.waiting.is_empty()
		and model.last_dispatch.is_empty(), "Reset must clear all daily queue state.")
	model.advance()
	_check(model.active.is_empty() and model.waiting.size() == model.received,
		"Without staff, incoming calls must remain waiting.")


func _settle() -> void:
	for frame in range(6):
		await process_frame


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("/tmp/chromed-queue-%s.png" % name)
		_check(error == OK, "Unable to save UI snapshot: " + name)


func _check_bounds(scene, size: Vector2i) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var controls: Array[Control] = [scene.primary_button, scene.pause_button,
		scene.floor_grid.get_parent(), scene.report_panel if scene.report_panel.visible else scene.queue_panel]
	for control in controls:
		if control.is_visible_in_tree():
			_check(screen.encloses(control.get_global_rect()),
				"Control falls outside %s: %s (%s)" % [size, control.name, control.get_global_rect()])


func _test_scene() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var scene = WORKDAY.instantiate()
	root.add_child(scene)
	await _settle()
	_check(scene.call_queue.received == 0 and scene.queue_panel.empty_label.visible,
		"Prepare must start with an empty queue.")
	_check_bounds(scene, root.size)
	await _capture("prepare")
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		scene._start_day()
		scene.day_timer.stop()
		for step in range(8):
			scene._simulate_tick()
		await _settle()
		_check(scene.queue_panel.waiting_label.text == str(scene.call_queue.waiting.size()),
			"The queue counter must match the waiting calls.")
		_check(scene.queue_panel.more_label.visible, "A long queue must show its overflow count.")
		var first_row: Label = scene.queue_panel.rows.get_child(0).get_node("Margin/Content/CallId")
		_check(first_row.text == "Call #%03d" % scene.call_queue.waiting[0]["id"],
			"The first displayed caller must be the next waiting caller.")
		_check(scene.employee_cards[2].status_label.text == "OPEN SEAT",
			"An unassigned employee card must remain an open seat.")
		_check_bounds(scene, size)
		await _capture("live-%d" % size.x)
		scene._toggle_pause()
		var before: String = var_to_str([scene.call_queue.received, scene.call_queue.active, scene.call_queue.waiting])
		scene._simulate_tick()
		scene.day_timer.wait_time = 0.01
		scene.day_timer.start()
		await create_timer(0.05).timeout
		_check(before == var_to_str([scene.call_queue.received, scene.call_queue.active, scene.call_queue.waiting]),
			"Pause must freeze incoming calls, waiting order, and active progress.")
		_check(scene.queue_panel.state_label.text == "PAUSED", "The queue must visibly indicate pause.")
		scene.day_timer.stop()
		scene._toggle_pause()
		scene._simulate_tick()
		_check(scene.call_queue.received > 0 and before != var_to_str(
			[scene.call_queue.received, scene.call_queue.active, scene.call_queue.waiting]),
			"Calls must continue after resume.")
		scene._toggle_pause()
		scene._finish_day()
		await _settle()
		_check(scene.phase == scene.Phase.REPORT and not scene.day_timer.paused
			and scene.day_timer.is_stopped(), "Ending a paused day must safely stop the timer.")
		_check(scene.report_panel.calls_label.text == "Calls handled  %d" % scene.call_queue.handled,
			"The report must use completed calls, not received calls, as handled calls.")
		_check(scene.report_panel.waiting_label.text == "Waiting at close  %d" % scene.call_queue.waiting.size()
			and scene.report_panel.unfinished_label.text == "Unfinished calls  %d" % scene.call_queue.active.size(),
			"The report must account for waiting and unfinished calls at close.")
		_check(scene.report_panel._format_number(12345) == "12,345", "Report amounts must retain all digits.")
		_check_bounds(scene, size)
		await _capture("report-%d" % size.x)
		var received: int = scene.call_queue.received
		scene._simulate_tick()
		_check(scene.call_queue.received == received, "Closed days must not receive further calls.")
		scene._prepare_next_day()
		scene.day_timer.wait_time = 0.75
		await _settle()
		_check(scene.phase == scene.Phase.PREPARE and scene.call_queue.received == 0
			and scene.call_queue.active.is_empty() and scene.call_queue.waiting.is_empty()
			and scene.revenue_label.text == "$0" and scene.queue_panel.empty_label.visible,
			"Next day must reset the queue, call cards, and daily counters.")
		_check_bounds(scene, size)
	# Exercise automatic end-of-day, as well as the early-close path above.
	scene._start_day()
	scene.day_timer.stop()
	for step in range(scene.DAY_TICKS):
		scene._simulate_tick()
	_check(scene.phase == scene.Phase.REPORT, "A complete day must automatically reach Report.")
	_check(scene.call_queue.received == scene.call_queue.handled + scene.call_queue.active.size()
		+ scene.call_queue.waiting.size(), "Closing a day must retain every outstanding call in the report state.")
	scene.queue_free()
	await process_frame
