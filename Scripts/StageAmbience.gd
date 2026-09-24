extends Node2D
## Small, non-interactive pixel vignettes that make each painted venue feel
## alive. Every actor follows a venue-approved polyline supplied by the same
## art-direction layer that places the crowd.

const LAYERS = preload("res://Scripts/VenueLayers.gd")
const SPRITES := {
	"roadrunner": preload("res://Assets/Ambience/roadrunner-run-v3.png"),
	"javelina": preload("res://Assets/Ambience/javelina-trot-v3.png"),
	"crab": preload("res://Assets/Ambience/blue-crab-scuttle-v3.png"),
	"bicycle": preload("res://Assets/Ambience/cyclist-pedal-v3.png"),
	"bird": preload("res://Assets/Ambience/pigeon-flap-v3.png"),
	"oriole": preload("res://Assets/Ambience/baltimore-oriole-flap-v1.png"),
	"gull": preload("res://Assets/Ambience/boston-gull-flap-v1.png"),
	"cardinal": preload("res://Assets/Ambience/belair-cardinal-flap-v1.png"),
	"sparrow": preload("res://Assets/Ambience/berlin-sparrow-flap-v1.png"),
	"toucan": preload("res://Assets/Ambience/brasilia-toucan-flap-v1.png"),
	"cockatoo": preload("res://Assets/Ambience/canberra-cockatoo-flap-v1.png"),
	"capybara": preload("res://Assets/Ambience/brasilia-capybara-walk-v1.png"),
	"kangaroo": preload("res://Assets/Ambience/canberra-kangaroo-hop-v1.png"),
	"walker": preload("res://Assets/Ambience/pedestrian-walk-v1.png"),
	"rollerblader": preload("res://Assets/Ambience/rollerblader-glide-v1.png"),
	"dogwalker": preload("res://Assets/Ambience/dogwalker-labrador-v1.png"),
	"dogwalker_dachshund": preload("res://Assets/Ambience/dogwalker-dachshund-v1.png"),
	"dogwalker_kelpie": preload("res://Assets/Ambience/dogwalker-kelpie-v1.png"),
	"grackle": preload("res://Assets/Ambience/houston-grackle-flap-v1.png"),
	"raven": preload("res://Assets/Ambience/humboldt-raven-flap-v1.png"),
	"chickadee": preload("res://Assets/Ambience/maine-chickadee-flap-v1.png"),
	"ibis": preload("res://Assets/Ambience/orlando-ibis-flap-v1.png"),
	"meadowlark": preload("res://Assets/Ambience/topeka-meadowlark-flap-v1.png"),
	"whiteeye": preload("res://Assets/Ambience/tokyo-whiteeye-flap-v1.png"),
	"eagle": preload("res://Assets/Ambience/washington-eagle-flap-v1.png"),
	"train": preload("res://Assets/Ambience/chicago-train-periodic-v3.png"),
}
const SPRITE_SCALE := {"roadrunner":0.45, "javelina":0.48, "crab":0.44,
	"bicycle":0.65, "bird":0.55, "oriole":0.55, "gull":0.55,
	"cardinal":0.55, "sparrow":0.55, "toucan":0.50, "cockatoo":0.52,
	"capybara":0.48, "kangaroo":0.47, "walker":0.60, "rollerblader":0.62,
	"dogwalker":0.56, "dogwalker_dachshund":0.56, "dogwalker_kelpie":0.56,
	"grackle":0.55, "raven":0.54, "chickadee":0.55, "ibis":0.52,
	"meadowlark":0.55, "whiteeye":0.55, "eagle":0.52,
	"train":1.0}
const FRAME_SIZE := {"roadrunner":Vector2(176,96), "javelina":Vector2(152,96),
	"crab":Vector2(128,80), "bicycle":Vector2(144,128), "bird":Vector2(96,80),
	"oriole":Vector2(96,80), "gull":Vector2(96,80), "cardinal":Vector2(96,80),
	"sparrow":Vector2(96,80), "toucan":Vector2(112,88),
	"cockatoo":Vector2(104,88), "capybara":Vector2(152,96),
	"kangaroo":Vector2(176,128), "walker":Vector2(112,128),
	"rollerblader":Vector2(144,128), "dogwalker":Vector2(208,128),
	"dogwalker_dachshund":Vector2(208,128), "dogwalker_kelpie":Vector2(208,128),
	"grackle":Vector2(104,88), "raven":Vector2(104,88),
	"chickadee":Vector2(96,80), "ibis":Vector2(112,88),
	"meadowlark":Vector2(104,88), "whiteeye":Vector2(96,80),
	"eagle":Vector2(120,96)}
