extends SceneTree
## Godot --headless --path . --script res://tests/test_sales_slam.gd

var failures: Array[String] = []
var plan := SalesSlamPlan.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _sales(values: Array) -> Array[Dictionary]:
	var sales: Array[Dictionary] = []
	for value in values:
		sales.append({"value": int(value), "employee_id": "nina"})
	return sales


func _breaks(steps: Array) -> int:
	var count := 0
	for step in steps:
		if step["breaks_goal"]:
			count += 1
	return count


func _test_plan() -> void:
	var sorted := plan.sort_sales(_sales([300, 50, 300, 120]))
	var values: Array = []
	for sale in sorted:
		values.append(sale["value"])
	_check(values == [50, 120, 300, 300], "Sales replay in ascending value order.")
	_check(plan.intensity(0) == plan.min_intensity and plan.intensity(100000) == plan.max_intensity,
		"Intensity clamps to its configured bounds.")
	_check(plan.intensity(100) < plan.intensity(400), "Bigger sales hit harder.")
	_check(plan.total(_sales([100, 200, 50])) == 350, "Total is the sum of recorded sales.")

	var sales := _sales([400, 350, 251])
	_check(_breaks(plan.build(sales, 1000)) == 1, "Barely exceeding the goal breaks it exactly once.")
	_check(_breaks(plan.build(_sales([400, 350, 250]), 1000)) == 0, "Exactly equal never demolishes.")
	_check(_breaks(plan.build(_sales([400, 300]), 1000)) == 0, "Falling short never demolishes.")
	_check(_breaks(plan.build(_sales([300, 450, 600, 900, 700]), 1000)) == 1, "Many sales past the goal still break only once.")
	_check(_breaks(plan.build(_sales([5000]), 1000)) == 1, "A single huge sale can break the goal.")
	_check(plan.build([], 1000).is_empty(), "No sales produce no steps.")

	var steps := plan.build(_sales([400, 350, 251]), 1000)
	_check(steps[steps.size() - 1]["tally_after"] == 1001 and steps[0]["tally_before"] == 0,
		"Step tallies chain from zero to the recorded total.")
	_check(plan.stage_for(499, 1000) == SalesSlamPlan.Stage.IDLE and plan.stage_for(500, 1000) == SalesSlamPlan.Stage.WARM
		and plan.stage_for(750, 1000) == SalesSlamPlan.Stage.HOT and plan.stage_for(900, 1000) == SalesSlamPlan.Stage.STRAINED
		and plan.stage_for(1000, 1000) == SalesSlamPlan.Stage.REACHED and plan.stage_for(1001, 1000) == SalesSlamPlan.Stage.EXCEEDED,
		"Tension stages trip at 50/75/90% and 100% is reached, not exceeded.")

	var many: Array = []
	for index in 200:
		many.append(40 + index % 60)
	var long_steps := plan.build(_sales(many), 1000)
	_check(plan.total_seconds(long_steps) <= plan.max_total_seconds + 0.01, "Long replays compress to the time budget.")

	for scenario in SalesSlamScenarios.all():
		var scenario_steps := plan.build(scenario["sales"], scenario["goal"])
		var expect := 1 if plan.total(scenario["sales"]) > scenario["goal"] else 0
		_check(_breaks(scenario_steps) == expect, "Scenario '%s' demolition count." % scenario["name"])


func _play(board: SalesSlamBoard, scenario: Dictionary) -> Dictionary:
	var holder := {"result": {}}
	var capture := func(result: Dictionary) -> void: holder["result"] = result
	board.finished.connect(capture)
	board.play(scenario["sales"], scenario["goal"])
	var frames := 0
	while board.running and frames < 600:
		await process_frame
		frames += 1
	board.finished.disconnect(capture)
	return holder["result"]


