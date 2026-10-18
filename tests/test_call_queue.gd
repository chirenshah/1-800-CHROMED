extends SceneTree
## Run with: Godot --headless --path . --script res://tests/test_call_queue.gd
## Omit --headless and append -- --capture to save UI snapshots in /tmp.

const MODEL := preload("res://scripts/call_queue_simulation.gd")

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
	await _test_timer_scheduling()
	if failures.is_empty():
		print("PASS: queue accounting, FIFO and seat priority, pause, closing report, next day, and responsive layout.")
	quit(0 if failures.is_empty() else 1)


func _test_model() -> void:
	var model := MODEL.new()
	model.reset(["nina", "zip", "", "victoria", "", "", "", "", ""], 123)
	model.next_arrival_seconds = INF
	model.receive_call()
	model.receive_call()
	_check(model.active[0]["id"] == 1 and model.active[1]["id"] == 2,
		"The oldest callers must reach the earliest available staffed seats.")
	_check(model.handled == 0, "Assigning a call must not count it as handled.")
	model.receive_call()
	model.receive_call()
	_check(model.active[3]["id"] == 3 and model.waiting[0]["id"] == 4,
		"Busy seats must be skipped while older callers keep their place.")
	for step in range(100):
		model.receive_call()
		model.advance()
		_check(model.received == model.handled + model.abandoned + model.active.size() + model.waiting.size(),
			"Every received call must be handled, abandoned, active, or waiting exactly once.")
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
	model.reset([], 321)
	_check(model.received == 0 and model.handled == 0 and model.revenue == 0
		and model.sales == 0 and model.active.is_empty() and model.waiting.is_empty()
		and model.last_dispatch.is_empty(), "Reset must clear all daily queue state.")
	model.receive_call()
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


func _queue_snapshot(scene) -> String:
	return var_to_str([scene.call_queue.elapsed_seconds, scene.call_queue.next_arrival_seconds, scene.call_queue.elapsed_ticks, scene.call_queue.received,
		scene.call_queue.handled, scene.call_queue.abandoned, scene.call_queue.active,
		scene.call_queue.waiting, scene.call_queue.employee_results()])