const FRAME_RATE := {"roadrunner":9.0, "javelina":6.0, "crab":7.0,
	"bicycle":8.0, "bird":8.0, "oriole":8.0, "gull":7.0,
	"cardinal":9.0, "sparrow":9.0, "toucan":7.0, "cockatoo":7.0,
	"capybara":6.0, "kangaroo":7.0, "walker":7.0, "rollerblader":8.0,
	"dogwalker":6.0, "dogwalker_dachshund":6.0, "dogwalker_kelpie":6.0,
	"grackle":8.0, "raven":7.0, "chickadee":9.0, "ibis":7.0,
	"meadowlark":8.0, "whiteeye":9.0, "eagle":7.0}

var city_id := "wiesbaden"
var actors: Array[Dictionary] = []
var clock := 0.0
var _rng := RandomNumberGenerator.new()

func setup(value: String, layer := "all") -> void:
	city_id = value
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actors.clear()
	# A fresh offset on every visit makes an actor appear anywhere along its
	# approved route without ever leaving that route.
	_rng.seed = int(Time.get_ticks_usec()) ^ city_id.hash()
	for spec in LAYERS.motion(city_id):
		var spec_layer := "foreground" if spec.get("foreground", false) else "background"
		if layer != "all" and layer != spec_layer:
			continue
		_add(spec)
	queue_redraw()

func _path_length(path: Array) -> float:
	var total := 0.0
	for i in path.size() - 1:
		total += Vector2(path[i]).distance_to(Vector2(path[i + 1]))
	return total

func _sample_path(path: Array, distance: float) -> Dictionary:
	var remaining := distance
	for i in path.size() - 1:
		var from := Vector2(path[i])
		var to := Vector2(path[i + 1])
		var segment := from.distance_to(to)
		if remaining <= segment or i == path.size() - 2:
			var amount := clampf(remaining / maxf(segment, 0.001), 0.0, 1.0)
			return {"position": from.lerp(to, amount),
				"facing": 1.0 if to.x >= from.x else -1.0,
				"angle": from.angle_to_point(to)}
		remaining -= segment
	return {"position": Vector2(path.back()), "facing": 1.0}

func _add(spec: Dictionary) -> void:
	var actor := spec.duplicate(true)
	var choices: Array = actor.get("choices", [])
	if not choices.is_empty():
		actor.kind = choices[_rng.randi_range(0, choices.size() - 1)]
	var path: Array = actor.path
	var total := _path_length(path)
	actor["path_length"] = total
	actor["phase"] = _rng.randf_range(0.0, TAU)
	if actor.get("periodic", false):
		actor["travel"] = 0.0
		actor["active"] = false
		actor["render_size"] = float(actor.get("start_size", actor.size))
		actor["delay"] = _rng.randf_range(float(actor.get("initial_wait_min", 2.0)),
			float(actor.get("initial_wait_max", 9.0)))
		actor["position"] = Vector2(path.front())
		actor["facing"] = 1.0
		actor["rotation"] = Vector2(path[0]).angle_to_point(Vector2(path[1]))
		actors.append(actor)
		return
	actor["travel"] = _rng.randf_range(0.0, total * 2.0)
	var mirrored := float(actor.travel) > total
	var route_distance := total * 2.0 - float(actor.travel) if mirrored else float(actor.travel)
	var sample := _sample_path(path, route_distance)
	actor["position"] = sample.position
	actor["facing"] = -float(sample.facing) if mirrored else float(sample.facing)
	actors.append(actor)

