extends Node2D
## Decorative supporters, deliberately outside the collision/group roster.
## Positions are hand-scattered into loose friend groups instead of rows.
## The backgrounds have very different foreground silhouettes, so the crowd
## uses venue-specific standing pockets rather than one layout for every map.
const ART = preload("res://Scripts/FighterArt.gd")
const LAYERS = preload("res://Scripts/VenueLayers.gd")

var cheer_left := 0.0
var boo_left := 0.0
var clock := 0.0
var ambient_shout_left := 5.0
var fans: Array[Sprite2D] = []
var frames: Array = []
var base_positions: Array[Vector2] = []
var phases: Array[float] = []
var _rng := RandomNumberGenerator.new()

func setup(center: Vector2, player: Dictionary, local: Array, player_home: bool, visitors: Array = []) -> void:
	position = center
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = GameState.city_id().hash() + 1988
	ambient_shout_left = _rng.randf_range(1.5, 3.0)
	var side_spots: Array = LAYERS.crowd(GameState.city_id())
	for side in 2:
		var yours := (side == 0) == player_home
		for i in side_spots[side].size():
			var profile := ART.defaults("FAN")
			var palette: Array = local[i % local.size()]
			if side == 1 and player_home and not visitors.is_empty():
				palette = visitors[i % visitors.size()]
			var primary := Color(player.jersey) if yours else Color(palette[1])
			var secondary := Color(player.accent) if yours else Color(palette[2])
			profile.merge({"skin": (i * 3 + side) % ART.SKINS.size(), "hair_style": (i * 2 + side) % ART.STYLES.size(),
				"hair_color": i % ART.HAIRS.size(), "body_type": i % ART.BODIES.size(),
				"hat": i % ART.HATS.size(), "pattern": i % ART.PATTERNS.size(),
				"jersey": primary.lightened(0.035 * (i % 3)).to_html(false),
				"accent": secondary.to_html(false), "pants": secondary.darkened(0.1).to_html(false)}, true)
			var sprite := Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var world_feet: Vector2 = side_spots[side][i]
			# Scale from the same ground-plane depth used for painter sorting. This
			# keeps a rear spectator slightly smaller than somebody nearer the camera,
			# while a tiny variation prevents cloned-looking rows.
			var depth_amount := clampf(inverse_lerp(-100.0, 300.0, world_feet.y), 0.0, 1.0)
			var size_variation := lerpf(0.56, 0.70, depth_amount)
			size_variation += float(posmod(i + side, 3) - 1) * 0.012
			sprite.scale = Vector2(size_variation, size_variation)
			sprite.flip_h = (i + side) % 3 == 0
			sprite.offset = Vector2(0, -46)
			# Small deterministic offsets keep the same venue recognizable while
			# breaking the last traces of a grid or parade formation.
			sprite.position = world_feet - center + Vector2(_rng.randi_range(-6,6), _rng.randi_range(-4,4))
			# Depth-sort every spectator from the position of their feet. A coarse
			# front/back layer lets a later-created rear child cover a nearer child;
			# screen-space Y gives the painter's order the three-quarter view needs.
			sprite.z_index = clampi(roundi(world_feet.y), -300, 300)
			sprite.set_meta("supporter_side", "home" if side == 0 else "away")
			sprite.set_meta("player_supporter", yours)
			sprite.set_meta("palette", profile.jersey)
			var poses := [ImageTexture.create_from_image(ART.frame(profile, 0, 0)), ImageTexture.create_from_image(ART.frame(profile, 0, 6))]
			sprite.texture = poses[0]
			add_child(sprite)
			fans.append(sprite)
			frames.append(poses)
			base_positions.append(sprite.position)
			phases.append(_rng.randf_range(0.0, TAU))
	queue_redraw()

func _play(sound: StringName, volume_db: float, min_gap: float) -> void:
	var audio := get_node_or_null("/root/RetroSfx")
	if audio != null:
		audio.play(sound, volume_db, min_gap)

func cheer(seconds := 1.0, audible := true) -> void:
	cheer_left = maxf(cheer_left, seconds)
	boo_left = 0.0
	if audible:
		_play(&"crowd_cheer", -5.0, 0.85)

func boo(seconds := 1.0) -> void:
	boo_left = maxf(boo_left, seconds)
	cheer_left = 0.0
	_play(&"crowd_boo", -5.0, 0.85)

func random_shout() -> void:
	var choices := [&"crowd_shout_a", &"crowd_shout_b", &"crowd_shout_c"]
	_play(choices[_rng.randi_range(0, choices.size() - 1)], -8.0, 1.4)

func _process(delta: float) -> void:
	clock += delta
	cheer_left = maxf(0, cheer_left - delta)
	boo_left = maxf(0, boo_left - delta)
	ambient_shout_left -= delta
	if ambient_shout_left <= 0.0:
		random_shout()
		ambient_shout_left = _rng.randf_range(4.0, 7.0)
	for i in fans.size():
		var active := cheer_left > 0 or boo_left > 0
		var spontaneous := sin(clock * 0.85 + phases[i]) > 0.985
		var cheering := active or spontaneous
		fans[i].texture = frames[i][1 if cheering else 0]
		var hop := -absf(sin(clock * (8.0 + fmod(i,3)) + phases[i])) * (5.0 if cheer_left > 0 else 2.0) if cheering else 0.0
		var sway := sin(clock * 1.4 + phases[i]) * (1.5 if not cheering else 0.6)
		fans[i].position = base_positions[i] + Vector2(sway, hop)

func _draw() -> void:
	for point in base_positions:
		draw_set_transform(point + Vector2(2, 2), 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, 17, Color(0.03, 0.04, 0.06, 0.24))
	draw_set_transform(Vector2.ZERO)