func _test_scene() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	# Load scenes after autoload initialization so UI dependencies are available.
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	# Preserve open-seat UI coverage now that the default floor is fully staffed.
	scene._bench_employee(2)
	_check(scene.call_queue.received == 0 and scene.queue_panel.empty_label.visible,
		"Prepare must start with an empty queue.")
	_check_bounds(scene, root.size)
	await _capture("prepare")
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = size
		scene._start_day()
		scene.day_timer.stop()
		# Explicit fixture load guarantees queue overflow regardless of sampled arrivals.
		for index in range(18):
			scene.call_queue.receive_call()
		scene._simulate_tick(0.25)
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
		var before := _queue_snapshot(scene)
		scene._simulate_tick()
		scene.day_timer.wait_time = 0.01
		scene.day_timer.start()
		await create_timer(0.05).timeout
		_check(before == _queue_snapshot(scene),
			"Pause must freeze the sampled arrival countdown, patience, handling, counters, and employee workload.")
		_check(scene.queue_panel.state_label.text == "PAUSED", "The queue must visibly indicate pause.")
		scene.day_timer.stop()
		scene._toggle_pause()
		scene._simulate_tick()
		_check(scene.call_queue.received > 0 and before != _queue_snapshot(scene),
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
		_check(scene.report_panel.abandoned_label.text == "Left while waiting  %d" % scene.call_queue.abandoned,
			"The report must include callers who abandoned the queue.")
		_check(scene.report_panel.employee_rows.get_child_count() == scene.staffed_seats.size(),
			"Report must show workload for each staffed employee.")
		var nina: Dictionary = scene.call_queue.employee_stats["nina"]
		var nina_row: Label = scene.report_panel.employee_rows.get_child(0)
		_check(nina_row.text.contains("Seat 01 · Nina")
			and nina_row.text.contains("Assigned %d · Handled %d" % [nina["assigned"], nina["handled"]])
			and nina_row.text.contains("Busy %.1fs · Idle %.1fs" % [
				float(nina["busy_ticks"]) * MODEL.TICK_SECONDS, float(nina["idle_ticks"]) * MODEL.TICK_SECONDS]),
			"Employee report rows must reflect measured assignments and simulation time.")
		_check(scene.report_panel._format_number(12345) == "12,345", "Report amounts must retain all digits.")
		_check_bounds(scene, size)
		await _capture("report-%d" % size.x)
		var report_scroll: ScrollContainer = scene.report_panel.get_node("Margin/Scroll")
		report_scroll.scroll_vertical = int(scene.report_panel.employee_rows.position.y)
		await _settle()
		for row: Label in scene.report_panel.employee_rows.get_children():
			_check(row.size.x <= report_scroll.size.x,
				"Employee workloads must wrap within the report at %s." % size)
		await _capture("workload-%d" % size.x)
		var received: int = scene.call_queue.received
		scene._simulate_tick()
		_check(scene.call_queue.received == received, "Closed days must not receive further calls.")
		report_scroll.ensure_control_visible(scene.report_panel.next_day_button)
		await _settle()
		_check(report_scroll.get_global_rect().encloses(scene.report_panel.next_day_button.get_global_rect()),
			"The next-day action must remain reachable by scrolling the extended report.")
		scene.report_panel.next_day_button.pressed.emit()
		scene.day_timer.wait_time = 0.75
		await _settle()
		_check(scene.phase == scene.Phase.PREPARE and scene.call_queue.received == 0
			and scene.call_queue.active.is_empty() and scene.call_queue.waiting.is_empty()
			and scene.revenue_label.text == "$0" and scene.queue_panel.empty_label.visible,
			"Next day must reset the queue, call cards, and daily counters.")
		_check(scene.call_queue.abandoned == 0 and scene.call_queue.employee_stats["nina"]["busy_ticks"] == 0
			and scene.employee_cards[0].status_label.text == "READY", "Next day must clear patience losses, workload, and visible busy state.")
		_check_bounds(scene, size)
	# Exercise automatic end-of-day, as well as the early-close path above.
	scene._start_day()
	scene.day_timer.stop()
	for step in range(scene.DAY_TICKS):
		# Keep the floor overloaded explicitly; random arrivals may otherwise remain serviceable.
		for index in range(4):
			scene.call_queue.receive_call()
		scene._simulate_tick()
	_check(scene.phase == scene.Phase.REPORT, "A complete day must automatically reach Report.")
	_check(scene.call_queue.received == scene.call_queue.handled + scene.call_queue.active.size()
		+ scene.call_queue.waiting.size() + scene.call_queue.abandoned,
		"Closing a day must account for every received call, including abandonment.")
	_check(scene.call_queue.abandoned > 0 and scene.report_panel.abandoned_label.text
		== "Left while waiting  %d" % scene.call_queue.abandoned,
		"A full overloaded day must report actual abandonment.")
	await _settle()
	await _capture("full-day-report")
	scene.queue_free()
	await process_frame


func _test_timer_scheduling() -> void:
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	await _settle()
	scene._start_day()
	scene.day_timer.stop()
	scene.call_queue.reset(scene.floor_plan.seats, 31)
	scene._schedule_next_event()
	_check(scene.day_timer.one_shot, "The workday timer must schedule one event at a time.")
	var first_arrival: float = scene.call_queue.next_arrival_seconds
	_check(not is_zero_approx(fmod(first_arrival, MODEL.TICK_SECONDS)),
		"The seeded timer fixture must exercise an arrival between display ticks.")

	# Emit the connected signal directly to exercise scheduling without wall-clock waits.
	scene._toggle_pause()
	var paused_snapshot := _queue_snapshot(scene)
	scene.day_timer.stop()
	scene.day_timer.timeout.emit()
	_check(paused_snapshot == _queue_snapshot(scene) and scene.day_timer.is_stopped(),
		"A timeout received while paused must neither advance the model nor restart the timer.")
	scene._toggle_pause()
	scene._schedule_next_event()
	var saw_first_arrival := false
	var day_seconds: float = scene.DAY_TICKS * MODEL.TICK_SECONDS
	for event_index in range(500):
		if scene.phase != scene.Phase.PLAY:
			break
		var before: float = scene.call_queue.elapsed_seconds
		var expected_delay: float = minf(day_seconds - before, scene.call_queue.time_until_next_event())
		var scheduled_delay: float = scene.day_timer.wait_time
		_check(not scene.day_timer.is_stopped() and is_equal_approx(scheduled_delay, expected_delay),
			"Each timer restart must target the next model event or the day boundary.")
		scene.day_timer.stop()
		scene.day_timer.timeout.emit()
		_check(is_equal_approx(scene.call_queue.elapsed_seconds, before + scheduled_delay),
			"The connected timer timeout must advance by its precise scheduled duration.")
		if not saw_first_arrival and scene.call_queue.received > 0:
			saw_first_arrival = true
			_check(scene.call_queue.received == 1 and is_equal_approx(scene.call_queue.elapsed_seconds, first_arrival),
				"The timer must receive the first call at its sampled off-tick deadline.")
		if scene.phase == scene.Phase.PLAY:
			_check(not scene.day_timer.is_stopped(), "A live timeout must schedule the next event automatically.")
	_check(saw_first_arrival, "The timer-driven day must process its first sampled arrival.")
	_check(scene.phase == scene.Phase.REPORT and scene.day_timer.is_stopped()
		and is_equal_approx(scene.call_queue.elapsed_seconds, day_seconds),
		"The timer-driven day must close exactly at DAY_TICKS times TICK_SECONDS and stop scheduling.")
	var closed_snapshot := _queue_snapshot(scene)
	scene.day_timer.timeout.emit()
	_check(closed_snapshot == _queue_snapshot(scene) and scene.day_timer.is_stopped(),
		"A late timeout after closing must leave the report model unchanged and the timer stopped.")
	scene.queue_free()
	await process_frame
