extends SceneTree
## Three swords: light, heavy and two-handed great. Data, switching rules, per-weapon feel and sheet routing.

const AttackProfile = preload("res://combat/attack_profile.gd")
const Renderer = preload("res://presentation/actor_renderer.gd")
const Player = preload("res://actors/player.gd")

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
	# ---- data: light retains reach/damage and first two cadences, with a narrow thrust corridor and long drill finisher.
	AttackProfile.set_weapon("light")
	check(AttackProfile.weapon_ids().size() == 3 and AttackProfile.weapon_ids().has("heavy") and AttackProfile.weapon_ids().has("great"), "three swords are defined")
	check(AttackProfile.radii(1) == Vector2(180, 12) and AttackProfile.radii(3) == Vector2(228, 20), "light sword retains forward reach with a narrow thrust corridor")
	check(is_equal_approx(AttackProfile.duration(1, "windup"), 0.065) and is_equal_approx(AttackProfile.total_duration(1), 0.065 + 0.105 + 0.14), "light sword keeps the original timing")
	check(AttackProfile.damage(1) == 1 and AttackProfile.damage(2) == 1 and AttackProfile.damage(3) == 2, "light sword keeps the original damage 1 / 1 / 2")
	var light_total: float = AttackProfile.total_duration(1)
	var light_reach: float = AttackProfile.radii(1).x
	var light_damage: int = AttackProfile.damage(1)
	var light_lunge: float = AttackProfile.lunge_speed(1)
	check(AttackProfile.set_weapon("heavy"), "heavy can be selected")
	check(AttackProfile.total_duration(1) > light_total * 1.3, "heavy swings are clearly slower (%.2f vs %.2f)" % [AttackProfile.total_duration(1), light_total])
	check(AttackProfile.damage(1) > light_damage and AttackProfile.damage(3) >= 3, "heavy hits harder")
	check(AttackProfile.radii(1).x < light_reach, "heavy is short and wide, not long")
	check(float(AttackProfile.profile(1)["blade_span_degrees"]) > 36.0, "heavy swings a broad arc")
	check(AttackProfile.set_weapon("great"), "great can be selected")
	check(AttackProfile.radii(1).x > light_reach * 1.25 and AttackProfile.radii(3).x > 270.0, "greatsword reaches much further (%d)" % int(AttackProfile.radii(1).x))
	check(AttackProfile.total_duration(3) > 0.55, "greatsword finisher is slow (%.2f)" % AttackProfile.total_duration(3))
	check(AttackProfile.damage(3) >= 4, "greatsword finisher is the hardest hit")
	check(AttackProfile.lunge_speed(1) < light_lunge, "heavy steel steps shorter than the light sword")
	var great_polygon: PackedVector2Array = AttackProfile.sweep_polygon(1, 0.25, 1.0)
	check(great_polygon.size() >= 6, "greatsword sweep polygon exists")
	AttackProfile.set_weapon("light")
	check(AttackProfile.radii(1).x == light_reach and AttackProfile.total_duration(1) == light_total, "switching back restores the light numbers exactly")
	check(not AttackProfile.set_weapon("banana") and AttackProfile.weapon == "light", "unknown swords are rejected")
	var combos_ok: bool = true
	for id: String in AttackProfile.weapon_ids():
		for combo: int in [1, 2, 3]:
			var p: Dictionary = AttackProfile.profile(combo, id)
			combos_ok = combos_ok and p.has("angle_keys") and p.has("radii") and p.has("phase_seconds") and int(p.get("damage", 0)) >= 1
	check(combos_ok, "every sword has a complete profile for every combo step")

	# ---- game wiring
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.music.stop_score()
	game.music.set_process(false)
	game.set_story_safe(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var player: CharacterBody2D = game.player
	player.set_physics_process(false)
	check(player.weapon == "light", "the hero starts with the light sword")
	for action: String in ["weapon_next", "weapon_prev", "weapon_light", "weapon_heavy", "weapon_great"]:
		check(InputMap.has_action(action), "input action " + action)
	var keys: Dictionary = {}
	for action: String in ["weapon_next", "weapon_prev", "weapon_light", "weapon_heavy", "weapon_great", "attack", "move_left", "move_right", "jump", "interact", "climb_up", "climb_down", "parry"]:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var code: int = (event as InputEventKey).physical_keycode
				keys[code] = int(keys.get(code, 0)) + (1 if action.begins_with("weapon_") else 0)
	var clash: bool = false
	for event: InputEvent in InputMap.action_get_events("weapon_next") + InputMap.action_get_events("weapon_prev") + InputMap.action_get_events("weapon_light") + InputMap.action_get_events("weapon_heavy") + InputMap.action_get_events("weapon_great"):
		var code2: int = (event as InputEventKey).physical_keycode
		for other: String in ["attack", "move_left", "move_right", "jump", "interact", "climb_up", "climb_down"]:
			for other_event: InputEvent in InputMap.action_get_events(other):
				if other_event is InputEventKey and (other_event as InputEventKey).physical_keycode == code2:
					clash = true
	check(not clash, "sword keys do not collide with movement, attack or interact keys")

	# Switching is refused mid-swing and applied right after.
	var changed: Array[String] = []
	player.weapon_changed.connect(func(id: String) -> void: changed.append(id))
	player.attack_phase = "active"
	player._weapon_request = "heavy"
	player._apply_weapon_request(false)
	check(player.weapon == "light" and player._weapon_request == "heavy", "no sword swap while a swing is in progress")
	player.attack_phase = "none"
	player._apply_weapon_request(false)
	check(player.weapon == "heavy" and AttackProfile.weapon == "heavy" and changed == ["heavy"], "the swap lands as soon as the swing ends")
	check(game.get_tree().get_meta("bellkeep_weapon", "") == "heavy", "the sword is remembered across reloads")
	player.dash_timer = 0.1
	player._weapon_request = "great"
	player._apply_weapon_request(false)
	check(player.weapon == "heavy", "no sword swap in the middle of a dash")
	player.dash_timer = 0.0
	player._apply_weapon_request(true)
	check(player.weapon == "heavy", "no sword swap in a story-safe section")
	player._apply_weapon_request(false)
	check(player.weapon == "great" and changed == ["heavy", "great"], "the swap waits and then applies once")

	# Keys: Q cycles, K goes back, 1 to 3 pick directly.
	Input.action_press("weapon_next")
	player._capture_weapon_input()
	Input.action_release("weapon_next")
	check(player._weapon_request == "light", "Q cycles great to light (%s)" % player._weapon_request)
	player._apply_weapon_request(false)
	await process_frame
	await process_frame
	Input.action_press("weapon_prev")
	player._capture_weapon_input()
	Input.action_release("weapon_prev")
	check(player._weapon_request == "great", "K cycles back (%s)" % player._weapon_request)
	player._apply_weapon_request(false)
	await process_frame
	await process_frame
	Input.action_press("weapon_heavy")
	player._capture_weapon_input()
	Input.action_release("weapon_heavy")
	player._apply_weapon_request(false)
	check(player.weapon == "heavy", "key 2 picks the heavy sword")
	check(not player.set_weapon("heavy") and player.weapon == "heavy", "re-selecting the same sword does nothing")

	# Real swing timing and damage follow the sword in hand.
	player.set_weapon("light")
	player.attack_phase = "none"
	player.combo = 1
	player._combo_grace = 0.0
	player._start_attack()
	var light_swing: float = player.attack_timer
	player._cancel_attack()
	player.set_weapon("great")
	player._start_attack()
	check(player.attack_timer > light_swing * 1.5, "a greatsword swing takes longer (%.2f vs %.2f)" % [player.attack_timer, light_swing])
	check(is_equal_approx(player._phase_duration(), AttackProfile.duration(1, "windup")), "swing phases read the active sword")
	player._cancel_attack()

	# Hit stop and recoil are heavier with heavier steel.
	var stops: Dictionary = {}
	for id: String in ["light", "heavy", "great"]:
		player._cancel_attack() # Isolate equipment fixtures; live mid-swing switching is tested above.
		player.set_weapon(id)
		player.combat_freeze = 0.0
		player.attack_phase = "active"
		player.set_impact_freeze(0.06)
		stops[id] = player.combat_freeze
	check(float(stops["light"]) < float(stops["heavy"]) and float(stops["heavy"]) < float(stops["great"]), "hit stop grows with the sword (%.3f / %.3f / %.3f)" % [stops["light"], stops["heavy"], stops["great"]])
	check(float(stops["great"]) <= 0.12 * 1.6 + 0.0001, "hit stop stays bounded")
	var recoils: Dictionary = {}
	for id: String in ["light", "heavy", "great"]:
		player._cancel_attack() # Isolate equipment fixtures; live mid-swing switching is tested above.
		player.set_weapon(id)
		player.attack_phase = "active"
		player.combo = 2
		player.confirm_attack_hit()
		recoils[id] = player._recoil_speed
	check(float(recoils["light"]) < float(recoils["heavy"]) and float(recoils["heavy"]) < float(recoils["great"]), "recoil grows with the sword")
	check(float(recoils["great"]) <= 200.0, "recoil stays presentation sized (%.0f)" % float(recoils["great"]))
	player.attack_phase = "none"
	player._cancel_attack()

	# Whole-strike check on a real target: the greatsword reaches a dummy the light sword cannot.
	var enemy_script: Script = load("res://actors/enemy.gd")
	var dummy: CharacterBody2D = enemy_script.new()
	dummy.set("kind", "elite")
	game.add_child(dummy)
	dummy.set_physics_process(false)
	player.global_position = Vector2(1000, 280)
	dummy.global_position = Vector2(1000.0 + 230.0, 280.0)
	player.facing = 1
	var reached: Dictionary = {}
	for id: String in ["light", "great"]:
		player._cancel_attack()
		player.set_weapon(id)
		player.combo = 1
		player.attack_phase = "active"
		player.attack_sweep_from = AttackProfile.contact_start()
		player.attack_sweep_to = 1.0
		var hits: Array = []
		for t: Node2D in preload("res://combat/melee_query.gd").collect(player, [dummy], 0.25, 1.0, 0):
			hits.append(t)
		reached[id] = hits.size()
	check(int(reached["light"]) == 0 and int(reached["great"]) == 1, "a target 230 px away is out of the light sword's reach and inside the greatsword's")
	dummy.queue_free()
	player.attack_phase = "none"

	# HUD state and sheet routing.
	game._refresh_hud()
	var hud_box: Array[Dictionary] = []
	game.hud_updated.connect(func(s: Dictionary) -> void: hud_box.append(s))
	player.set_weapon("heavy")
	game._refresh_hud()
	check(not hud_box.is_empty() and str(hud_box.back().get("weapon", "")) == "heavy", "the HUD state carries the sword in hand")
	check(Renderer.weapon_of(player) == "heavy", "renderer reads the sword from the hero")
	check(Renderer.hero_sheet("res://presentation/feel_frames/hero_atlas.png", "light") == "res://presentation/feel_frames/hero_atlas.png", "light uses the base sheet")
	for id: String in ["heavy", "great"]:
		var sheet: String = Renderer.hero_sheet("res://presentation/feel_frames/hero_atlas.png", id)
		check(ResourceLoader.exists(sheet), "%s sheet resolves to a loadable file (%s)" % [id, sheet.get_file()])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/feel_frames/manifest.json"))
	var weapons: Dictionary = manifest["hero"].get("weapons", {})
	if not weapons.is_empty():
		check(weapons.has("light") and weapons.has("heavy") and weapons.has("great"), "manifest lists all three weapon sheets")
		for id: String in ["light", "heavy", "great"]:
			var entry: Dictionary = weapons.get(id, {})
			check(ResourceLoader.exists("res://presentation/feel_frames/" + str(entry.get("atlas", "missing"))), "%s atlas exists" % id)
		var reach_light: float = 0.0
		var reach_great: float = 0.0
		var rear_great: float = 0.0
		var rear_light: float = INF
		for f: int in 8:
			reach_light = maxf(reach_light, absf(Renderer.weapon_tip_local(2, f, false, "light").x))
			reach_great = maxf(reach_great, absf(Renderer.weapon_tip_local(2, f, false, "great").x))
			rear_great = minf(rear_great, Renderer.weapon_tip_local(2, f, false, "great").x)
			rear_light = minf(rear_light, Renderer.weapon_tip_local(2, f, false, "light").x)
		check(reach_great >= 60.0 and rear_great < -40.0 and rear_light > 0.0, "greatsword turns around the body while the light point stays in front (rear %.0f / %.0f, front reach %.0f / %.0f)" % [rear_great, rear_light, reach_great, reach_light])
		for id: String in ["heavy", "great"]:
			var atlas: Texture2D = load("res://presentation/feel_frames/" + str(weapons[id]["atlas"]))
			check(atlas != null and atlas.get_width() == 8 * 144 and atlas.get_height() == load("res://presentation/feel_frames/hero_atlas.png").get_height(), "%s atlas has the same grid as the light atlas" % id)
	else:
		print("NOTE manifest has no weapons table yet; art-dependent checks skipped")

	# Effects: swapping and swinging each sword stay bounded and valid.
	var fx: Node = game.get_node("FxLayer")
	fx.set_process(false)
	for id: String in ["light", "heavy", "great"]:
		player._cancel_attack() # Isolate equipment fixtures; live mid-swing switching is tested above.
		player.set_weapon(id)
		player.attack_phase = "active"
		for combo: int in [1, 2, 3]:
			player.combo = combo
			game.emit_fx("slash", player.global_position + Vector2(20, -18), Vector2.RIGHT, float(combo))
	check(fx.counts()["effects"] <= 64 and fx.counts()["chips"] <= 800, "sword effects stay inside the pool caps")
	player.attack_phase = "none"
	player.set_weapon("light")
	check(AttackProfile.weapon == "light", "the test leaves the light sword equipped")

	game.get_tree().remove_meta("bellkeep_weapon")
	game.queue_free()
	await process_frame
	print("Weapon switch: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