func _process(delta: float) -> void:
	clock += delta
	for i in actors.size():
		var actor: Dictionary = actors[i]
		var total := float(actor.path_length)
		if actor.get("periodic", false):
			if not actor.active:
				actor.delay = float(actor.delay) - delta
				if actor.delay <= 0.0:
					actor.active = true
					actor.travel = 0.0
				actors[i] = actor
				continue
			actor.travel = float(actor.travel) + absf(float(actor.speed)) * delta
			if actor.travel >= total:
				actor.active = false
				actor.delay = _rng.randf_range(float(actor.wait_min), float(actor.wait_max))
				actors[i] = actor
				continue
			var periodic_sample := _sample_path(actor.path, float(actor.travel))
			actor.position = periodic_sample.position
			actor.facing = periodic_sample.facing
			actor.rotation = periodic_sample.angle
			var depth_progress := clampf(float(actor.travel) / maxf(total, 0.001), 0.0, 1.0)
			actor.render_size = lerpf(float(actor.get("start_size", actor.size)),
				float(actor.get("end_size", actor.size)), depth_progress)
			actors[i] = actor
			continue
		actor.travel = fposmod(float(actor.travel) + absf(float(actor.speed)) * delta, total * 2.0)
		var mirrored := float(actor.travel) > total
		var route_distance := total * 2.0 - float(actor.travel) if mirrored else float(actor.travel)
		var sample := _sample_path(actor.path, route_distance)
		actor.position = Vector2(sample.position) + Vector2(0,
			sin(clock * 1.7 + float(actor.phase)) * float(actor.bob))
		actor.facing = -float(sample.facing) if mirrored else float(sample.facing)
		actors[i] = actor
	queue_redraw()

func _draw() -> void:
	for actor in actors:
		if actor.get("periodic", false) and not actor.active:
			continue
		var direction := float(actor.facing)
		var angle := float(actor.get("rotation", 0.0)) if actor.get("align_path", false) else 0.0
		var render_size := float(actor.get("render_size", actor.size))
		draw_set_transform(Vector2(actor.position).round(), angle,
			Vector2(render_size * direction, render_size))
		match str(actor.kind):
			"boat": _draw_boat()
			"roadrunner", "javelina", "crab", "bicycle", "bird", "oriole", "gull", "cardinal", "sparrow", "toucan", "cockatoo", "capybara", "kangaroo", "walker", "rollerblader", "dogwalker", "dogwalker_dachshund", "dogwalker_kelpie", "grackle", "raven", "chickadee", "ibis", "meadowlark", "whiteeye", "eagle", "train": _draw_sprite(str(actor.kind), float(actor.phase))
			"kite": _draw_kite()
			"leaves": _draw_leaves(float(actor.phase))
			"petals": _draw_petals(float(actor.phase))
			"fireflies": _draw_fireflies(float(actor.phase))
	draw_set_transform(Vector2.ZERO)

func _draw_sprite(kind: String, phase: float) -> void:
	var texture: Texture2D = SPRITES[kind]
	var factor: float = SPRITE_SCALE[kind]
	var source_size: Vector2 = FRAME_SIZE.get(kind, texture.get_size())
	var size := source_size * factor
	# Ground actors and the train use a foot/wheel-level pivot. This keeps the
	# image seated on its approved route when it rotates or changes scale.
	var top := -size.y if kind in ["roadrunner", "javelina", "crab", "bicycle",
		"capybara", "kangaroo", "walker", "rollerblader", "dogwalker",
		"dogwalker_dachshund", "dogwalker_kelpie", "train"] else -size.y * 0.5
	if FRAME_SIZE.has(kind):
		var frame := posmod(int(floor(clock * float(FRAME_RATE[kind]) + phase)), 4)
		draw_texture_rect_region(texture, Rect2(Vector2(-size.x * 0.5, top), size),
			Rect2(Vector2(source_size.x * frame, 0), source_size))
	else:
		draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, top), size), false)

func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x,y,w,h), color)

func _poly(points: Array, color: Color) -> void:
	draw_polygon(PackedVector2Array(points), PackedColorArray([color]))

func _ground_shadow(width: float, at_y := 15.0) -> void:
	_poly([Vector2(-width,at_y), Vector2(-width+5,at_y-3),
		Vector2(width-5,at_y-3), Vector2(width,at_y),
		Vector2(width-5,at_y+3), Vector2(-width+5,at_y+3)],
		Color(0.02,0.025,0.04,0.26))

