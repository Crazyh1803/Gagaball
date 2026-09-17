extends Node2D
## Decorative supporters, deliberately outside the collision/group roster.
const ART = preload("res://Scripts/FighterArt.gd")
var cheer_left := 0.0
var clock := 0.0
var fans: Array[Sprite2D] = []
var frames: Array = []
var base_positions: Array[Vector2] = []

func setup(center: Vector2, player: Dictionary, local: Array, player_home: bool, visitors: Array = []) -> void:
	position = center
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for side in 2:
		var yours := (side == 0) == player_home
		var label := Label.new()
		label.text = ("HOME" if side == 0 else "AWAY") + (" · YOU" if yours else " · FANS")
		label.position = Vector2(-515 if side == 0 else 365, -144)
		label.size = Vector2(150, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_color", Color(player.jersey).lightened(0.45) if yours else Color("ffd777"))
		add_child(label)
		for i in 6:
			var profile := ART.defaults("FAN")
			var palette: Array = local[i % local.size()]
			if side == 1 and player_home and not visitors.is_empty(): palette = visitors[i % visitors.size()]
			var primary := Color(player.jersey) if yours else Color(palette[1])
			var secondary := Color(player.accent) if yours else Color(palette[2])
			profile.merge({"skin": (i * 3 + side) % ART.SKINS.size(), "hair_style": (i * 2 + side) % ART.STYLES.size(),
				"hair_color": i % ART.HAIRS.size(), "body_type": i % ART.BODIES.size(),
				"hat": i % ART.HATS.size(), "pattern": i % ART.PATTERNS.size(),
				"jersey": primary.lightened(0.035 * (i % 3)).to_html(false),
				"accent": secondary.to_html(false), "pants": secondary.darkened(0.1).to_html(false)}, true)
			var sprite := Sprite2D.new()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(0.66, 0.66)
			sprite.offset = Vector2(0, -46)
			sprite.position = Vector2((-475 if side == 0 else 415) + (i % 2) * 62, -45 + (i / 2) * 45)
			sprite.set_meta("supporter_side", "home" if side == 0 else "away")
			sprite.set_meta("player_supporter", yours)
			sprite.set_meta("palette", profile.jersey)
			var poses := [ImageTexture.create_from_image(ART.frame(profile, 0, 0)), ImageTexture.create_from_image(ART.frame(profile, 0, 6))]
			sprite.texture = poses[0]
			add_child(sprite)
			fans.append(sprite)
			frames.append(poses)
			base_positions.append(sprite.position)
	queue_redraw()

func cheer(seconds := 1.0) -> void:
	cheer_left = maxf(cheer_left, seconds)

func _process(delta: float) -> void:
	clock += delta
	cheer_left = maxf(0, cheer_left - delta)
	for i in fans.size():
		var cheering := cheer_left > 0 or sin(clock * 1.2 + i * 1.7) > 0.94
		fans[i].texture = frames[i][1 if cheering else 0]
		fans[i].position = base_positions[i] + Vector2(0, -absf(sin(clock * 9 + i)) * 5 if cheering else 0)

func _draw() -> void:
	for point in base_positions:
		draw_set_transform(point + Vector2(2, 2), 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, 17, Color(0.03, 0.04, 0.06, 0.24))
	draw_set_transform(Vector2.ZERO)
