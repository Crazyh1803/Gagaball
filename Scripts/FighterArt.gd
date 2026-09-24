extends RefCounted
## Original 80x96 layered pixel fighters. Shared sunlight/shadow ramps,
## material-specific texture, sculpted silhouettes and all saved cosmetics.
## Existing palette indices stay fixed so older saves keep their appearance.
const SKINS := ["f6d4af", "e9b483", "ca885d", "a86d49", "7b4935", "503326",
	"f8dfca", "edc2a2", "dbab88", "b68e69", "946647", "603c2d"]
const SKIN_NAMES := ["Light Peach", "Peach", "Tan", "Medium Brown", "Dark Brown", "Deep Brown",
	"Ivory", "Light Beige", "Beige", "Olive Tan", "Warm Brown", "Rich Brown"]
const HAIRS := ["252332", "583625", "a25832", "e2b451", "dad5c5", "853c72"]
const COLORS := ["efb83b", "ed6731", "c93748", "337cbe", "429465", "7853a6", "e8e2cf", "242938",
	"e493b2", "359d9e", "243c61", "89929c", "784d38", "f3f1e7", "a9ce78", "813449"]
const COLOR_NAMES := ["Gold", "Orange", "Red", "Blue", "Green", "Purple", "Cream", "Black",
	"Pink", "Teal", "Navy", "Grey", "Brown", "White", "Light Green", "Burgundy"]
const STYLES := ["Crop", "Quiff", "Curls", "Long", "Mohawk", "Bald",
	"Side Part", "Afro", "Braids", "Ponytail", "Spikes", "Buzz Cut"]
const HATS := ["None", "Ball cap", "Beanie", "Headband"]
const BEARDS := ["None", "Moustache", "Goatee", "Full beard"]
const BODIES := ["Classic", "Slim", "Broad", "Stocky"]
const ACCESSORIES := ["None", "Glasses", "Sunglasses", "Wristbands", "Elbow Pads", "Neck Scarf"]
const EYES := ["593c2d", "3675a8", "448653", "a88a42", "82939d", "3a302e", "b18349"]
const EYE_NAMES := ["Brown", "Blue", "Green", "Hazel", "Grey", "Dark Brown", "Amber"]
const PATTERNS := ["Solid", "Two-tone Split", "Contrast Shoulders", "Chest Stripe"]
const COLOR_KEYS := ["jersey", "accent", "pants", "shoes"]
const W := 80
const H := 96

static func defaults(player_name := "ROOKIE") -> Dictionary:
	return {"name": player_name, "skin": 1, "hair_color": 0, "hair_style": 1,
		"hat": 0, "beard": 0, "jersey": "efb83b", "accent": "242938",
		"pants": "242938", "shoes": "242938", "eye_color": 0,
		"body_type": 0, "accessory": 0, "pattern": 0, "home_city": "wiesbaden"}

static func normalize(value: Dictionary) -> Dictionary:
	var p := defaults()
	var city := str(value.get("home_city", "wiesbaden"))
	p.home_city = city if preload("res://Scripts/LeagueCatalog.gd").PALETTES.has(city) else "wiesbaden"
	# Preserve the spelling and casing the player chose. Earlier builds forced
	# every saved name to uppercase, which made the editor feel as if it ignored
	# the text field. LineEdit prevents newlines, but old/imported saves may not.
	var raw_name: String = str(value.get("name", "ROOKIE")).replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	p["name"] = raw_name.substr(0, 24) if not raw_name.is_empty() else "ROOKIE"
	for entry in [["skin", SKINS.size()], ["hair_color", HAIRS.size()],
			["hair_style", STYLES.size()], ["hat", HATS.size()], ["beard", BEARDS.size()],
			["eye_color", EYES.size()], ["body_type", BODIES.size()],
			["accessory", ACCESSORIES.size()], ["pattern", PATTERNS.size()]]:
		p[entry[0]] = clampi(int(value.get(entry[0], p[entry[0]])), 0, entry[1] - 1)
	for key in COLOR_KEYS:
		var fallback: String = str(value.get("accent", p.accent)) if key in ["pants","shoes"] else p[key]
		p[key] = Color.from_string(str(value.get(key, fallback)), Color(p[key])).to_html(false)
	return p

