class_name VenueLayers
extends RefCounted
## Art-direction data layered over the painted venue backgrounds.
##
## CROWD positions are world-space foot anchors. MOTION paths are approved
## world-space polylines. Keeping this information per venue means decorative
## actors never have to guess whether a pixel belongs to pavement, water, sky,
## landscaping, or a building.

const CROWD := {
	"wiesbaden": [
		[Vector2(-435,20),Vector2(-360,10),Vector2(-280,5),Vector2(-415,70),Vector2(-355,110)],
		[Vector2(260,20),Vector2(340,30),Vector2(440,60),Vector2(390,110),Vector2(460,125)]],
	"belair": [
		[Vector2(-520,70),Vector2(-440,105),Vector2(-570,170),Vector2(-470,220),Vector2(-540,280)],
		[Vector2(520,75),Vector2(440,110),Vector2(570,170),Vector2(470,230),Vector2(540,285)]],
	"doylestown": [
		[Vector2(-550,40),Vector2(-455,80),Vector2(-575,150),Vector2(-470,220),Vector2(-540,285)],
		[Vector2(530,40),Vector2(445,85),Vector2(575,150),Vector2(470,225),Vector2(540,290)]],
	"taos": [
		[Vector2(-570,0),Vector2(-480,20),Vector2(-390,40),Vector2(-540,140),Vector2(-430,200)],
		[Vector2(380,10),Vector2(470,30),Vector2(550,70),Vector2(400,160),Vector2(500,220)]],
	"topeka": [
		[Vector2(-570,20),Vector2(-480,0),Vector2(-390,-10),Vector2(-550,110),Vector2(-430,160)],
		[Vector2(290,-20),Vector2(390,0),Vector2(490,50),Vector2(430,140),Vector2(400,200)]],
	"annapolis": [
		[Vector2(-420,18),Vector2(-370,48),Vector2(-410,90),Vector2(-365,134),Vector2(-415,180)],
		[Vector2(420,18),Vector2(370,48),Vector2(410,90),Vector2(365,134),Vector2(415,180)]],
	"phoenix": [
		[Vector2(-455,30),Vector2(-380,15),Vector2(-280,20),Vector2(-420,70),Vector2(-350,95)],
		[Vector2(290,10),Vector2(390,10),Vector2(490,30),Vector2(360,80),Vector2(450,120)]],
	"boston": [
		[Vector2(-300,0),Vector2(-220,15),Vector2(-475,90),Vector2(-410,125),Vector2(-375,155)],
		[Vector2(300,0),Vector2(220,15),Vector2(475,90),Vector2(410,125),Vector2(375,160)]],
	"houston": [
		[Vector2(-520,110),Vector2(-440,90),Vector2(-365,75),Vector2(-450,140),Vector2(-400,180)],
		[Vector2(210,50),Vector2(290,60),Vector2(390,120),Vector2(500,160),Vector2(430,220)]],
	"baltimore": [
		[Vector2(-480,90),Vector2(-405,95),Vector2(-370,55),Vector2(-390,180),Vector2(-310,230)],
		[Vector2(385,125),Vector2(460,140),Vector2(405,190),Vector2(310,230),Vector2(250,250)]],
	"chicago": [
		[Vector2(-375,35),Vector2(-335,68),Vector2(-365,108),Vector2(-340,150),Vector2(-370,190)],
		[Vector2(375,35),Vector2(335,68),Vector2(365,108),Vector2(340,150),Vector2(370,190)]],
	"orlando": [
		# These anchors keep the whole character silhouette on the open side
		# terraces. The wider guide polygons themselves extend over the two lamps,
		# so using their outer edges as foot points makes spectators climb them.
		[Vector2(-485,115),Vector2(-430,105),Vector2(-375,95),Vector2(-450,165),Vector2(-390,160)],
		[Vector2(385,110),Vector2(440,105),Vector2(490,120),Vector2(400,165),Vector2(460,160)]],
	"washington": [
		[Vector2(-560,-10),Vector2(-460,-10),Vector2(-355,-10),Vector2(-540,110),Vector2(-430,200)],
		[Vector2(190,-10),Vector2(310,-10),Vector2(470,0),Vector2(430,140),Vector2(460,210)]],
	"brasilia": [
		[Vector2(-540,55),Vector2(-455,95),Vector2(-575,160),Vector2(-455,225),Vector2(-550,290)],
		[Vector2(540,55),Vector2(450,100),Vector2(575,165),Vector2(455,230),Vector2(550,290)]],
	"berlin": [
		[Vector2(-540,45),Vector2(-455,90),Vector2(-575,155),Vector2(-460,225),Vector2(-550,290)],
		[Vector2(540,50),Vector2(450,95),Vector2(575,160),Vector2(455,230),Vector2(550,295)]],
	"nairobi": [
		[Vector2(-550,-20),Vector2(-460,30),Vector2(-575,100),Vector2(-470,190),Vector2(-550,280)],
		[Vector2(540,-15),Vector2(450,35),Vector2(575,105),Vector2(470,195),Vector2(550,285)]],
	"tokyo": [
		[Vector2(-565,-20),Vector2(-465,-10),Vector2(-360,-10),Vector2(-550,110),Vector2(-440,200)],
		[Vector2(260,0),Vector2(360,0),Vector2(500,-10),Vector2(320,120),Vector2(470,210)]],
	"canberra": [
		[Vector2(-540,45),Vector2(-450,90),Vector2(-575,155),Vector2(-455,225),Vector2(-545,290)],
		[Vector2(535,45),Vector2(445,90),Vector2(570,155),Vector2(450,225),Vector2(545,290)]],
	"maine": [
		[Vector2(-475,55),Vector2(-400,65),Vector2(-500,120),Vector2(-420,150),Vector2(-370,185)],
		[Vector2(220,0),Vector2(310,25),Vector2(420,60),Vector2(490,120),Vector2(400,180)]],
	"humboldt": [
		[Vector2(-500,80),Vector2(-410,85),Vector2(-520,135),Vector2(-430,150),Vector2(-380,100)],
		[Vector2(400,60),Vector2(500,70),Vector2(570,100),Vector2(460,145),Vector2(360,150)]],
}

