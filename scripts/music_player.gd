extends AudioStreamPlayer
## One soundtrack for the opening and every workday, independent of scene changes.

signal muted_changed(muted: bool)

var muted := false


func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), muted)
	muted_changed.emit(muted)