static func sheet(profile: Dictionary) -> ImageTexture:
	var p := normalize(profile)
	var atlas := Image.create(W * 8, H * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		for col in 8:
			atlas.blit_rect(frame(p, row, col), Rect2i(0, 0, W, H), Vector2i(col * W, row * H))
	return ImageTexture.create_from_image(atlas)

static func box(im: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	im.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, W, H)), color)

## Discrete material ramps: warm sunlight, cool reflected courtyard shadows.
static func ramp(base: Color) -> Array[Color]:
	return [base.darkened(0.43).lerp(Color("30354d"), 0.26),
		base.darkened(0.22).lerp(Color("43465d"), 0.13), base,
		base.lightened(0.13).lerp(Color("ffe0a1"), 0.12),
		base.lightened(0.28).lerp(Color("fff0c9"), 0.12)]

static func stroke(im: Image, a: Vector2, b: Vector2, color: Color, width := 1) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for step in steps + 1:
		var point := a.lerp(b, float(step) / steps).round()
		box(im, int(point.x) - width / 2, int(point.y) - width / 2, width, width, color)

## Pixel-aligned scanline polygons. Texture is anchored to each body part so
## walking never causes random flicker. A small palette keeps clusters legible.
static func shape(im: Image, coords: Array, base: Color, material := "skin", offset := Vector2.ZERO,
		secondary := Color.TRANSPARENT, pattern := 0) -> void:
	var points: Array[Vector2] = []
	var bounds := Rect2(Vector2(coords[0][0], coords[0][1]) + offset, Vector2.ZERO)
	for coord in coords:
		var point := Vector2(coord[0], coord[1]) + offset
		points.append(point)
		bounds = bounds.expand(point)
	var shades := ramp(base)
	var second_shades := ramp(secondary)
	for i in points.size():
		stroke(im, points[i], points[(i + 1) % points.size()], shades[0].darkened(0.23), 3)
	for y in range(maxi(0, int(bounds.position.y)), mini(H, int(bounds.end.y) + 1)):
		var intersections: Array[float] = []
		for i in points.size():
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				intersections.append(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y))
		intersections.sort()
		for pair in range(0, intersections.size() - 1, 2):
			for x in range(maxi(0, ceili(intersections[pair])), mini(W, floori(intersections[pair + 1]) + 1)):
				var u := (x - bounds.position.x) / maxf(1, bounds.size.x)
				var v := (y - bounds.position.y) / maxf(1, bounds.size.y)
				var shade := 3 if u < 0.43 and v < 0.65 else 2
				if u > 0.79 or v > 0.87:
					shade = 1
				if u > 0.92 and v > 0.4:
					shade = 0
				var local_x := x - int(offset.x)
				var local_y := y - int(offset.y)
				if material == "cloth" and (local_x + local_y * 3) % 13 < 2 and local_y % 3 == 0:
					shade = mini(4, shade + 1)
				elif material == "hair":
					if (local_x + local_y / 3) % 7 <= 1:
						shade = maxi(0, shade - 1)
					elif local_y % 11 < 2 and u < 0.7:
						shade = mini(4, shade + 1)
				var use_second := (pattern == 1 and u > 0.52) or (pattern == 2 and v < 0.30) or (pattern == 3 and v > 0.4 and v < 0.63)
				im.set_pixel(x, y, second_shades[shade] if use_second else shades[shade])

static func arm(im: Image, shoulder: Vector2, elbow: Vector2, fist: Vector2, skin: Color, jersey: Color) -> void:
	var side := (elbow - shoulder).orthogonal().normalized() * 5
	var wrist := (fist - elbow).orthogonal().normalized() * 4
	var coords: Array = []
	for point in [shoulder + side, elbow + side, fist + wrist, fist - wrist, elbow - side, shoulder - side]:
		coords.append([int(point.x), int(point.y)])
	shape(im, coords, skin)
	stroke(im, shoulder - side, shoulder + side, ramp(jersey)[0], 6)
	stroke(im, shoulder - side + Vector2(0,-1), shoulder + side + Vector2(0,-1), jersey, 3)
	var hand := fist.round()
	shape(im, [[-4,-5],[3,-5],[5,-2],[5,3],[2,5],[-4,3],[-5,-1]], skin, "skin", hand)
	var shades := ramp(skin)
	stroke(im, hand + Vector2(-2,-3), hand + Vector2(2,-3), shades[4])
	stroke(im, hand, hand + Vector2(3,1), shades[1])
	box(im, int(hand.x) - 3, int(hand.y), 2, 3, shades[1])

