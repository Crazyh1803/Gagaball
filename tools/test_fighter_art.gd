extends SceneTree
const ART = preload("res://Scripts/FighterArt.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	var frames := 0
	var start := Time.get_ticks_msec()
	# Pairwise wardrobe sweep: every hairstyle/hat pair, all skin tones,
	# hair colours and facial hair, through all 24 animation cells.
	for variant in 48:
		var p := ART.defaults()
		p.merge({"skin": variant % ART.SKINS.size(), "hair_color": variant % 6,
			"hair_style": variant / 4, "hat": variant % 4,
			"beard": (variant / 6) % 4, "jersey": ART.COLORS[variant % ART.COLORS.size()],
			"body_type":variant % 4,"eye_color":variant % 7,"accessory":(variant / 8) % 6,
			"pattern":variant % 4,"pants":"337cbe","shoes":"c93748"}, true)
		p = ART.normalize(p)
		for row in 3:
			for col in 8:
				var frame := ART.frame(p, row, col)
				frames += 1
				var bounds := frame.get_used_rect()
				if bounds.position.x <= 0 or bounds.position.y <= 0 or bounds.end.x >= ART.W or bounds.end.y >= ART.H:
					push_error("Sprite clips frame: variant %d facing %d pose %d bounds %s" % [variant,row,col,bounds])
					failures += 1
	var profile := ART.defaults()
	if ART.frame(profile,0,0).get_data() != ART.frame(profile,0,0).get_data():
		push_error("Material textures are not deterministic")
		failures += 1
	var pose_hashes := {}
	for col in [0,1,3,4,5,6,7]:
		pose_hashes[hash(ART.frame(profile,0,col).get_data())] = true
	if pose_hashes.size() != 7:
		push_error("Action poses must have distinct silhouettes")
		failures += 1
	print("ART CHECKS: %d frames; deterministic texture; 7 distinct poses; failures: %d; elapsed: %d ms" % [frames, failures, Time.get_ticks_msec()-start])
	quit(1 if failures else 0)
