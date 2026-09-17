extends RefCounted
## City identities are independent of difficulty. Palettes are original
## unbranded interpretations of regional sports colours, not licensed kits.
const NAMES := ["Kindergarten", "Elementary School", "Middle School", "High School"]
const DESCRIPTIONS := ["Small towns & county seats · Aukamm homecoming", "US state capitals", "Large American cities", "World capitals · six continents"]
const ROUTES := [
	["wiesbaden", "belair", "doylestown", "taos"],
	["topeka", "annapolis", "phoenix", "boston"],
	["houston", "baltimore", "phoenix", "boston", "chicago", "orlando"],
	["washington", "brasilia", "berlin", "nairobi", "tokyo", "canberra"],
]
const ORIGINAL_IDS := ["wiesbaden", "topeka", "houston", "maine", "humboldt", "baltimore", "phoenix", "boston", "chicago", "orlando"]
const EXTRA := {
	"belair": ["Heart of Harford", "Bel Air, MD", "court", "8b5a32", "b6aa93"],
	"doylestown": ["Bucks County Yard", "Doylestown, PA", "blacktop", "765033", "a69b91"],
	"taos": ["Adobe Elementary", "Taos, NM", "sand", "a66a3f", "c2a478"],
	"annapolis": ["Capital Harbor School", "Annapolis, MD", "court", "405a6f", "9b9d98"],
	"washington": ["District International", "Washington, DC, USA", "blacktop", "405a6f", "aba999"],
	"brasilia": ["Cerrado International", "Brasília, Brazil", "court", "577054", "bbab91"],
	"berlin": ["Spree International", "Berlin, Germany", "blacktop", "70413c", "aaa39b"],
	"nairobi": ["Acacia International", "Nairobi, Kenya", "court", "90613d", "bdac8d"],
	"tokyo": ["Sakura International", "Tokyo, Japan", "court", "765033", "a9a9a2"],
	"canberra": ["Capital Territory School", "Canberra, Australia", "blacktop", "70634c", "b4ac94"],
}
## Each entry: regional team inspiration, shirt and trim. No logos.
const PALETTES := {
	"wiesbaden": [["Wehen Wiesbaden", "c93748", "242938"], ["Wiesbaden Phantoms", "254c84", "edc85c"]],
	"topeka": [["Washburn", "254c84", "e8e2cf"], ["Kansas City Chiefs", "c93748", "edc85c"]],
	"houston": [["Astros", "ed6731", "202f50"], ["Rockets", "c93748", "e8e2cf"], ["Texans", "202f50", "c93748"]],
	"maine": [["Maine Black Bears", "70a7cf", "202f50"], ["Portland Sea Dogs", "c93748", "202f50"]],
	"humboldt": [["Humboldt", "276544", "e7b948"], ["Humboldt Crabs", "c93748", "202f50"]],
	"baltimore": [["Orioles", "ed6731", "242938"], ["Ravens", "59358c", "242938"]],
	"phoenix": [["Suns", "7853a6", "ed6731"], ["Diamondbacks", "a82f42", "54c1be"], ["Cardinals", "a82f42", "e8e2cf"]],
	"boston": [["Celtics", "268654", "e8e2cf"], ["Red Sox", "c93748", "202f50"], ["Bruins", "edc85c", "242938"]],
	"chicago": [["Bulls", "c93748", "242938"], ["Cubs", "254c84", "c93748"], ["Bears", "202f50", "ed6731"], ["White Sox", "242938", "c5cbd0"]],
	"orlando": [["Magic", "337cbe", "242938"], ["Orlando City", "7853a6", "edc85c"]],
	"belair": [["Orioles", "ed6731", "242938"], ["Ravens", "59358c", "242938"]],
	"doylestown": [["Phillies", "c93748", "e8e2cf"], ["Eagles", "246b65", "b8bfc4"]],
	"taos": [["New Mexico Lobos", "c93748", "b8bfc4"], ["New Mexico United", "242938", "edc85c"]],
	"annapolis": [["Navy", "202f50", "edc85c"], ["Orioles", "ed6731", "242938"], ["Ravens", "59358c", "242938"]],
	"washington": [["Nationals", "c93748", "e8e2cf"], ["Capitals", "202f50", "c93748"], ["Commanders", "762b36", "edc85c"]],
	"brasilia": [["Brasiliense", "edc85c", "276544"], ["Gama", "276544", "e8e2cf"]],
	"berlin": [["Hertha", "337cbe", "e8e2cf"], ["Union", "c93748", "e8e2cf"], ["Alba", "edc85c", "337cbe"]],
	"nairobi": [["Gor Mahia", "268654", "e8e2cf"], ["AFC Leopards", "337cbe", "e8e2cf"]],
	"tokyo": [["FC Tokyo", "337cbe", "c93748"], ["Yomiuri Giants", "ed6731", "242938"], ["Tokyo Verdy", "276544", "edc85c"]],
	"canberra": [["Raiders", "85be54", "e8e2cf"], ["Brumbies", "202f50", "edc85c"], ["Canberra United", "268654", "e8e2cf"]],
}

static func cities(originals: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in originals.size():
		var city: Dictionary = originals[i].duplicate(true)
		city["city_id"] = ORIGINAL_IDS[i]
		city["venue_index"] = i
		result.append(city)
	for id in EXTRA:
		var data: Array = EXTRA[id]
		result.append({"city_id": id, "name": data[0], "location": data[1],
			"floor": data[2], "surround": "city", "wall_color": data[3], "court_tint": data[4],
			"backdrop": "backdrop_" + id, "pit_center": Vector2(0, 155), "pit_scale": 0.36,
			"cpus": [0,0,0,0,0], "drop_speed": 260.0, "ball_damp": 0.3, "venue_index": -1})
	return result

static func find_city(id: String, originals: Array) -> Dictionary:
	for city in cities(originals):
		if city.city_id == id:
			return city
	return cities(originals)[0]

static func route(league: int, originals: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ROUTES[clampi(league, 0, 3)]:
		var city := find_city(id, originals)
		city["cpus"] = [[0,0,0,0,0], [0,1,1,1,1], [1,1,2,2,2], [2,2,2,2,2]][league].duplicate()
		city["drop_speed"] = [230.0, 290.0, 340.0, 390.0][league]
		city["ai_speed"] = [145.0, 175.0, 205.0, 230.0][league]
		city["double_ball"] = false
		result.append(city)
	return result