static func shoe(im: Image, at: Vector2, accent: Color, back: bool) -> void:
	shape(im, [[-7,-4],[3,-5],[7,-2],[10,0],[10,5],[-9,5],[-10,2]], accent, "cloth", at)
	var x := int(at.x)
	var y := int(at.y)
	box(im, x - 9, y + 4, 19, 2, Color("bdbab0"))
	box(im, x - 8, y + 3, 17, 1, Color("f5ebd3"))
	box(im, x - 5, y - 3, 8, 2, ramp(accent)[3])
	if not back:
		for lace in 3:
			box(im, x - 2, y - 3 + lace * 2, 5, 1, Color("f4e7cb"))
	else:
		box(im, x - 3, y - 3, 5, 4, Color("c3c9cb"))
	box(im, x + 6, y, 2, 2, Color("e1d9c5"))

static func frame(p: Dictionary, row: int, col: int) -> Image:
	var im := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var skin := Color(SKINS[p.skin])
	var hair := Color(HAIRS[p.hair_color])
	var jersey := Color(p.jersey)
	var accent := Color(p.accent)
	var pants := Color(p.pants)
	var shoes := Color(p.shoes)
	var s := ramp(skin)
	var j := ramp(jersey)
	var a := ramp(pants)
	var bob := -2 if col in [1,3] else (3 if col == 4 else 0)
	if col == 7:
		bob = 5
	var lean := 3 if col == 5 else (-2 if col == 4 else 0)
	var step := 4 if col == 1 else (-4 if col == 3 else 0)
	var body := Vector2(lean, bob)
	var left_shoulder := Vector2(25,55) + body
	var right_shoulder := Vector2(56,55) + body
	var left_elbow := Vector2(19,64 + step / 2) + body
	var right_elbow := Vector2(62,64 - step / 2) + body
	var left_fist := Vector2(21,72 + step / 2) + body
	var right_fist := Vector2(62,72 - step / 2) + body
	if row == 1:
		left_shoulder.x += 7
		left_elbow.x += 5
		left_fist.x += 7
	if col == 4:
		left_elbow = Vector2(15,64) + body
		left_fist = Vector2(27,64) + body
		right_elbow = Vector2(65,60) + body
		right_fist = Vector2(60,49) + body
	elif col == 5:
		right_elbow = Vector2(67,57) + body
		right_fist = Vector2(68,51) + body
		left_fist = Vector2(19,66) + body
	elif col == 6:
		left_elbow = Vector2(14,40)
		left_fist = Vector2(17,25)
		right_elbow = Vector2(65,40)
		right_fist = Vector2(63,25)
	arm(im, left_shoulder, left_elbow, left_fist, skin.darkened(0.07), accent if p.pattern == 2 else jersey)
	for leg in 2:
		var x := 29 if leg == 0 else 50
		var lift := mini(step,0) if leg == 0 else -maxi(step,0)
		if row == 1 and leg == 0:
			x += 5
		shape(im, [[-5,0],[5,0],[6,7],[4,16],[-5,16],[-6,7]], skin, "skin", Vector2(x,73 + lift))
		box(im, x - 3, 78 + lift, 5, 2, s[4])
		box(im, x - 5, 84 + lift, 9, 5, Color("ddd6bc"))
		box(im, x - 5, 84 + lift, 9, 1, a[2])
		box(im, x + 2, 85 + lift, 2, 4, Color("9b9ea2"))
		shoe(im, Vector2(x,88 + lift), shoes, row == 2)
	shape(im, [[24,68],[56,68],[59,79],[45,80],[41,75],[37,81],[23,79]], pants, "cloth", body)
	stroke(im, Vector2(26,77) + body, Vector2(35,78) + body, a[3], 2)
	stroke(im, Vector2(46,77) + body, Vector2(56,77) + body, a[3], 2)
	stroke(im, Vector2(40,70) + body, Vector2(41,75) + body, a[0], 2)
	shape(im, [[31,48],[48,48],[57,52],[60,59],[54,63],[55,69],[49,73],
		[27,72],[23,67],[25,59],[21,56],[25,51]], jersey, "cloth", body, accent, int(p.pattern))
	# Shirt trim no longer borrows its colour from the shorts.
	a = ramp(accent)
	stroke(im, Vector2(27,52) + body, Vector2(30,63) + body, j[4], 2)
	stroke(im, Vector2(54,57) + body, Vector2(50,68) + body, j[1], 3)
	stroke(im, Vector2(31,65) + body, Vector2(36,68) + body, j[1], 2)
	stroke(im, Vector2(28,70) + body, Vector2(50,70) + body, a[2], 2)
	stroke(im, Vector2(44,65) + body, Vector2(49,64) + body, j[4])
	shape(im, [[34,44],[46,44],[46,51],[41,54],[34,50]], skin, "skin", body)
	stroke(im, Vector2(31,50) + body, Vector2(39,55) + body, a[0], 3)
	stroke(im, Vector2(39,55) + body, Vector2(49,50) + body, a[0], 3)
	stroke(im, Vector2(32,51) + body, Vector2(39,54) + body, a[3])
	if row == 0:
		box(im, 45 + lean, 58 + bob, 5, 5, a[1])
		box(im, 46 + lean, 58 + bob, 3, 3, a[4])
	elif row == 2:
		box(im, 31 + lean, 49 + bob, 19, 5, j[1])
		stroke(im, Vector2(30,56) + body, Vector2(51,56) + body, j[4])
		box(im, 37 + lean, 59 + bob, 3, 7, a[3])
		box(im, 42 + lean, 59 + bob, 3, 7, a[3])
	arm(im, right_shoulder, right_elbow, right_fist, skin, accent if p.pattern in [1,2] else jersey)
	if p.accessory == 3:
		for wrist in [left_elbow.lerp(left_fist,0.62),right_elbow.lerp(right_fist,0.62)]:
			stroke(im,wrist + Vector2(-4,0),wrist + Vector2(4,0),accent,4)
	elif p.accessory == 4:
		for elbow in [left_elbow,right_elbow]:
			shape(im,[[-4,-4],[4,-4],[5,2],[2,5],[-4,3]],Color("344054"),"cloth",elbow)
	elif p.accessory == 5:
		shape(im,[[30,49],[49,49],[46,54],[39,62],[33,54]],accent,"cloth",body)
	_reshape_body(im,int(p.body_type))
	if p.body_type == 3:
		body.y += 5
	_head(im, p, row, col, body, skin, hair, jersey, accent)
	_polish_frame(im)
	return im

