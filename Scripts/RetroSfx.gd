extends Node
## Layered original 16-bit-era arcade voices, with bounded polyphony.

const PATHS := {
	&"dribble": "res://Assets/Audio/dribble.wav",
	&"steal": "res://Assets/Audio/steal.wav",
	&"toss": "res://Assets/Audio/toss.wav",
	&"jump": "res://Assets/Audio/jump.wav",
	&"ui": "res://Assets/Audio/ui.wav",
	&"count": "res://Assets/Audio/count.wav",
	&"go": "res://Assets/Audio/go.wav",
	&"bounce": "res://Assets/Audio/bounce.wav",
	&"slap": "res://Assets/Audio/slap.wav",
	&"power": "res://Assets/Audio/power.wav",
	&"out": "res://Assets/Audio/out.wav",
	&"double": "res://Assets/Audio/double.wav",
	&"victory": "res://Assets/Audio/victory.wav",
	&"crowd_cheer": "res://Assets/Audio/crowd_cheer.wav",
	&"crowd_boo": "res://Assets/Audio/crowd_boo.wav",
	&"crowd_shout_a": "res://Assets/Audio/crowd_shout_a.wav",
	&"crowd_shout_b": "res://Assets/Audio/crowd_shout_b.wav",
	&"crowd_shout_c": "res://Assets/Audio/crowd_shout_c.wav",
}
const MUSIC_PATHS := [
	"res://Assets/Audio/Music/schoolyard_sprint.wav",
	"res://Assets/Audio/Music/county_line_clash.wav",
	"res://Assets/Audio/Music/capital_circuit.wav",
	"res://Assets/Audio/Music/city_lights.wav",
	"res://Assets/Audio/Music/world_final.wav",
]

var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var enabled := true
var music_enabled := true
var _music_player: AudioStreamPlayer
var _music_key := ""
var _music_generation := 0

func _ready() -> void:
	_setup_buses()
	for sound in PATHS:
		_streams[sound] = load(PATHS[sound])
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = &"MUSIC"
	_music_player.volume_db = -17.0
	add_child(_music_player)

func _setup_buses() -> void:
	if AudioServer.get_bus_index(&"SFX") < 0:
		AudioServer.add_bus()
		var sfx_bus := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_bus, &"SFX")
		var room := AudioEffectReverb.new()
		room.room_size = 0.34
		room.damping = 0.72
		room.wet = 0.10
		room.dry = 0.92
		AudioServer.add_bus_effect(sfx_bus, room)
	if AudioServer.get_bus_index(&"MUSIC") < 0:
		AudioServer.add_bus()
		var music_bus := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus, &"MUSIC")
		var chorus := AudioEffectChorus.new()
		chorus.wet = 0.08
		chorus.dry = 0.96
		AudioServer.add_bus_effect(music_bus, chorus)

func play_music(map_key: String) -> void:
	if not music_enabled:
		return
	var index := posmod(map_key.hash(), MUSIC_PATHS.size())
	var key := "%s:%d" % [map_key, index]
	if _music_key == key and _music_player.playing:
		return
	_music_key = key
	_music_generation += 1
	var generation := _music_generation
	var swap := func() -> void:
		if generation != _music_generation or not music_enabled:
			return
		var stream := load(MUSIC_PATHS[index]).duplicate()
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.mix_rate * stream.get_length())
		_music_player.stream = stream
		_music_player.volume_db = -30.0
		_music_player.play()
		create_tween().tween_property(_music_player, "volume_db", -17.0, 0.7)
	if _music_player.playing:
		var fade := create_tween()
		fade.tween_property(_music_player, "volume_db", -35.0, 0.35)
		fade.tween_callback(swap)
	else:
		swap.call()

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	if not value:
		_music_generation += 1
		_music_player.stop()
	elif not _music_key.is_empty():
		var previous := _music_key.get_slice(":", 0)
		_music_key = ""
		play_music(previous)

func stop_music() -> void:
	_music_generation += 1
	_music_key = ""
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null

func play(sound: StringName, volume_db := -4.0, min_gap := 0.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -100.0)) < min_gap:
		return
	_last_played[sound] = now
	var sfx_players: Array[Node] = []
	for child in get_children():
		if child is AudioStreamPlayer and child != _music_player:
			sfx_players.append(child)
	if sfx_players.size() >= 16:
		sfx_players[0].queue_free()
	var player := AudioStreamPlayer.new()
	player.stream = _streams[sound]
	player.bus = &"SFX"
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func stop_all() -> void:
	stop_music()
	for child in get_children():
		if child is AudioStreamPlayer and child != _music_player:
			child.stop()
			child.queue_free()