func _test_board() -> void:
	var board := SalesSlamBoard.new()
	board.time_scale = 100.0
	board.size = Vector2(900, 500)
	root.add_child(board)
	board.audio.enabled = false
	await process_frame
	for scenario in SalesSlamScenarios.all():
		var result: Dictionary = await _play(board, scenario)
		var recorded := plan.total(scenario["sales"])
		var expected_demolitions := 1 if recorded > scenario["goal"] else 0
		_check(not result.is_empty() and result["total"] == recorded, "'%s' finishes on the recorded total." % scenario["name"])
		_check(board.displayed_total() == recorded, "'%s' counter shows the recorded total." % scenario["name"])
		_check(board.demolition_count == expected_demolitions, "'%s' demolition count." % scenario["name"])
		_check(board.running == false, "'%s' stops running." % scenario["name"])

	var big := SalesSlamScenarios.named("Greatly exceeding")
	board.time_scale = 1.0
	board.play(big["sales"], big["goal"])
	await process_frame
	board.skip()
	_check(not board.running and board.displayed_total() == plan.total(big["sales"]) and board.demolition_count == 1,
		"Skipping jumps to the correct final state with one demolition.")
	board.skip()
	_check(board.demolition_count == 1, "A second skip changes nothing.")

	var sales: Array[Dictionary] = big["sales"].duplicate(true)
	board.play(sales, big["goal"])
	board.stop()
	_check(not board.running and sales == big["sales"], "Stopping leaves the recorded sales untouched.")
	board.queue_free()
	await process_frame


func _test_simulation() -> void:
	var queue := CallQueueSimulation.new()
	queue.reset()
	_check(queue.sale_log.is_empty() and queue.revenue == 0, "A fresh simulation has no sales or revenue.")
	queue.revenue = 999
	queue.sale_log.append({"id": 1, "value": 999, "employee_id": "nina", "recovery": false})
	queue.reset()
	_check(queue.revenue == 0 and queue.sale_log.is_empty(), "Reset clears revenue and the sale log between days.")


func _test_workday() -> void:
	var scene = load("res://scenes/workday.tscn").instantiate()
	root.add_child(scene)
	for frame in range(4):
		await process_frame
	scene._start_day()
	scene.day_timer.stop()
	scene.call_queue.sale_log.append({"id": 1, "value": 400, "employee_id": "nina", "recovery": false})
	scene.call_queue.revenue = 400
	var budget_before: int = scene.augment_manager.budget
	scene._finish_day()
	_check(scene.augment_manager.budget == budget_before + 400, "The day's revenue is credited exactly once.")
	_check(scene.slam_board.visible and scene.slam_board.running, "The report phase launches the slam board.")
	_check(scene.slam_board.goal == scene.score_target(scene.day), "The board uses the day's score target.")
	scene.slam_board.skip()
	_check(scene.augment_manager.budget == budget_before + 400 and scene.call_queue.revenue == 400,
		"Playing the board never changes revenue or budget.")
	scene._prepare_next_day()
	await process_frame
	_check(not scene.slam_board.visible and not scene.slam_board.running, "Leaving the report hides the board.")
	scene.queue_free()
	await process_frame


func _test_feel() -> void:
	var light := plan.step_seconds(0.2, 0, 10000)
	var heavy := plan.step_seconds(1.0, 0, 10000)
	_check(is_equal_approx(light, plan.beat_seconds) and is_equal_approx(heavy, plan.beat_seconds * 2.0),
		"Light sales take one beat and heavy sales take two.")
	_check(plan.step_seconds(0.2, 600, 1000) < light, "Steps accelerate as the tally builds toward the goal.")
	_check(plan.step_seconds(0.2, 950, 1000) > plan.step_seconds(0.2, 600, 1000),
		"Steps just before the goal stretch out for anticipation.")
	var steps := plan.build(_sales([100, 100, 100, 100, 700, 100]), 1000)
	var windups := 0
	for step in steps:
		if step["windup"] > 0.0:
			windups += 1
			_check(step["breaks_goal"], "Only the goal-breaking sale has a windup.")
	_check(windups == 1, "Exactly one windup per breaking day.")
	_check(plan.build(_sales([400, 300]), 1000)[0]["windup"] == 0.0, "A short day has no windup.")
	var many: Array = []
	for index in 120:
		many.append(30 + index % 40)
	_check(plan.total_seconds(plan.build(_sales(many), 1000)) <= plan.max_total_seconds + 0.01,
		"Windup and break time still fit the total budget.")


func _test_audio() -> void:
	var audio := SalesSlamAudio.new()
	for key in ["impact", "impact_heavy", "tick", "riser", "chime", "boom", "fail", "final"]:
		var stream: AudioStreamWAV = audio._stream_for(key)
		_check(stream.data.size() > 1000 and stream.mix_rate == SalesSlamAudio.RATE, "Placeholder sound '%s' is synthesized." % key)
	audio.free()


func _run() -> void:
	_test_plan()
	_test_feel()
	_test_audio()
	await _test_board()
	_test_simulation()
	await _test_workday()
	if failures.is_empty():
		print("PASS: Sales Slam ordering, intensity, stages, goal-breaking, pacing, board playback, skip, and revenue integrity.")
	quit(0 if failures.is_empty() else 1)