## A restrained final light pass gives the small sprites the same warm-key /
## cool-shadow language as the painted stages. It stays pixel-sharp: no blur,
## antialiasing, or sub-pixel edges.
static func _polish_frame(im: Image) -> void:
	var source := im.duplicate() as Image
	var sunlight := Color("ffd990")
	var bounce := Color("36445f")
	var arcade_ink := Color("111827")
	# The promo art's strongest character cue is its heavy navy silhouette.
	# Add a one-pixel external keyline before the lighting pass so customized
	# fighters retain that same legibility against every detailed backdrop.
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if source.get_pixel(x, y).a >= 0.5:
				continue
			var borders_fighter := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if (ox != 0 or oy != 0) and source.get_pixel(x + ox, y + oy).a >= 0.5:
						borders_fighter = true
			if borders_fighter:
				im.set_pixel(x, y, arcade_ink)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var pixel := source.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			var upper_edge := source.get_pixel(x, y - 1).a < 0.5 or source.get_pixel(x - 1, y).a < 0.5
			var lower_edge := source.get_pixel(x, y + 1).a < 0.5 or source.get_pixel(x + 1, y).a < 0.5
			if upper_edge and (x + y) % 3 != 0:
				im.set_pixel(x, y, pixel.lerp(sunlight, 0.13))
			elif lower_edge:
				im.set_pixel(x, y, pixel.lerp(bounce, 0.18))

