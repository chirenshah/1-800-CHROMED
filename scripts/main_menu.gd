extends Control

const OPENING_SCENE := "res://scenes/opening.tscn"
const FLOOR_SCENE := "res://scenes/main.tscn"
const BACKGROUND := Color(0.018, 0.027, 0.043)
const TEAL := Color(0.38, 0.89, 0.8)

@onready var home: VBoxContainer = %Home
@onready var settings: VBoxContainer = %Settings
@onready var new_quarter_button: Button = %NewQuarter
@onready var resume_button: Button = %Resume
@onready var settings_button: Button = %OpenSettings
@onready var back_button: Button = %Back
@onready var music_toggle: CheckButton = %MusicToggle
@onready var music_slider: HSlider = %MusicVolume
@onready var volume_value: Label = %VolumeValue
@onready var notice: Label = %Notice
@onready var replace_overlay: Control = %ReplaceOverlay
@onready var cancel_new_quarter: Button = %CancelNewQuarter
@onready var confirm_new_quarter: Button = %ConfirmNewQuarter
@onready var music = get_node("/root/MusicPlayer")


func _ready() -> void:
	new_quarter_button.pressed.connect(_request_new_quarter)
	resume_button.pressed.connect(_resume_quarter)
	settings_button.pressed.connect(_show_settings)
	back_button.pressed.connect(_show_home)
	cancel_new_quarter.pressed.connect(_close_replace_confirmation)
	confirm_new_quarter.pressed.connect(_confirm_new_quarter)
	music_toggle.toggled.connect(_update_music_toggle)
	music_slider.value_changed.connect(_set_music_volume)
	resized.connect(queue_redraw)
	_refresh_resume()
	new_quarter_button.grab_focus()


func _request_new_quarter() -> void:
	if RunSave.has_save():
		replace_overlay.show()
		new_quarter_button.disabled = true
		resume_button.disabled = true
		settings_button.disabled = true
		cancel_new_quarter.grab_focus()
	else:
		_start_quarter()


func _close_replace_confirmation() -> void:
	replace_overlay.hide()
	new_quarter_button.disabled = false
	settings_button.disabled = false
	_refresh_resume()
	new_quarter_button.grab_focus()


func _confirm_new_quarter() -> void:
	_close_replace_confirmation()
	_start_quarter()


func _start_quarter() -> void:
	RunSave.pending_resume = {}
	RunSave.session_active = true
	if not _open_scene(OPENING_SCENE):
		RunSave.session_active = false


func _resume_quarter() -> void:
	var checkpoint := RunSave.load()
	if checkpoint.is_empty():
		_refresh_resume()
		notice.text = "The saved quarter could not be opened."
		return
	RunSave.pending_resume = checkpoint
	RunSave.session_active = true
	if not _open_scene(FLOOR_SCENE):
		RunSave.pending_resume = {}
		RunSave.session_active = false


func _open_scene(path: String) -> bool:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		notice.text = "The quarter could not be opened."
		push_error("Main menu could not open %s (error %d)." % [path, error])
	return error == OK


func _refresh_resume() -> void:
	resume_button.disabled = not RunSave.has_save()
	resume_button.tooltip_text = "Complete a workday to create a save." if resume_button.disabled else "Continue from your latest autosave."


func _show_settings() -> void:
	home.hide()
	settings.show()
	var bus_index := AudioServer.get_bus_index(music.bus)
	music_slider.set_value_no_signal(roundf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0))
	volume_value.text = "%d%%" % int(music_slider.value)
	_update_music_toggle(not music.muted)
	back_button.grab_focus()


func _show_home() -> void:
	settings.hide()
	home.show()
	settings_button.grab_focus()


func _update_music_toggle(enabled: bool) -> void:
	music_toggle.set_pressed_no_signal(enabled)
	music.set_muted(not enabled)


func _set_music_volume(value: float) -> void:
	var bus_index := AudioServer.get_bus_index(music.bus)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value / 100.0, 0.0001)))
	volume_value.text = "%d%%" % int(value)


func _unhandled_input(event: InputEvent) -> void:
	if replace_overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_replace_confirmation()
		get_viewport().set_input_as_handled()
	elif settings.visible and event.is_action_pressed("ui_cancel"):
		_show_home()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	var frame := Rect2(Vector2(28, 28), size - Vector2(56, 56))
	var grid_color := Color(0.14, 0.30, 0.34, 0.2)
	for x in range(80, int(frame.end.x), 80):
		draw_line(Vector2(x, frame.position.y), Vector2(x, frame.end.y), grid_color)
	for y in range(80, int(frame.end.y), 80):
		draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), grid_color)
	draw_rect(frame, Color(0.18, 0.32, 0.36, 0.7), false, 1.0)
	draw_line(frame.position, frame.position + Vector2(68, 0), TEAL, 2.0)
	draw_line(frame.end - Vector2(68, 0), frame.end, TEAL, 2.0)
