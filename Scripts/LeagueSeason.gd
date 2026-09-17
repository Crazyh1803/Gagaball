extends RefCounted
## Six clubs per division; one representative per club plays free-for-all.
## Each city is best-of-three (two round wins clinch). Three different winners:
## round wins, then round podium points, then summed places, then season seed.
## The city's final podium earns 3/2/1 league points; everyone else gets zero.
## Off-screen divisions play simulated fixtures; all exchanges happen together.
const CATALOG = preload("res://Scripts/LeagueCatalog.gd")
const ART = preload("res://Scripts/FighterArt.gd")
const REPS := ["LENA", "BO", "JET", "FINN", "ROWAN", "CAM", "SOL", "QUINN", "DRE", "NOVA", "ARI", "JO", "MAX", "SKYE", "RIO", "KIM", "SAM", "ALEX", "ASH", "REM", "JULES", "LUZ", "DEV", "LEE"]

static func create(league: int, player: Dictionary) -> Dictionary:
	var career := {"version": 2, "season": 1, "round": 0, "complete": false,
		"seed": randi(), "clubs": [], "last_tables": [], "movement": "", "last_places": [],
		"series": empty_series(), "last_series": [], "last_league": league}
	for division in 4:
		for slot in 6:
			var index := division * 6 + slot
			var city: String = CATALOG.ROUTES[division][slot % CATALOG.ROUTES[division].size()]
			var palette: Array = CATALOG.PALETTES[city][slot % CATALOG.PALETTES[city].size()]
			var profile := ART.defaults(REPS[index])
			profile.merge({"home_city": city, "jersey": palette[1], "accent": palette[2],
				"pants": palette[2], "skin": index % ART.SKINS.size(), "hair_style": index % ART.STYLES.size(),
				"body_type": index % ART.BODIES.size(), "pattern": index % ART.PATTERNS.size()}, true)
			var is_player := division == league and slot == 0
			career.clubs.append({"id": "player" if is_player else "club_%d" % index,
				"league": division, "points": 0, "wins": 0, "place_total": 0, "seed": slot,
				"profile": player.duplicate() if is_player else profile})
	return career

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version", 0) not in [1,2] or not value.get("clubs") is Array:
		return false
	if value.clubs.size() != 24:
		return false
	var counts := [0,0,0,0]
	var ids := {}
	for club in value.clubs:
		if not club is Dictionary or not club.get("profile") is Dictionary:
			return false
		var division := int(club.get("league", -1))
		var id := str(club.get("id", ""))
		if division < 0 or division > 3 or id == "" or ids.has(id):
			return false
		counts[division] += 1
		ids[id] = true
	return counts == [6,6,6,6] and ids.has("player") and int(value.get("round", -1)) >= 0

static func player_league(career: Dictionary) -> int:
	for club in career.clubs:
		if club.id == "player":
			return int(club.league)
	return 0

static func table(career: Dictionary, league: int) -> Array:
	var rows: Array = []
	for club in career.clubs:
		if int(club.league) == league:
			rows.append(club)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.points != b.points: return a.points > b.points
		if a.wins != b.wins: return a.wins > b.wins
		if int(a.get("place_total", 0)) != int(b.get("place_total", 0)): return int(a.get("place_total", 0)) < int(b.get("place_total", 0))
		if a.seed != b.seed: return a.seed < b.seed
		return a.id < b.id)
	return rows

static func award(career: Dictionary, order: Array) -> void:
	for place in order.size():
		for club in career.clubs:
			if club.id == order[place]:
				club.points += maxi(0, 3 - place)
				if place == 0: club.wins += 1
				club["place_total"] = int(club.get("place_total", 0)) + place + 1

static func empty_series() -> Dictionary:
	return {"rounds": 0, "wins": {}, "scores": {}, "places": {}}

static func migrate(career: Dictionary) -> Dictionary:
	if career.get("version", 1) == 1:
		career.version = 2
		career.series = empty_series()
		career.last_series = []
		career.last_league = player_league(career)
	if not career.get("series") is Dictionary:
		career.series = empty_series()
	for club in career.clubs:
		if not club.has("place_total"): club.place_total = 0
	return career

