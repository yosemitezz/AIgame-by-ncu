extends SceneTree
## Hero shadow trail, sprite smear, restrained palette and the light recoil after a landed hit.

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
	game.music.stop_score()
	game.music.set_process(false)
	# stop_score() marks the game story-safe in full-score mode; combat visuals need it off.
	game.set_story_safe(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var fx: Node = game.get_node("FxLayer")
	fx.set_process(false)
	var player: CharacterBody2D = game.player
	var smear: Node = fx._smear
	check(smear != null and smear.get_child_count() == smear.COPIES, "hero smear holds %d pooled copies" % smear.COPIES)

	# Palette: no hue cycling, the two house ramps stay warm or cold.
	var hues: Array[float] = []
	for i: int in 12:
		fx._clock = float(i) * 0.37
		var c: Color = fx._col("rainbow", 0.55, 1.0, float(i) * 0.08)
		hues.append(c.h)
	var warm_ok: bool = true
	for h: float in hues:
		warm_ok = warm_ok and (h < 0.14 or h > 0.9)
	check(warm_ok, "the 'rainbow' ramp is now furnace ember (hues stay between red and amber)")
	var cold_ok: bool = true
	for i: int in 12:
		fx._clock = float(i) * 0.37
		var c2: Color = fx._col("flow", 0.5, 1.0, float(i) * 0.08)
		cold_ok = cold_ok and c2.h > 0.5 and c2.h < 0.72
	check(cold_ok, "the 'flow' ramp is icy blade light (hues stay between cyan and indigo)")

	# Dash leaves black shadow ghosts, not coloured ones.
	player.set("dash_timer", 1.0)
	for i: int in 30:
		player.global_position = Vector2(200.0 + float(i) * 12.0, 280.0)
		player.set("velocity", Vector2(420.0, 0.0))
		fx._clock += 0.05
		fx._follow_actors(0.05)
	check(fx.ghost_count() >= 3 and fx.ghost_count() <= 28, "a dash leaves a line of shadows (%d)" % fx.ghost_count())
	var shadow_only: bool = true
	for g: Node in fx._ghosts:
		shadow_only = shadow_only and g.kind != "hero" or g.material == fx._shadow_material
	check(shadow_only, "hero afterimages use the black shadow material")
	var owned: int = 0
	for g: Node in fx._ghosts:
		if g.source_id == player.get_instance_id():
			owned += 1
	check(owned <= fx.MAX_OWNER_GHOSTS, "shadows per owner stay capped (%d)" % owned)
	var dark: bool = true
	for g: Node in fx._ghosts:
		dark = dark and g.tint == Color.WHITE
	check(dark, "shadow ghosts are not tinted")
	var shader_text: String = FileAccess.get_file_as_string("res://presentation/ghost_shadow.gdshader")
	check(shader_text.contains("shadow_color") and shader_text.contains("0.012, 0.0, 0.03"), "the shadow shader is near-black")

	# Smear: scales with speed, is hidden at rest, pooled, and obeys F2 and F3.
	player.set("dash_timer", 0.0)
	player.set("velocity", Vector2.ZERO)
	smear.follow(player, 0.016, 1)
	check(smear.visible_copies() == 0, "no smear while standing")
	player.set("velocity", Vector2(420.0, 0.0))
	smear.follow(player, 0.016, 1)
	var normal_count: int = smear.visible_copies()
	var normal_strength: float = smear.strength
	check(normal_count == smear.COPIES and normal_strength > 0.9, "full speed shows every smear copy (%d)" % normal_count)
	player.set("velocity", Vector2(300.0, 0.0))
	smear.follow(player, 0.016, 1)
	check(smear.strength > 0.3 and smear.strength < normal_strength, "a slower run smears less (%.2f)" % smear.strength)
	player.set("velocity", Vector2(420.0, 0.0))
	smear.follow(player, 0.016, 2)
	check(smear.strength >= normal_strength, "F3 strong mode smears at least as much")
	smear.follow(player, 0.016, 0)
	check(smear.visible_copies() == 0 and smear.strength == 0.0, "speed effects off hides the smear")
	smear.follow(player, 0.016, 1)
	var behind: bool = true
	for copy: Node in smear.get_children():
		behind = behind and copy.position.x < player.global_position.x
	check(behind, "smear copies trail behind the direction of travel")
	var alphas: Array[float] = []
	for copy: Node in smear.get_children():
		alphas.append(copy.modulate.a)
	var fading: bool = true
	for i: int in range(1, alphas.size()):
		fading = fading and alphas[i] < alphas[i - 1]
	check(fading and alphas[0] <= 0.41, "smear copies fade away from the hero")
	player.set("velocity", Vector2.ZERO)
	smear.follow(player, 0.5, 1)
	smear.pulse(Vector2.RIGHT, 1.0)
	smear.follow(player, 0.016, 1)
	check(smear.visible_copies() > 0, "a landed hit pulses the smear even when standing still")
	for i: int in 20:
		smear.follow(player, 0.016, 1)
	check(smear.visible_copies() == 0, "the hit pulse fades out")

	# Hit effects spawn, stay bounded and carry no rainbow ramp.
	var before_shapes: int = fx.counts()["effects"]
	for i: int in 30:
		fx.spawn("hit", Vector2(300, 250), Vector2.RIGHT, 1.0 + float(i % 3) * 0.5)
	check(fx.counts()["effects"] > before_shapes and fx.counts()["effects"] <= 64, "hit effects are bounded")
	check(fx.counts()["chips"] <= 800, "hit sparks are bounded")

	# Recoil: a confirmed hit pushes the hero back lightly, never forward, and it ends quickly.
	player.set_physics_process(true)
	player.global_position = Vector2(300.0, 290.0)
	player.velocity = Vector2.ZERO
	player.facing = 1
	player.combo = 2
	player.attack_phase = "active"
	player._recoil_time = 0.0
	player.confirm_attack_hit()
	player.combat_freeze = 0.0
	check(player._recoil_time > 0.0 and player._recoil_speed >= 80.0 and player._recoil_speed <= 160.0, "a landed hit arms a light recoil (%.0f px/s)" % player._recoil_speed)
	check(player._lunge_timer == 0.0, "the forward lunge stops on contact")
	var speeds: Array[float] = []
	for i: int in 24:
		player._physics_process(1.0 / 60.0)
		speeds.append(player.velocity.x)
	var pushed_back: bool = speeds[0] < 0.0
	var peak_speed: float = 0.0
	for s: float in speeds:
		peak_speed = maxf(peak_speed, absf(s))
		pushed_back = pushed_back and s <= 0.01
	# After the hit stop the push eases out linearly: from the last peak, speed never rises again.
	var slows: bool = true
	var last_peak: int = 0
	for i: int in speeds.size():
		if absf(speeds[i]) >= peak_speed - 0.01:
			last_peak = i
	for i: int in range(last_peak + 1, speeds.size()):
		slows = slows and absf(speeds[i]) <= absf(speeds[i - 1]) + 0.01
	check(pushed_back and slows and peak_speed <= 160.0 and absf(speeds[speeds.size() - 1]) < 1.0, "recoil pushes backward, peaks at %.0f and eases out to rest" % peak_speed)
	check(player._recoil_time == 0.0, "recoil ends after hit stop plus about six frames")
	var travel: float = player.global_position.x - 300.0
	check(travel < 0.0 and travel > -14.0, "the recoil moves the hero back only a few pixels (%.1f)" % travel)
	# Recoil is cancelled by a dash.
	player.global_position = Vector2(300.0, 290.0)
	player.attack_phase = "active"
	player.combo = 3
	player.confirm_attack_hit()
	player._cancel_attack()
	check(player._recoil_time == 0.0, "cancelling the attack drops any pending recoil")
	# Whiffs never push the hero.
	player.attack_phase = "active"
	player.combo = 1
	player._recoil_time = 0.0
	for i: int in 4:
		player._physics_process(1.0 / 60.0)
	check(player._recoil_time == 0.0, "a swing that hits nothing has no recoil")

	# Speed lines are stronger and still bounded.
	var blur: Node = game.get_node("MotionBlur")
	blur.enabled_by_user = true
	game.speed_effects_level = 2
	player.global_position = Vector2(500.0, 290.0)
	player.set("dash_timer", 0.12)
	for i: int in 40:
		player.global_position.x += 8.0
		blur._process(0.02)
	check(blur.is_active() and blur._marks.size() <= blur.MAX_MARKS and blur._marks.size() >= 20, "strong speed mode paints a dense, bounded field of lines (%d)" % blur._marks.size())
	player.set("dash_timer", 0.0)
	game.speed_effects_level = 1

	game.queue_free()
	await process_frame
	print("Hero shadow: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
