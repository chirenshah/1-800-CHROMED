extends SceneTree
## Godot --headless --path . --script res://tests/test_music.gd

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


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _settle()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	await _settle()
	var music = root.get_node("MusicPlayer")
	var music_bus := AudioServer.get_bus_index("Music")
	_check(music.playing and music.stream is AudioStreamOggVorbis and music.stream.loop,
		"The supplied Ogg must start automatically and loop.")
	_check(music_bus > 0 and music.bus == &"Music" and is_equal_approx(music.volume_db, -18.0),
		"Music must use its own bus at the configured background level.")
	# Capture the final mix to verify decoding and that mute actually silences output.
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	AudioServer.add_bus_effect(0, capture)
	music.seek(15.0)
	await create_timer(0.3).timeout
	_check(_peak(capture) > 0.00001, "The soundtrack must produce non-silent decoded audio.")
	change_scene_to_file("res://scenes/opening.tscn")
	await _settle()
	var opening = current_scene
	opening.set_process(false)
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport_size
		await _settle()
		_check(Rect2(Vector2.ZERO, root.size).encloses(opening.music_button.get_global_rect()),
			"The music control must fit the opening at each supported size.")
		_check(not opening.music_button.get_global_rect().intersects(opening.skip_button.get_global_rect()),
			"Music and Skip controls must not overlap.")
		await _capture("opening-%d" % viewport_size.x)
	opening.music_button.grab_focus()
	await _key(KEY_SPACE)
	_check(music.muted and opening.music_button.text == "Music: Off"
		and opening.stage == opening.Stage.ESTABLISH,
		"Keyboard activation must mute music without skipping the opening.")
	_check(AudioServer.is_bus_mute(music_bus) and not AudioServer.is_bus_mute(0),
		"Music mute must leave the master bus available for other sounds.")
	await create_timer(0.15).timeout
	capture.clear_buffer()
	await create_timer(0.2).timeout
	_check(is_zero_approx(_peak(capture)), "Muted music must produce silent output.")
	var before_handoff: float = music.get_playback_position()
	await _key(KEY_ESCAPE)
	opening._process(opening.sequence.fade_seconds + 0.01)
	await _settle()
	var workday = current_scene.get_node("Workday")
	var button: Button = workday.get_node("PageMargin/Page/Header/MusicButton")
	await _capture("floor-960")
	_check(root.get_node("MusicPlayer") == music and music.get_playback_position() >= before_handoff,
		"Skipping into the sales floor must preserve the same player and playback position.")
	_check(button.text == "Music: Off" and music.muted,
		"Mute state must carry from the opening to the workday control.")
	button.pressed.emit()
	_check(not music.muted and button.text == "Music: On", "The workday control must restore music.")
	await create_timer(0.2).timeout
	capture.clear_buffer()
	await create_timer(0.2).timeout
	_check(_peak(capture) > 0.00001, "Restoring music must restore audible samples.")
	workday._start_day()
	workday._toggle_pause()
	var before_pause: float = music.get_playback_position()
	await create_timer(0.2).timeout
	_check(music.get_playback_position() > before_pause, "Music must continue while the workday is paused.")
	# Exercise a real end-of-track boundary without waiting through the six-minute song.
	music.seek(music.stream.get_length() - 0.15)
	await create_timer(0.5).timeout
	_check(music.playing and music.get_playback_position() < 2.0,
		"Reaching the track's end must loop back to its beginning.")
	AudioServer.remove_bus_effect(0, 0)
	current_scene.free()
	current_scene = null
	if failures.is_empty():
		print("PASS: music decoding, looping, scene continuity, pause, keyboard controls, and mute output.")
	quit(0 if failures.is_empty() else 1)


func _peak(capture: AudioEffectCapture) -> float:
	var peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak


func _capture(label: String) -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("/tmp/chromed-music-%s.png" % label) == OK,
			"Could not save music control preview.")