static func series_table(career: Dictionary) -> Array:
	var rows := table(career, player_league(career)).duplicate(true)
	var series: Dictionary = career.series
	for row in rows:
		row["round_wins"] = int(series.wins.get(row.id, 0))
		row["round_points"] = int(series.scores.get(row.id, 0))
		row["places"] = int(series.places.get(row.id, 0))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.round_wins != b.round_wins: return a.round_wins > b.round_wins
		if a.round_points != b.round_points: return a.round_points > b.round_points
		if a.places != b.places: return a.places < b.places
		return a.seed < b.seed if a.seed != b.seed else a.id < b.id)
	return rows

static func record(career: Dictionary, order: Array, expected_round: int, expected_game := -1) -> bool:
	if career.complete or int(career.round) != expected_round or order.size() != 6:
		return false
	migrate(career)
	if expected_game >= 0 and int(career.series.rounds) != expected_game: return false
	var division := player_league(career)
	var expected: Array = []
	for club in table(career, division): expected.append(club.id)
	var actual := order.duplicate()
	expected.sort()
	actual.sort()
	if expected != actual: return false
	var series: Dictionary = career.series
	for place in order.size():
		var id: String = order[place]
		series.wins[id] = int(series.wins.get(id, 0)) + (1 if place == 0 else 0)
		series.scores[id] = int(series.scores.get(id, 0)) + maxi(0, 3 - place)
		series.places[id] = int(series.places.get(id, 0)) + place + 1
	series.rounds += 1
	var standings := series_table(career)
	if series.rounds < 3 and standings[0].round_wins < 2: return true
	var city_order: Array = []
	for row in standings: city_order.append(row.id)
	career.last_series = standings.duplicate(true)
	award(career, city_order)
	career.last_places = city_order
	career.series = empty_series()
	career.round += 1
	if career.round >= CATALOG.ROUTES[division].size():
		finish(career)
	return true

static func finish(career: Dictionary) -> void:
	var played_division := player_league(career)
	career.last_league = played_division
	var rng := RandomNumberGenerator.new()
	rng.seed = int(career.seed) + int(career.season) * 7919
	for division in 4:
		if division == played_division: continue
		for fixture in CATALOG.ROUTES[division].size():
			_simulate_city(career, division, rng)
	career.last_tables = []
	var moves := {}
	var player_place := 0
	for division in 4:
		var rows := table(career, division)
		career.last_tables.append(rows.duplicate(true))
		for place in rows.size():
			var destination := division
			if place < 2 and division < 3: destination += 1
			elif place >= 4 and division > 0: destination -= 1
			moves[rows[place].id] = destination
			if rows[place].id == "player": player_place = place + 1
	for club in career.clubs: club.league = moves[club.id]
	var new_division := player_league(career)
	var action := "PROMOTED" if new_division > played_division else ("RELEGATED" if new_division < played_division else "STAYING")
	career.movement = "%s · finished #%d\nNext season: %s" % [action, player_place, CATALOG.NAMES[new_division]]
	career.complete = true

static func _simulate_city(career: Dictionary, division: int, rng: RandomNumberGenerator) -> void:
	var roster: Array = []
	for row in table(career, division): roster.append(row.id)
	var wins := {}
	var scores := {}
	var places := {}
	for game in 3:
		var order := roster.duplicate()
		# Fisher–Yates with a private RNG makes reloads deterministic.
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap: Variant = order[i]
			order[i] = order[j]
			order[j] = swap
		for place in order.size():
			var id: String = order[place]
			wins[id] = int(wins.get(id, 0)) + (1 if place == 0 else 0)
			scores[id] = int(scores.get(id, 0)) + maxi(0, 3 - place)
			places[id] = int(places.get(id, 0)) + place + 1
		var clinched := false
		for value in wins.values(): clinched = clinched or int(value) >= 2
		if clinched: break
	roster.sort_custom(func(a: String, b: String) -> bool:
		if int(wins.get(a,0)) != int(wins.get(b,0)): return int(wins.get(a,0)) > int(wins.get(b,0))
		if int(scores.get(a,0)) != int(scores.get(b,0)): return int(scores.get(a,0)) > int(scores.get(b,0))
		if int(places.get(a,0)) != int(places.get(b,0)): return int(places.get(a,0)) < int(places.get(b,0))
		return a < b)
	award(career, roster)

static func next_season(career: Dictionary) -> void:
	if not career.complete: return
	# Stable merit seed for tied points in the next season, across divisions.
	for division in 4:
		var rows := table(career, division)
		for i in rows.size(): rows[i].seed = i
	for club in career.clubs:
		club.points = 0
		club.wins = 0
		club.place_total = 0
	career.season += 1
	career.round = 0
	career.series = empty_series()
	career.complete = false