func _draw_boat() -> void:
	var ink := Color("17243b")
	# Broken horizontal highlights make the wake read like the painted harbor.
	_rect(-34,17,20,2,Color(0.63,0.86,0.96,0.55))
	_rect(-8,19,29,2,Color(0.39,0.70,0.90,0.48))
	_rect(25,17,12,2,Color(0.63,0.86,0.96,0.42))
	_poly([Vector2(-32,4),Vector2(31,4),Vector2(23,16),Vector2(-23,16)], ink)
	_poly([Vector2(-27,6),Vector2(26,6),Vector2(19,12),Vector2(-20,12)], Color("b94b3f"))
	_rect(-18,7,36,3,Color("f3d38e"))
	_rect(-4,-31,4,36,ink)
	_rect(-3,-29,2,33,Color("d7ad62"))
	_poly([Vector2(1,-27),Vector2(1,1),Vector2(25,1)], ink)
	_poly([Vector2(3,-24),Vector2(3,-2),Vector2(21,-2)], Color("f5efcf"))
	_poly([Vector2(-4,-22),Vector2(-4,1),Vector2(-24,1)], ink)
	_poly([Vector2(-6,-18),Vector2(-6,-2),Vector2(-20,-2)], Color("e79648"))
	draw_line(Vector2(1,-27),Vector2(24,1),Color("d2b67e"),1)
	_rect(-4,-35,10,3,Color("f0c951"))
	_rect(-14,12,4,3,Color("73b9d6"))
	_rect(7,12,4,3,Color("73b9d6"))

func _draw_roadrunner() -> void:
	var ink := Color("241d2d")
	var stride := roundi(sin(clock * 13.0) * 3.0)
	_ground_shadow(24, 16)
	_poly([Vector2(-37,-10),Vector2(-12,-8),Vector2(-14,-3),Vector2(-39,-4)], ink)
	_poly([Vector2(-34,-8),Vector2(-13,-6),Vector2(-18,-4),Vector2(-37,-5)], Color("337cbe"))
	_rect(-30,-7,8,2,Color("76add0"))
	_rect(-20,-6,5,2,Color("223f68"))
	_poly([Vector2(-18,-12),Vector2(4,-14),Vector2(13,-6),Vector2(7,5),Vector2(-13,5),Vector2(-22,-2)], ink)
	_poly([Vector2(-15,-10),Vector2(3,-11),Vector2(9,-5),Vector2(5,2),Vector2(-12,2),Vector2(-18,-2)], Color("3f87bd"))
	_rect(-7,-3,12,5,Color("d8c59d"))
	_rect(-13,-8,6,3,Color("72add0"))
	_rect(-2,-10,5,2,Color("a4c9da"))
	_poly([Vector2(5,-14),Vector2(13,-21),Vector2(22,-16),Vector2(20,-6),Vector2(10,-5)], ink)
	_rect(11,-17,7,8,Color("5d9cc7"))
	_rect(16,-15,2,2,Color("f5efcf"))
	_rect(18,-14,2,2,ink)
	_poly([Vector2(20,-14),Vector2(31,-11),Vector2(20,-8)], Color("ed9b3f"))
	_rect(8,-23,4,7,Color("315d91"))
	_rect(12,-22,3,5,Color("4b80a8"))
	draw_line(Vector2(-7,4),Vector2(-9+stride,14),Color("d8b04d"),3)
	draw_line(Vector2(4,4),Vector2(8-stride,14),Color("d8b04d"),3)
	_rect(-14+stride,13,12,3,ink)
	_rect(4-stride,13,12,3,ink)

func _draw_javelina() -> void:
	var ink := Color("241d2d")
	var stride := roundi(sin(clock * 9.0) * 2.0)
	_ground_shadow(29, 17)
	_poly([Vector2(-28,-8),Vector2(-18,-14),Vector2(12,-13),Vector2(27,-6),Vector2(31,3),Vector2(23,11),Vector2(-19,11),Vector2(-31,4)], ink)
	_poly([Vector2(-25,-6),Vector2(-16,-11),Vector2(11,-10),Vector2(24,-4),Vector2(27,2),Vector2(20,8),Vector2(-18,8),Vector2(-27,3)], Color("715646"))
	# Bristly pale collar and back highlights.
	_poly([Vector2(4,-11),Vector2(11,-14),Vector2(14,-9),Vector2(19,-11),Vector2(18,-5),Vector2(23,-5),Vector2(18,2),Vector2(8,0)], Color("ae9174"))
	_rect(-18,-8,16,3,Color("8d715d"))
	_rect(-20,-3,7,2,Color("94735c"))
	_rect(-9,2,6,2,Color("4f3d39"))
	_rect(2,-7,4,2,Color("d0b08b"))
	_poly([Vector2(21,-7),Vector2(29,-12),Vector2(30,-3)], ink)
	_poly([Vector2(23,-7),Vector2(28,-10),Vector2(28,-4)], Color("a78065"))
	_rect(25,-3,9,7,Color("89634f"))
	_rect(31,-1,4,3,ink)
	_rect(24,-5,2,2,Color("f1dc9d"))
	_rect(26,-5,2,2,ink)
	_poly([Vector2(31,4),Vector2(36,5),Vector2(31,8)], Color("eee1bd"))
	_rect(-20,8,4,8+stride,ink)
	_rect(-7,8,4,8-stride,ink)
	_rect(10,8,4,8+stride,ink)
	_rect(20,8,4,8-stride,ink)

