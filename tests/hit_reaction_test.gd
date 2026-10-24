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
	print("Hit reaction: %d passed, %d failed" % [passed, failed])
	game.queue_free()
	quit(1 if failed > 0 else 0)
