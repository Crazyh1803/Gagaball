extends Node2D
## Transient, world-anchored comic accent. No gameplay collision or hit-stop.
var kind := "slap"
var direction := Vector2.RIGHT
var power := 0.0
var age := 0.0
var duration := 0.42

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 8
	add_to_group(&"comic_impacts")

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var t := age / duration
	var alpha := 1.0 - smoothstep(0.45, 1.0, t)
	var radius := lerpf(19, 42 + power * 16, t)
	var star := PackedVector2Array()
	for i in 24:
		star.append(Vector2.from_angle(TAU * i / 24.0) * radius * (1.0 if i % 2 == 0 else 0.45))
	draw_colored_polygon(star, Color("ffd777", alpha))
	var border := star.duplicate()
	border.append(star[0])
	draw_polyline(border, Color("4e3042", alpha), 3)
	if kind == "slap":
		# Oversized open palm/fingers, trailing lines and a snappy follow-through.
		var hand := PackedVector2Array([Vector2(-12,15),Vector2(-17,3),Vector2(-24,-6),
			Vector2(-21,-11),Vector2(-12,-5),Vector2(-13,-24),Vector2(-8,-27),
			Vector2(-4,-9),Vector2(-3,-31),Vector2(2,-32),Vector2(5,-9),
			Vector2(8,-27),Vector2(13,-25),Vector2(12,-5),Vector2(17,-18),
			Vector2(22,-15),Vector2(17,7),Vector2(10,18)])
		draw_set_transform(direction * (t * 14), direction.angle() + PI / 2, Vector2.ONE * (1.15 + power * 0.25))
		draw_colored_polygon(hand, Color("fff1d0", alpha))
		hand.append(hand[0])
		draw_polyline(hand, Color("493247", alpha), 3)
		draw_line(Vector2(-8,5),Vector2(7,9),Color("ca9469", alpha),2)
		for i in 3:
			draw_line(Vector2(-14+i*12,24),Vector2(-14+i*12,40+t*15),Color("fff4dc", alpha),3)
		draw_set_transform(Vector2.ZERO)
	var word := ("SMAAACK!" if power > 0.55 else "SLAP!") if kind == "slap" else "WHUMP!"
	var font := ThemeDB.fallback_font
	var font_size := 25 if kind == "slap" else 22
	var width := font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var at := Vector2(-width / 2,-42-t*20)
	draw_string_outline(font,at,word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color("332336",alpha))
	draw_string(font,at,word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("fff1ad",alpha))