func _draw_train() -> void:
	var ink := Color("111827")
	_rect(-61,-17,122,4,ink)
	_rect(-58,-14,116,29,ink)
	_rect(-55,-11,110,22,Color("d6d5c9"))
	_rect(-55,-9,110,5,Color("2f6fa7"))
	_rect(-55,-4,110,3,Color("e2a13d"))
	for x in range(-48,45,16):
		_rect(x,0,11,7,ink)
		_rect(x+2,1,7,4,Color("f2cf69"))
		_rect(x+2,1,7,1,Color("fff2b0"))
	_rect(-4,-3,3,14,Color("7f8790"))
	_rect(42,-3,3,14,Color("7f8790"))
	_rect(-59,12,118,5,Color("2f394e"))
	for x in [-43,-18,18,43]:
		draw_circle(Vector2(x,17),4,ink)
		draw_circle(Vector2(x,17),2,Color("76818e"))
	_rect(55,-7,4,5,Color("f6d85e"))

func _draw_bicycle() -> void:
	var ink := Color("152033")
	var wheel_turn := clock * 10.0
	_ground_shadow(28, 18)
	for center in [Vector2(-17,8), Vector2(18,8)]:
		draw_circle(center,11,ink)
		draw_circle(center,8,Color("9ba6ad"))
		draw_circle(center,6,Color(0.15,0.19,0.24,0.55))
		for spoke in 4:
			var angle := wheel_turn + spoke * PI / 2.0
			draw_line(center,center+Vector2(cos(angle),sin(angle))*7,Color("d9d5c7"),1)
	var frame := Color("df5a3d")
	draw_line(Vector2(-17,8),Vector2(-4,-5),frame,3)
	draw_line(Vector2(-4,-5),Vector2(8,8),frame,3)
	draw_line(Vector2(8,8),Vector2(-17,8),frame,3)
	draw_line(Vector2(8,8),Vector2(18,8),frame,3)
	draw_line(Vector2(-4,-5),Vector2(13,-5),frame,3)
	draw_line(Vector2(13,-5),Vector2(18,8),frame,3)
	_rect(-9,-9,12,3,ink)
	_rect(11,-10,3,6,ink)
	# A compact River-City-style rider keeps the bicycle from looking like a
	# loose icon sliding across the courtyard.
	_rect(-10,-31,18,17,ink)
	_rect(-8,-29,14,12,Color("b97858"))
	_rect(-10,-34,19,7,Color("315d91"))
	_rect(4,-25,2,2,Color("f4e8c5"))
	_rect(5,-24,2,2,ink)
	_rect(-9,-16,17,13,ink)
	_rect(-7,-14,13,9,Color("337cbe"))
	_rect(-6,-13,11,3,Color("74b3d5"))
	draw_line(Vector2(4,-12),Vector2(13,-5),Color("b97858"),4)
	draw_line(Vector2(-2,-4),Vector2(-7,7),Color("273247"),3)
	draw_line(Vector2(4,-4),Vector2(8,7),Color("273247"),3)