const MOTION := {
	"wiesbaden": [
		{"kind":"walker","choices":["walker","rollerblader","dogwalker_dachshund","bicycle"],"path":[Vector2(-97,-36),Vector2(152,-18)],"speed":27.0,"size":0.86,"bob":0.5}],
	"belair": [
		{"kind":"bird","choices":["bird","cardinal"],"path":[Vector2(-303,-230),Vector2(496,-225)],"speed":31.0,"size":0.88,"bob":5.0},
		{"kind":"bicycle","choices":["walker","rollerblader","dogwalker","bicycle"],"path":[Vector2(-284,-25),Vector2(244,-30)],"speed":34.0,"size":1.02,"bob":1.0}],
	"doylestown": [
		{"kind":"bird","choices":["bird","cardinal"],"path":[Vector2(-390,-293),Vector2(-115,-293)],"speed":30.0,"size":0.90,"bob":5.0},
		{"kind":"walker","choices":["walker","rollerblader","dogwalker"],"path":[Vector2(-482,-78),Vector2(222,-78)],"speed":28.0,"size":1.0,"bob":0.5}],
	"taos": [
		{"kind":"walker","choices":["walker","rollerblader","dogwalker","javelina"],"path":[Vector2(-376,-90),Vector2(455,-94)],"speed":30.0,"size":0.94,"bob":0.5}],
	"topeka": [
		{"kind":"bird","choices":["bird","meadowlark"],"path":[Vector2(-310,-280),Vector2(78,-280)],"speed":31.0,"size":0.88,"bob":5.0}],
	"annapolis": [
		{"kind":"bird","choices":["bird","oriole"],"path":[Vector2(-235,-256),Vector2(485,-260)],"speed":28.0,"size":0.82,"bob":5.0},
		{"kind":"bicycle","choices":["walker","rollerblader","dogwalker","bicycle"],"path":[Vector2(-292,-67),Vector2(406,-67)],"speed":35.0,"size":1.08,"bob":1.0}],
	"phoenix": [
		{"kind":"roadrunner","choices":["roadrunner","javelina"],"path":[Vector2(-162,-32),Vector2(209,-32)],"speed":38.0,"size":0.94,"bob":1.0}],
	"boston": [
		{"kind":"bird","choices":["bird","gull"],"path":[Vector2(-20,-318),Vector2(234,-318)],"speed":30.0,"size":0.84,"bob":5.0},
		{"kind":"bird","choices":["bird","gull"],"path":[Vector2(234,-310),Vector2(-20,-310)],"speed":24.0,"size":0.62,"bob":4.0}],
	"houston": [
		{"kind":"bird","choices":["bird","grackle"],"path":[Vector2(-48,-269),Vector2(393,-269)],"speed":31.0,"size":0.92,"bob":6.0}],
	"baltimore": [
		{"kind":"crab","choices":["walker","rollerblader","dogwalker","bicycle","crab"],"path":[Vector2(-184,301),Vector2(190,301)],"speed":22.0,"size":0.90,"bob":0.5,"foreground":true}],
	"chicago": [
		# Wheel-level route along the exposed elevated track. The left end is
		# nearest the camera; the train shrinks as it approaches the buildings.
		{"kind":"train","path":[Vector2(-955,-410),Vector2(-700,-360),
			Vector2(-440,-309),Vector2(-180,-258),Vector2(75,-207),
			Vector2(325,-157)],"speed":110.0,
			"size":1.0,"start_size":1.18,"end_size":0.42,
			"bob":0.0,"periodic":true,"align_path":true,
			"initial_wait_min":2.0,"initial_wait_max":9.0,"wait_min":18.0,"wait_max":34.0},
		{"kind":"bird","path":[Vector2(680,-235),Vector2(-680,-215)],"speed":28.0,"size":0.76,"bob":4.0}],
	"orlando": [
		{"kind":"bird","choices":["bird","ibis"],"path":[Vector2(-330,-242),Vector2(210,-246)],"speed":29.0,"size":0.88,"bob":5.0}],
	"washington": [
		{"kind":"bird","choices":["bird","eagle"],"path":[Vector2(282,-256),Vector2(596,-258)],"speed":29.0,"size":0.82,"bob":4.0}],
	"brasilia": [
		{"kind":"bicycle","choices":["walker","rollerblader","dogwalker","bicycle","capybara"],"path":[Vector2(-276,-18),Vector2(280,-23)],"speed":34.0,"size":1.02,"bob":1.0}],
	"berlin": [
		{"kind":"bicycle","choices":["walker","rollerblader","dogwalker_dachshund","bicycle"],"path":[Vector2(-219,-35),Vector2(270,-35)],"speed":35.0,"size":1.10,"bob":1.0}],
	"nairobi": [
		{"kind":"walker","choices":["walker","rollerblader","dogwalker"],"path":[Vector2(-253,-58),Vector2(270,-60)],"speed":28.0,"size":1.0,"bob":0.5}],
	"tokyo": [
		{"kind":"petals","choices":["petals","whiteeye"],"path":[Vector2(-144,-287),Vector2(194,-287)],"speed":24.0,"size":0.78,"bob":6.0}],
	"canberra": [
		{"kind":"bird","choices":["bird","cockatoo"],"path":[Vector2(-72,-315),Vector2(254,-315)],"speed":33.0,"size":0.96,"bob":6.0},
		{"kind":"bicycle","choices":["walker","rollerblader","dogwalker_kelpie","bicycle","kangaroo"],"path":[Vector2(-247,-50),Vector2(316,-58)],"speed":34.0,"size":1.02,"bob":1.0}],
	"maine": [
		{"kind":"bird","choices":["bird","chickadee"],"path":[Vector2(-289,-282),Vector2(261,-288)],"speed":29.0,"size":0.86,"bob":5.0}],
	"humboldt": [
		{"kind":"bird","choices":["bird","raven"],"path":[Vector2(-149,-260),Vector2(337,-262)],"speed":28.0,"size":0.84,"bob":5.0},
		{"kind":"walker","choices":["walker","dogwalker"],"path":[Vector2(-232,299),Vector2(331,289)],"speed":25.0,"size":0.96,"bob":0.5,"foreground":true}],
}

static func crowd(city_id: String) -> Array:
	return CROWD.get(city_id, CROWD["wiesbaden"]).duplicate(true)

static func motion(city_id: String) -> Array:
	return MOTION.get(city_id, MOTION["wiesbaden"]).duplicate(true)
