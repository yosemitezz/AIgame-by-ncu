extends SceneTree
## End to end: the real hero_attack path picks knockback / stun / launch from the combo stage.

var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.music.stop_score()
	game.music.set_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		if enemy != game.boss:
			enemy.set_physics_process(false)
	var Enemy = load("res://actors/enemy.gd")
	var hero: CharacterBody2D = game.player
	hero.global_position = Vector2(0.0, 300.0)
	hero.facing = 1
	var expected: Array[String] = ["knockback", "stun", "launch"]
	for combo: int in [1, 2, 3]:
		var foe: CharacterBody2D = Enemy.new()
		foe.configure(game, "sentry", Vector2(30.0, 300.0))
		foe.set_physics_process(false)
		game.add_child(foe)
		await physics_frame
		hero.attack_serial += 1
		hero.attack_phase = "active"
		hero.combo = combo
		hero.attack_sweep_from = 0.0
		hero.attack_sweep_to = 1.0
		game.hero_attack(hero, 1, 42.0, combo)
		check(foe.reaction == expected[combo - 1], "combo %d gives %s (%s)" % [combo, expected[combo - 1], foe.reaction])
		check(foe.velocity.x > 0.0, "combo %d pushes the enemy away from the hero" % combo)
		foe.queue_free()
	# A heavy hit on the hero throws it further than a light one.
	hero.invuln = 0.0
	hero.receive_hit(1, Vector2(-20.0, 300.0))
	var light: Vector2 = hero.velocity
	hero.invuln = 0.0
	hero.receive_hit(3, Vector2(-20.0, 300.0))
	var heavy: Vector2 = hero.velocity
	check(heavy.x > light.x and heavy.y < light.y, "heavy damage knocks the hero further and higher")
	# The boss is not shoved or stunned by the new reactions.
	var boss_probe: Node = load("res://combat/boss.gd").new()
	check(not boss_probe.has_method("react"), "boss has no stun or launch reaction")
	boss_probe.free()
	# Hit punch: heavy blows stop the actors longer, kick the frame harder and push the camera in.
	var fb: Node = game.impact
	var spent: float = 0.0
	hero.combat_freeze = 0.0
	fb.request(hero, null, false)
	var light_hold: float = hero.combat_freeze
	hero.combat_freeze = 0.0
	fb.request(hero, null, true)
	var heavy_hold: float = hero.combat_freeze
	check(light_hold >= 0.05 and heavy_hold >= 0.11 and heavy_hold > light_hold, "hit stop is longer and heavier hits hold longer (%.3f / %.3f)" % [light_hold, heavy_hold])
	check(fb.sample_zoom(0.0) > 1.0 and fb.sample_zoom(0.0) <= 1.0 + fb.MAX_PUNCH + 0.001, "a blow pushes the camera in, within its cap")
	var zoomed: bool = true
	for _i: int in 90:
		spent = fb.sample_zoom(1.0 / 60.0)
	check(is_equal_approx(spent, 1.0), "the zoom punch settles back to normal")
	fb.reduced_motion = true
	fb.request(hero, null, true)
	check(fb.sample_zoom(1.0 / 60.0) == 1.0, "reduced motion turns the zoom punch off")
	fb.reduced_motion = false
	# Round and square effects both exist: rings default to round, and 4 or 6 sides give angular ones.
	var fx: Node = game.get_node("FxLayer")
	var before: int = fx.shape_count()
	fx._shape("ring", Vector2(100, 100), 0.3, "warm", {"r0": 2.0, "r1": 20.0, "w": 2.0})
	check(int(fx._shapes.back().get("sides", 32)) == 32, "a ring is round by default")
	fx._shape("ring", Vector2(100, 100), 0.3, "warm", {"r0": 2.0, "r1": 20.0, "w": 2.0, "sides": 4})
	check(int(fx._shapes.back()["sides"]) == 4, "a ring can be a square diamond")
	var kinds: Dictionary = {}
	for _i: int in 30:
		fx._shapes.clear()
		game.emit_fx("slash", Vector2(300, 250), Vector2.RIGHT, float(1 + _i % 3))
		for sh: Dictionary in fx._shapes:
			if sh["type"] == "ring":
				kinds["square" if int(sh.get("sides", 32)) <= 6 else "round"] = true
			elif sh["type"] in ["hexagram", "crystal"]:
				kinds["square"] = true
			elif sh["type"] == "arc":
				kinds["round"] = true
	check(kinds.has("round") and kinds.has("square"), "swings mix round and angular shapes (%s)" % str(kinds.keys()))
	kinds.clear()
	for _i: int in 24:
		fx._shapes.clear()
		game.emit_fx("hit", Vector2(300, 250), Vector2.RIGHT, 1.0)
		var has_round: bool = false
		var has_angular: bool = false
		for sh: Dictionary in fx._shapes:
			if sh["type"] == "ring":
				if int(sh.get("sides", 32)) > 6:
					has_round = true
				else:
					has_angular = true
			elif sh["type"] in ["hexagram", "crystal"]:
				has_angular = true
		kinds["both" if has_round and has_angular else "one"] = true
	check(kinds.has("both"), "hits show a round shock together with angular shapes")
	# Attack reach: each combo stage now covers the distance its swing effect actually draws.
	var Hero = load("res://actors/player.gd")
	check(Hero.HIT_REACH.size() == 3 and Hero.HIT_REACH[0] < Hero.HIT_REACH[1] and Hero.HIT_REACH[1] < Hero.HIT_REACH[2], "reach grows with each combo stage %s" % str(Hero.HIT_REACH))
	check(Hero.HIT_REACH[0] >= 60.0 and Hero.HIT_REACH[2] >= 78.0, "reach is wide enough to match the swing effects")
	var probes: Array = [[1, 170.0, true], [1, 210.0, false], [2, 195.0, true], [2, 230.0, false], [3, 220.0, true], [3, 250.0, false]]
	for probe: Array in probes:
		var target: CharacterBody2D = Enemy.new()
		target.configure(game, "sentry", Vector2(float(probe[1]), 300.0))
		target.set_physics_process(false)
		game.add_child(target)
		await physics_frame
		hero.attack_serial += 1
		hero.attack_phase = "active"
		hero.combo = int(probe[0])
		hero.attack_sweep_from = 0.0
		hero.attack_sweep_to = 1.0
		game.hero_attack(hero, 1, Hero.HIT_REACH[int(probe[0]) - 1], int(probe[0]))
		check((target.health < target.max_health) == bool(probe[2]), "combo %d at %d px: %s" % [probe[0], int(probe[1]), "hit" if probe[2] else "out of range"])
		target.queue_free()
	# The light point stays in its visible corridor; a heavy overhead cleave reaches a raised ledge.
	var high: CharacterBody2D = Enemy.new()
	high.configure(game, "sentry", Vector2(40.0, 300.0 - 36.0))
	high.set_physics_process(false)
	game.add_child(high)
	await physics_frame
	hero.attack_serial += 1
	hero.attack_phase = "active"
	hero.combo = 1
	hero.attack_sweep_from = 0.0
	hero.attack_sweep_to = 1.0
	game.hero_attack(hero, 1, Hero.HIT_REACH[0], 1)
	check(high.health == high.max_health, "light thrust misses a foe 36 px above its narrow visible corridor")
	hero._cancel_attack()
	hero.set_weapon("heavy")
	hero.attack_serial += 1
	hero.attack_phase = "active"
	hero.combo = 1
	hero.attack_sweep_from = 0.0
	hero.attack_sweep_to = 1.0
	game.hero_attack(hero, 1, 168.0, 1)
	check(high.health < high.max_health, "heavy overhead cleave still hits a foe on a ledge 36 px higher")
	high.queue_free()
	# Impact sounds: every kind is synthesized, audible, not clipped flat, and heavier hits are bigger and longer.
	var sfx: Node = fb.sounds
	var all_ok: bool = true
	var stats: Dictionary = {}
	for kind: String in sfx.KINDS:
		var stream: AudioStreamWAV = sfx._streams.get(kind)
		if stream == null:
			all_ok = false
			continue
		var peak: int = 0
		var energy: float = 0.0
		var n: int = stream.data.size() / 2
		for i: int in range(0, n, 3):
			var v: int = absi(stream.data.decode_s16(i * 2))
			peak = maxi(peak, v)
			energy += float(v) * float(v)
		stats[kind] = {"peak": peak, "rms": sqrt(energy / float(maxi(1, n / 3))), "length": float(n) / float(stream.mix_rate)}
		all_ok = all_ok and peak > 6000 and peak < 32000 and stream.mix_rate >= 32000
	check(all_ok and stats.size() == 11, "all 11 impact sounds exist, are audible and do not hard clip")
	check(stats["heavy"]["rms"] > stats["light"]["rms"] * 1.2 and stats["heavy"]["length"] > stats["light"]["length"] * 1.5, "heavy hit is louder and longer than a light hit")
	check(stats["break"]["length"] >= 0.45 and stats["stun"]["length"] >= 0.4 and stats["launch"]["length"] >= 0.35, "break, stun and launch sounds have a long tail")
	check(stats["light"]["rms"] > 2500.0, "light hit has real body (rms %.0f)" % stats["light"]["rms"])
	var sounded: Array[String] = []
	for kind: String in ["stun", "launch", "air_jump", "hurt", "swing"]:
		sfx._last_played.erase(kind)
		sfx.play_impact(kind)
		if sfx._last_played.has(kind):
			sounded.append(kind)
	check(sounded.size() == 5, "stun, launch, air jump, hurt and swing sounds all trigger")
	print("Hit reaction: %d passed, %d failed" % [passed, failed])
	game.queue_free()
	quit(1 if failed > 0 else 0)