static func _reshape_body(im: Image, body_type: int) -> void:
	if body_type == 0:
		return
	var source := im.duplicate() as Image
	im.fill(Color.TRANSPARENT)
	var width: float = [1.0,0.82,1.18,1.23][body_type]
	var height := 0.9 if body_type == 3 else 1.0
	for y in H:
		var source_y := roundi(94 + (y - 94) / height)
		if source_y < 0 or source_y >= H:
			continue
		# Keep outstretched fists inside their atlas cell in broad builds.
		var row_width := width
		for edge_x in W:
			if source.get_pixel(edge_x,source_y).a > 0 and absf(edge_x-40) > 0:
				row_width = minf(row_width,36.0 / absf(edge_x-40))
		for x in range(2,W-2):
			var source_x := roundi(40 + (x - 40) / row_width)
			if source_x >= 0 and source_x < W:
				im.set_pixel(x,y,source.get_pixel(source_x,source_y))

static func _head(im: Image, p: Dictionary, row: int, col: int, at: Vector2,
		skin: Color, hair: Color, jersey: Color, accent: Color) -> void:
	var s := ramp(skin)
	var h := ramp(hair)
	shape(im, [[20,29],[25,28],[27,34],[24,39],[20,36]], skin, "skin", at)
	shape(im, [[56,28],[60,30],[60,36],[56,39],[54,34]], skin, "skin", at)
	shape(im, [[27,13],[48,12],[55,17],[57,28],[55,39],[50,46],
		[42,49],[31,46],[25,40],[23,28],[24,19]], skin, "skin", at)
	var x := int(at.x)
	var y := int(at.y)
	stroke(im, Vector2(27,27) + at, Vector2(27,36) + at, s[4], 2)
	stroke(im, Vector2(29,42) + at, Vector2(36,45) + at, s[3], 2)
	stroke(im, Vector2(48,42) + at, Vector2(44,46) + at, s[1], 3)
	box(im, 21 + x, 31 + y, 2, 4, s[1])
	box(im, 57 + x, 31 + y, 2, 4, s[0])
	if row != 2:
		var eyes: Array = [29,45] if row == 0 else [46]
		for eye in eyes:
			stroke(im, Vector2(eye-1,27) + at, Vector2(eye+7,28) + at, h[0], 2)
			box(im, eye + x, 30 + y, 8, 6, s[0])
			box(im, eye + x, 30 + y, 7, 4, Color("fff0d0"))
			box(im, eye + 4 + x, 30 + y, 3, 5, Color(EYES[p.eye_color]))
			box(im, eye + 5 + x, 31 + y, 2, 3, Color("242635"))
			box(im, eye + 4 + x, 30 + y, 1, 1, Color("b6c9d1"))
			box(im, eye + x, 35 + y, 6, 1, s[1])
			if col == 7:
				stroke(im, Vector2(eye,30) + at, Vector2(eye+6,35) + at, h[0], 2)
				stroke(im, Vector2(eye+6,30) + at, Vector2(eye,35) + at, h[0], 2)
			elif col == 6:
				box(im, eye + x, 32 + y, 7, 3, s[2])
		var nose := 40 if row == 0 else 54
		stroke(im, Vector2(nose,32) + at, Vector2(nose-1,37) + at, s[4], 2)
		box(im, nose - 1 + x, 37 + y, 5, 2, s[1])
		box(im, nose + 3 + x, 37 + y, 2, 1, s[0])
		var mouth := 35 if row == 0 else 47
		box(im, mouth + x, 42 + y, 11 if row == 0 else 7, 2, s[0])
		box(im, mouth + 2 + x, 44 + y, 6, 1, s[4])
		if col == 6:
			box(im, mouth + x, 41 + y, 10, 4, s[0])
			box(im, mouth + 1 + x, 41 + y, 8, 2, Color("fff0d0"))
		if row == 1:
			shape(im, [[55,31],[59,35],[58,38],[54,38]], skin, "skin", at)
	if row == 2 and p.hair_style not in [4,5,11]:
		shape(im, [[25,16],[51,15],[56,23],[55,37],[50,43],[31,43],[25,35]], hair, "hair", at)
	# A cap conceals raised hairstyles; long side locks still show beneath it.
	var hairstyle := int(p.hair_style)
	if p.hat in [1,2] and hairstyle in [1,2,4,6,7,10]:
		hairstyle = 0
	match hairstyle:
		0:
			shape(im, [[23,24],[23,17],[27,12],[35,10],[47,11],[54,15],[55,24],
				[51,27],[49,21],[30,20],[27,26]], hair, "hair", at)
		1:
			shape(im, [[23,25],[22,18],[27,13],[29,7],[39,9],[45,5],[51,8],
				[54,14],[56,21],[52,29],[48,20],[40,22],[31,20],[27,25]], hair, "hair", at)
			stroke(im, Vector2(28,16) + at, Vector2(44,12) + at, h[4], 2)
			stroke(im, Vector2(30,18) + at, Vector2(43,15) + at, h[3])
		2:
			shape(im, [[22,25],[20,19],[23,14],[27,13],[28,9],[35,10],[39,7],
				[45,10],[50,9],[55,14],[58,19],[56,26],[51,28],[49,22],[29,22],[26,28]], hair, "hair", at)
			for curl in [Vector2(26,17),Vector2(32,13),Vector2(40,12),Vector2(49,15),Vector2(52,21),Vector2(36,20)]:
				stroke(im, curl + at, curl + at + Vector2(3,-1), h[4], 2)
				box(im, int(curl.x) + x + 3, int(curl.y) + y, 2, 2, h[0])
		3:
			shape(im, [[22,22],[24,15],[29,10],[43,9],[52,12],[56,20],[57,43],
				[61,49],[51,48],[50,29],[48,20],[35,23],[29,21],[27,35],[29,48],
				[20,49],[23,41]], hair, "hair", at)
			stroke(im, Vector2(26,22) + at, Vector2(25,42) + at, h[3], 2)
			stroke(im, Vector2(52,24) + at, Vector2(54,43) + at, h[3])
		4:
			shape(im, [[34,24],[33,14],[35,7],[39,8],[42,5],[45,7],[47,19],[44,24]], hair, "hair", at)
			stroke(im, Vector2(38,18) + at, Vector2(40,8) + at, h[4], 2)
		5:
			stroke(im, Vector2(29,18) + at, Vector2(37,16) + at, s[4], 2)
		6:
			shape(im,[[23,25],[23,16],[28,11],[46,10],[54,16],[55,25],[50,26],[47,18],[34,23],[28,21],[26,28]],hair,"hair",at)
			stroke(im,Vector2(43,12)+at,Vector2(39,21)+at,h[0],2)
			stroke(im,Vector2(27,17)+at,Vector2(38,14)+at,h[4],2)
		7:
			shape(im,[[18,27],[15,22],[18,17],[17,12],[22,10],[24,6],[31,7],[35,4],
				[42,5],[46,4],[51,7],[57,8],[59,13],[63,16],[62,23],[58,30],[53,28],
				[50,22],[29,23],[26,31],[22,29]],hair,"hair",at)
			for curl in [Vector2(24,14),Vector2(31,10),Vector2(40,9),Vector2(49,12),Vector2(57,17),Vector2(22,23)]:
				stroke(im,curl+at,curl+at+Vector2(3,-1),h[3],2)
		8:
			shape(im,[[24,24],[24,16],[29,11],[48,11],[55,18],[55,27],[51,25],[49,21],[29,21]],hair,"hair",at)
			for braid_x in [24,28,51,55]:
				stroke(im,Vector2(braid_x,22)+at,Vector2(braid_x+1,48)+at,h[0],4)
				for braid_y in range(24,48,4):
					stroke(im,Vector2(braid_x-1,braid_y)+at,Vector2(braid_x+1,braid_y+2)+at,h[3],2)
		9:
			shape(im,[[24,24],[24,16],[29,10],[47,10],[55,17],[54,27],[49,22],[29,22]],hair,"hair",at)
			var tail := at + Vector2(-7 if row == 1 else 0,0)
			shape(im,[[53,22],[62,22],[64,28],[61,39],[64,47],[58,50],[55,40],[57,30]],hair,"hair",tail)
			stroke(im,Vector2(55,24)+tail,Vector2(61,24)+tail,accent,3)
		10:
			shape(im,[[23,26],[20,18],[26,18],[26,9],[32,13],[36,5],[41,12],[49,6],
				[49,14],[56,12],[55,21],[53,28],[47,22],[29,22]],hair,"hair",at)
			stroke(im,Vector2(33,18)+at,Vector2(36,11)+at,h[4],2)
		11:
			shape(im,[[24,22],[25,16],[30,12],[46,12],[53,17],[54,23],[50,21],[29,21]],hair,"hair",at)
			if row == 2:
				shape(im,[[26,19],[53,19],[54,32],[50,38],[31,38],[26,32]],hair,"hair",at)
	if row == 1 and p.hair_style not in [4,5]:
		shape(im, [[25,22],[36,21],[38,30],[34,33],[30,40],[26,35]], hair, "hair", at)
	if row != 2:
		var beard_offset := at + Vector2(8,0) if row == 1 else at
		match int(p.beard):
			1:
				shape(im, [[33,40],[39,39],[41,40],[45,39],[49,41],[48,43],[41,42],[34,43]], hair, "hair", beard_offset)
			2:
				shape(im, [[38,44],[45,44],[46,48],[41,50],[37,48]], hair, "hair", beard_offset)
			3:
				if row == 1:
					shape(im, [[32,36],[38,40],[48,41],[56,38],[55,44],[49,49],[41,49],[35,44]], hair, "hair", at)
				else:
					shape(im, [[27,36],[31,40],[37,41],[42,40],[49,40],[53,35],[52,44],
						[47,49],[38,51],[31,47],[28,42]], hair, "hair", at)
				box(im, (46 if row == 1 else 37) + x, 42 + y, 8, 2, s[1])
				box(im, (47 if row == 1 else 38) + x, 43 + y, 6, 1, s[0])
	_hat(im, p, row, at, jersey, accent)
	if row != 2 and p.accessory in [1,2]:
		for lens in ([28,44] if row == 0 else [45]):
			box(im,lens+x,29+y,11,9,Color("262c38"))
			box(im,lens+1+x,30+y,9,6,Color("45596e") if p.accessory == 2 else s[3])
			if p.accessory == 1:
				box(im,lens+3+x,31+y,5,4,Color(EYES[p.eye_color]))
				box(im,lens+5+x,31+y,2,4,Color("242635"))
			stroke(im,Vector2(lens+2,31)+at,Vector2(lens+5,30)+at,Color("c2d8de"),1)
		stroke(im,Vector2(38,32)+at,Vector2(44,32)+at,Color("262c38"),2)

