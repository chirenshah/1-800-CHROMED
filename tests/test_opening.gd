extends SceneTree
## Godot --headless --path . --script res://tests/test_opening.gd
## Omit --headless and append -- --capture to render snapshots into /tmp.

const OPENING := preload("res://scenes/opening.tscn")

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


func _new_opening():
	var scene = OPENING.instantiate()
	scene.sequence = scene.sequence.duplicate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	return scene


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("/tmp/chromed-opening-%s.png" % name)
		_check(error == OK, "Could not capture " + name)


func _check_static_bounds(scene, screen_size: Vector2i) -> void:
	var screen := Rect2(Vector2.ZERO, Vector2(screen_size))
	var labels: Array[Control] = [scene.skip_button, scene.archive_label, scene.section_label,
		scene.footer_label]
	for path in ["Establish/Heading", "Establish/Year", "Establish/Footer", "Boot/Heading",
		"Boot/Status", "Reveal/Welcome", "Reveal/Company", "Reveal/Motto", "Reveal/Appointment",
		"Reveal/Predecessor", "Reveal/Directive"]:
		labels.append(scene.get_node(path))
	for label in labels:
		_check(screen.encloses(label.get_global_rect()), "Opening text/control outside %s: %s (%s)" % [screen_size, label.name, label.get_global_rect()])
		_check(label.size.x <= label.get_parent().size.x, "Opening line exceeds its parent: " + str(label.name))
	for paragraph: Label in scene.paragraphs:
		_check(paragraph.size.x <= scene.crawl_window.size.x, "Crawl width must wrap to its window.")
		_check(paragraph.size.y >= paragraph.get_minimum_size().y, "Wrapped crawl lines must not clip vertically.")
	_check(scene.skip_button.get_global_rect().position.y > scene.crawl_window.get_global_rect().end.y,
		"Skip control must remain outside the moving text.")


func _check_destination() -> void:
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn",
		"Opening must hand off to the existing main scene.")
	if current_scene != null and current_scene.has_node("Workday"):
		var workday = current_scene.get_node("Workday")
		_check(workday.phase == workday.Phase.PREPARE and workday.call_queue.received == 0
			and workday.day_timer.is_stopped(), "Destination must be fresh Prepare with no elapsed simulation.")
		_check(workday.employee_cards.size() == 9 and workday.staffed_seats.size() == 3,
			"Opening must not change the nine-seat prototype or staffing.")


func _remove_current() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var scene = _new_opening()
	await _settle()
	_check(scene.stage == scene.Stage.ESTABLISH and scene.paragraphs.size() == 9,
		"Opening must establish the year and load all narrative paragraphs.")
	_check(not scene.has_node("Workday"), "Workday must not run beneath the cinematic.")
	_check(scene.skip_button.has_focus(), "Keyboard/gamepad users must have a focused skip control.")
	_check(scene.crawl_height > 0, "The crawl must be laid out on initial startup.")
	# Sample the entire presentation at the supported minimum, base and a taller window.
	for screen_size in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1280, 1024)]:
		root.size = screen_size
		await _settle()
		_check_static_bounds(scene, screen_size)
		for stage in [scene.Stage.ESTABLISH, scene.Stage.CRAWL, scene.Stage.BOOT, scene.Stage.REVEAL]:
			scene._set_stage(stage)
			scene._process(scene._duration() * 0.8)
			await _settle()
			await _capture("%s-%d" % [str(stage), screen_size.y])
		scene._set_stage(scene.Stage.CRAWL)
		scene._process(scene.sequence.crawl_seconds * 0.5)
		_check(is_equal_approx(scene.crawl_text.position.y,
			(scene.crawl_window.size.y - scene.crawl_height) * 0.5), "Crawl position must use normalized timing after a resize.")
		await _capture("crawl-middle-%d" % screen_size.y)
	# A long frame must carry time forward, rather than dropping a narrative beat.
	scene._set_stage(scene.Stage.ESTABLISH)
	scene._process(scene.sequence.establish_seconds + scene.sequence.crawl_seconds + 0.5)
	_check(scene.stage == scene.Stage.BOOT and is_equal_approx(scene.stage_elapsed, 0.5),
		"Long frames must preserve elapsed time through stage boundaries.")
	scene._process(scene.sequence.boot_seconds)
	_check(scene.stage == scene.Stage.REVEAL, "Boot must lead to the company reveal.")
	scene._process(scene.sequence.reveal_seconds + scene.sequence.fade_seconds)
	await _settle()
	_check_destination()
	await _remove_current()
	# Exercise real input routing, and repeated skip requests during the fade.
	for key in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
		scene = _new_opening()
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		await _settle()
		_check(scene.stage == scene.Stage.EXIT, "Skip key must bypass the whole opening: " + str(key))
		scene.skip()
		scene._process(scene.sequence.fade_seconds + 0.01)
		await _settle()
		_check_destination()
		await _remove_current()
	# Mouse/touch reaches the Button's pressed signal from any presentation stage.
	for stage in [0, 1, 2, 3]:
		scene = _new_opening()
		scene._set_stage(stage)
		scene.skip_button.pressed.emit()
		_check(scene.stage == scene.Stage.EXIT, "Skip button must work during every stage.")
		scene._process(scene.sequence.fade_seconds + 0.01)
		await _settle()
		_check_destination()
		await _remove_current()
	# Development switches must skip without waiting for animation time.
	ProjectSettings.set_setting("chromed/opening/enabled", false)
	scene = _new_opening()
	await _settle()
	_check_destination()
	await _remove_current()
	ProjectSettings.set_setting("chromed/opening/enabled", true)
	scene = OPENING.instantiate()
	scene.enabled = false
	root.add_child(scene)
	current_scene = scene
	await _settle()
	_check_destination()
	await _remove_current()
	# Finally let the real process loop complete an accelerated resource naturally.
	scene = _new_opening()
	scene.sequence.establish_seconds = 0.1
	scene.sequence.crawl_seconds = 0.1
	scene.sequence.boot_seconds = 0.1
	scene.sequence.reveal_seconds = 0.1
	scene.sequence.fade_seconds = 0.1
	scene.set_process(true)
	await create_timer(0.8).timeout
	_check_destination()
	await _remove_current()
	if failures.is_empty():
		print("PASS: opening layout, timeline, input/button skip, development bypass, and fresh Prepare handoff.")
	quit(0 if failures.is_empty() else 1)
