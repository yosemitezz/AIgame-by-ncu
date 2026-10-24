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
	print("Hit reaction: %d passed, %d failed" % [passed, failed])
	game.queue_free()
	quit(1 if failed > 0 else 0)