static func _hat(im: Image, p: Dictionary, row: int, at: Vector2, jersey: Color, accent: Color) -> void:
	var a := ramp(accent)
	var j := ramp(jersey)
	var x := int(at.x)
	var y := int(at.y)
	match int(p.hat):
		1:
			shape(im, [[22,24],[24,14],[30,9],[44,8],[52,12],[55,23]], accent, "cloth", at)
			stroke(im, Vector2(38,10) + at, Vector2(37,22) + at, a[3])
			box(im, 35 + x, 8 + y, 5, 2, a[4])
			if row == 2:
				box(im, 33 + x, 19 + y, 13, 6, a[0])
				box(im, 34 + x, 23 + y, 11, 2, j[2])
			else:
				shape(im, [[21,24],[42,22],[55,23],[61 if row == 1 else 57,27],
					[53,29],[36,27],[22,27]], jersey, "cloth", at)
				box(im, 38 + x, 14 + y, 5, 6, j[3])
				box(im, 39 + x, 15 + y, 3, 3, j[4])
		2:
			shape(im, [[22,25],[23,15],[27,10],[35,7],[44,8],[52,12],[55,24]], accent, "cloth", at)
			for rib in range(26,52,4):
				stroke(im, Vector2(rib,15) + at, Vector2(rib-1,23) + at, a[3])
			shape(im, [[22,22],[54,22],[55,27],[22,27]], jersey, "cloth", at)
			box(im, 46 + x, 23 + y, 5, 4, Color("d5d0b4"))
		3:
			shape(im, [[23,23],[54,23],[55,27],[23,28]], accent, "cloth", at)
			stroke(im, Vector2(24,24) + at, Vector2(51,24) + at, a[4])
			shape(im, [[22,26],[25,29],[22,40],[18,43],[20,33]], accent, "cloth", at)