func _draw_kite() -> void:
	var ink := Color("1d2740")
	_poly([Vector2(0,-17),Vector2(15,0),Vector2(0,18),Vector2(-15,0)], ink)
	_poly([Vector2(0,-13),Vector2(11,0),Vector2(0,0)], Color("ed6731"))
	_poly([Vector2(0,-13),Vector2(0,0),Vector2(-11,0)], Color("edc85c"))
	_poly([Vector2(0,0),Vector2(11,0),Vector2(0,14)], Color("337cbe"))
	_poly([Vector2(0,0),Vector2(0,14),Vector2(-11,0)], Color("7853a6"))
	draw_line(Vector2(0,-13),Vector2(0,14),Color("f4e5bd"),1)
	draw_line(Vector2(-11,0),Vector2(11,0),Color("f4e5bd"),1)
	draw_line(Vector2(0,17),Vector2(11,31),Color("e8e2cf"),1)
	draw_line(Vector2(11,31),Vector2(5,40),Color("e8e2cf"),1)
	_poly([Vector2(6,26),Vector2(11,29),Vector2(7,33)], Color("edc85c"))
	_poly([Vector2(4,34),Vector2(8,38),Vector2(3,40)], Color("ed6731"))

func _draw_leaves(phase: float) -> void:
	var ink := Color("533a32")
	for i in 6:
		var at := Vector2(i * 12 - 30, sin(clock * 2.4 + phase + i) * 8 + i * 3)
		var leaf := [at+Vector2(-6,0),at+Vector2(0,-5),at+Vector2(6,1),at+Vector2(0,5)]
		_poly(leaf, ink)
		_poly([at+Vector2(-3,0),at+Vector2(0,-3),at+Vector2(4,1),at+Vector2(0,3)],
			Color("d86d38") if i % 2 == 0 else Color("e9b34c"))
		draw_line(at+Vector2(-2,0),at+Vector2(4,1),Color("f1d27a"),1)

func _draw_petals(phase: float) -> void:
	var ink := Color("7d4569")
	for i in 7:
		var at := Vector2(i * 11 - 33, sin(clock * 2.0 + phase + i * 0.8) * 9 + i * 2)
		_rect(at.x-3,at.y-2,7,5,ink)
		_rect(at.x-1,at.y-1,4,3,Color("f2a7bd") if i % 2 == 0 else Color("ffd0dd"))

func _draw_fireflies(phase: float) -> void:
	for i in 7:
		var at := Vector2(i * 13 - 39, sin(clock * 1.6 + phase + i) * 14 + (i % 3) * 7)
		var pulse := 0.35 + 0.65 * maxf(0.0, sin(clock * 3.0 + phase + i * 1.9))
		draw_circle(at,4,Color(1.0,0.78,0.22,0.12 * pulse))
		_rect(at.x-1,at.y-1,3,3,Color(1.0,0.88,0.38,0.55 + 0.4 * pulse))

func _draw_bird(phase: float) -> void:
	# Side-profile pigeon/seagull silhouette: a head, eye, beak, tail and one
	# articulated wing remain readable at the distant scale used by the maps.
	var ink := Color("17243b")
	var flap := roundi(sin(clock * 7.0 + phase) * 5.0)
	_poly([Vector2(-18,1),Vector2(-10,-5),Vector2(5,-6),Vector2(14,-2),Vector2(13,5),Vector2(0,8),Vector2(-12,6)], ink)
	_poly([Vector2(-14,0),Vector2(-8,-3),Vector2(5,-3),Vector2(10,0),Vector2(8,4),Vector2(-3,5),Vector2(-11,3)], Color("92aebc"))
	# Tail feathers.
	_poly([Vector2(-11,1),Vector2(-25,-4),Vector2(-19,3),Vector2(-26,7),Vector2(-10,6)], ink)
	_poly([Vector2(-12,2),Vector2(-21,-1),Vector2(-17,3),Vector2(-22,5),Vector2(-11,4)], Color("d7e0dc"))
	# Wing changes silhouette as it flaps, rather than reading as an abstract W.
	_poly([Vector2(-5,0),Vector2(-1,-15-flap),Vector2(9,-5),Vector2(5,3)], ink)
	_poly([Vector2(-2,-1),Vector2(0,-11-flap),Vector2(6,-5),Vector2(3,1)], Color("e5e6db"))
	draw_circle(Vector2(10,-5),6,ink)
	draw_circle(Vector2(10,-5),4,Color("a8bec5"))
	_rect(11,-7,2,2,Color("f7efd0"))
	_rect(12,-7,1,1,ink)
	_poly([Vector2(15,-5),Vector2(23,-2),Vector2(15,0)], Color("e4a63f"))
