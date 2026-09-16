extends Node
## Lightweight one-shot player for the original generated 8-bit WAV set.

const PATHS := {
	&"ui": "res://Assets/Audio/ui.wav",
	&"count": "res://Assets/Audio/count.wav",
	&"go": "res://Assets/Audio/go.wav",
	&"bounce": "res://Assets/Audio/bounce.wav",
	&"slap": "res://Assets/Audio/slap.wav",
	&"power": "res://Assets/Audio/power.wav",
	&"out": "res://Assets/Audio/out.wav",
	&"double": "res://Assets/Audio/double.wav",
	&"victory": "res://Assets/Audio/victory.wav",
}

var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var enabled := true

func _ready() -> void:
	for sound in PATHS:
		_streams[sound] = load(PATHS[sound])

func play(sound: StringName, volume_db := -4.0, min_gap := 0.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -100.0)) < min_gap:
		return
	_last_played[sound] = now
	var player := AudioStreamPlayer.new()
	player.stream = _streams[sound]
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()
