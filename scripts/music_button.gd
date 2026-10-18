extends Button
## Scene-local control for the persistent soundtrack.

@onready var music = get_node("/root/MusicPlayer")


func _ready() -> void:
	pressed.connect(_toggle_music)
	music.muted_changed.connect(_update_state)
	_update_state(music.muted)


func _toggle_music() -> void:
	music.set_muted(not music.muted)


func _update_state(muted: bool) -> void:
	text = "Music: Off" if muted else "Music: On"
	tooltip_text = "Turn background music on." if muted else "Mute background music."
