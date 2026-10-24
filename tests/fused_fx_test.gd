extends SceneTree
## Bounded real-scene presentation contracts. No automated playthrough.
const AttackProfile = preload("res://combat/attack_profile.gd")
const Boss = preload("res://combat/boss.gd")
var passed: int = 0
var failed: int = 0
var game: Node
var fx: Node

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	call_deferred("run")

func wipe() -> void:
	fx.clear_hostile()
	# Celebrations intentionally survive story safety; explicit test fixture reset removes them.
	fx._parts.clear()
	fx._shapes.clear()

func active(progress: float = 0.0) -> void:
	game.player.attack_serial += 1
	game.player.combo = 2
	game.player.attack_phase = "active"
	game.player.attack_timer = 0.2
	game.player._phase_elapsed = game.player._phase_duration() * progress
	game.player.animation_state = "attack"
	game.player.attack_sweep_from = maxf(AttackProfile.contact_start(), progress - 0.05)
	game.player.attack_sweep_to = maxf(AttackProfile.contact_start(), progress)

func bound_shape() -> Dictionary:
	for shape: Dictionary in fx._shapes:
		if bool(shape.get("phase_bound", false)):
			return shape
	return {}

func sweep_sample(steps: int) -> int:
	wipe()
	active()
	fx._spawn_event = "slash"
	fx._shape("arc", game.player.global_position + Vector2(22, -18), 0.4, "flow",
		{"d": 1.0, "r": 40.0, "w": 5.0, "flip": false, "half": 1.5, "sweep": true})
	fx._spawn_event = ""
	var shape: Dictionary = fx._shapes[0]
	for i: int in range(steps + 1):
		game.player._phase_elapsed = game.player._phase_duration() * float(i) / float(steps)
		fx._sync_slash(shape)
	return fx.particle_count()

func profile_sample(steps: int) -> int:
	wipe()
	active(AttackProfile.contact_start())
	game.vfx_requested.emit("slash", game.player.position, Vector2.RIGHT, 2.0)
	var primary: Dictionary = bound_shape()
	for index: int in range(steps + 1):
		var progress: float = lerpf(AttackProfile.contact_start(), 1.0, float(index) / steps)
		game.player._phase_elapsed = game.player._phase_duration() * progress
		game.player.attack_sweep_from = maxf(AttackProfile.contact_start(), progress - 0.01)
		game.player.attack_sweep_to = progress
		fx._sync_slash(primary)
	return fx.particle_count()

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.music.stop_score()
	game.music.set_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	fx = game.get_node_or_null("FxLayer")
	check(fx != null, "the real scene contains the single FxLayer")
	if fx == null:
		quit(1)
		return
	fx.set_process(false)
	check(game.get_node_or_null("CombatVFX") == null, "legacy combat VFX is not instantiated")
	var health: int = game.player.health
	var position_before: Vector2 = game.player.position
	var score: int = game.score
	var time_scale_before: float = Engine.time_scale
	game.set_story_safe(false)
	wipe()
	fx.setup(game)
	fx.setup(game)
	var fx_connections: int = 0
	for connection: Dictionary in game.vfx_requested.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == fx:
			fx_connections += 1
	check(fx_connections == 1, "repeated setup keeps exactly one FX signal subscription")
	game.vfx_requested.emit("dash_start", Vector2(300, 250), Vector2.RIGHT, 1.0)
	check(fx.shape_count() == 1 and fx.particle_count() == 6, "one signal produces one source dash-start bundle")
	check(fx.counts().keys().size() == 5, "counts exposes effects/chips/ghosts/warnings/trails")
	# Full-size source clash, smaller reflection and larger break; root owns true contact dedup.
	wipe()
	game.vfx_requested.emit("projectile_parry", Vector2(320, 250), Vector2.RIGHT, 1.0)
	var reflection_radius: float = fx._shapes[0]["r"]
	var reflection_count: int = fx.shape_count()
	wipe()
	game.vfx_requested.emit("blade_parry", Vector2(320, 250), Vector2.RIGHT, 1.0)
	var blade_radius: float = fx._shapes[0]["r"]
	check(blade_radius > reflection_radius, "blade clash stays larger than projectile reflection")
	check(fx.shape_count() >= 8 and fx.particle_count() >= 60, "preferred cross/fans/rings full clash remains")
	var blade_count: int = fx.shape_count()
	game.vfx_requested.emit("blade_parry", Vector2(320, 250), Vector2.RIGHT, 1.0)
	check(fx.shape_count() == blade_count * 2, "separate accepted same-frame contacts are not fuzzily suppressed")
	wipe()
	game.vfx_requested.emit("guard_break", Vector2(320, 250), Vector2.RIGHT, 1.0)
	check(float(fx._shapes[0]["r"]) > blade_radius and fx.shape_count() > reflection_count, "guard break retains its distinct larger expanding layers")
	wipe()
	game.vfx_requested.emit("blade_parry", Vector2(320, 250), Vector2.RIGHT, 1.0)
	check(float(fx._shapes[0]["r"]) <= 18.0 and float(fx._shapes[0]["max"]) <= 0.033, "parry white core keeps native eighteen-pixel cap and one-to-two-frame life")
	fx._process(0.05)
	var white_flashes: int = 0
	for shape: Dictionary in fx._shapes:
		if String(shape["type"]) == "flash":
			white_flashes += 1
	check(white_flashes == 0 and fx.shape_count() > 0 and fx.particle_count() > 0, "whiteflash_ages_out_by_0.05 while colored rings and directional sparks remain")
	# Actual phase authority: hold, progress, natural release and cancellation.
	wipe()
	active(0.3)
	game.vfx_requested.emit("slash", game.player.position + Vector2(22, -18), Vector2.RIGHT, 2.0)
	var primary: Dictionary = bound_shape()
	check(not primary.is_empty(), "preferred slash shape binds to real active serial")
	fx._process(0.001)
	check(String(primary["type"]) == "profile", "real active slash uses shared melee geometry instead of legacy circles")
	check(primary.get("polygon", PackedVector2Array()) == AttackProfile.world_polygon(game.player, game.player.attack_sweep_from, game.player.attack_sweep_to), "bright contour polygon equals the actual accepted query polygon")
	var frozen_polygon: PackedVector2Array = primary.get("polygon", PackedVector2Array()).duplicate()
	var pose: float = primary.get("visual_t", -1.0)
	var spark_step: int = primary.get("spark_step", 0)
	# Real root overlay pause must preserve an already-active slash and a Boss windup warning.
	var pause_boss := Boss.new()
	game.add_child(pause_boss)
	pause_boss.configure(game, Vector2(900, 300))
	pause_boss.set_physics_process(false)
	game.boss = pause_boss
	pause_boss._begin_attack("slash", {"windup_beats": 0.8})
	var warning_before: Dictionary = fx._warns.back()
	var warning_life_before: float = warning_before["life"]
	var paused_serial: int = game.player.attack_serial
	var sound_state: Dictionary = game.impact.sounds._last_played.duplicate(true)
	var impacts_before: int = game.impact.impact_count
	game._set_overlay("map")
	await process_frame
	fx._process(0.1)
	check(not bound_shape().is_empty() and int(bound_shape()["serial"]) == paused_serial, "map pause preserves the live slash serial")
	check(fx._warns.has(warning_before) and float(warning_before["life"]) == warning_life_before, "map pause preserves the frozen Boss windup warning")
	check(primary.get("polygon", PackedVector2Array()) == frozen_polygon and is_equal_approx(float(primary["visual_t"]), pose), "map pause cannot advance primary pose or geometry")
	game._set_overlay("")
	await process_frame
	fx._process(0.0)
	check(not bound_shape().is_empty() and int(bound_shape()["serial"]) == paused_serial and fx._warns.has(warning_before), "overlay resume retains the same live primary and warning")
	check(primary.get("polygon", PackedVector2Array()) == frozen_polygon and is_equal_approx(float(primary["visual_t"]), pose), "overlay resume does not jump phase progress")
	check(game.impact.sounds._last_played == sound_state and game.impact.impact_count == impacts_before, "overlay resume never reissues swing or impact sound")
	game.boss = null
	pause_boss.queue_free()
	game.player.combat_freeze = 0.1
	for _i: int in 8:
		fx._process(0.016)
	check(primary.get("polygon", PackedVector2Array()) == frozen_polygon, "local freeze holds the exact shared contour geometry")
	check(is_equal_approx(float(primary["visual_t"]), pose), "local impact hold freezes primary slash pose")
	check(int(primary.get("spark_step", 0)) == spark_step, "held slash does not emit frame-rate-driven tip sparks")
	game.player.combat_freeze = 0.0
	game.player._phase_elapsed = game.player._phase_duration() * 0.7
	game.player.attack_sweep_from = 0.65
	game.player.attack_sweep_to = 0.7
	fx._process(0.001)
	check(float(primary["visual_t"]) > pose, "slash advances when actual combat progress advances")
	game.player._cancel_attack()
	fx._process(0.001)
	check(bound_shape().is_empty(), "cancel immediately removes every phase-bound primary stroke")
	wipe()
	active(0.8)
	game.vfx_requested.emit("slash", game.player.position + Vector2(22, -18), Vector2.RIGHT, 2.0)
	fx._process(0.001)
	primary = bound_shape()
	game.player._enter_attack_phase("recover")
	fx._process(0.001)
	check(primary.has("tail_age") and not primary.has("actor_ref"), "natural recovery detaches a short layered afterglow")
	var tail_at: Vector2 = primary["at"]
	active(0.0)
	game.player.position.x += 8.0
	fx._process(0.05)
	check(Vector2(primary["at"]) == tail_at, "old afterglow stays at the previous slash when next serial moves")
	fx._process(0.2)
	check(fx.shape_count() == 0, "natural afterglow expires within its short bounded tail")
	game.player.position = position_before
	game.player._cancel_attack()
	# Non-crescent personalities must share the same active origin and release without a jump.
	wipe()
	active(0.4)
	var origin: Vector2 = game.player.position + Vector2(22, -18)
	fx._spawn_event = "slash"
	fx._shape("streaks", origin, 0.34, "rainbow", {"d": 1.0, "len": 70.0, "n": 4})
	fx._shape("ring", origin, 0.4, "flow", {"r0": 8.0, "r1": 50.0, "w": 4.0})
	fx._spawn_event = ""
	game.player.position.x += 12.0
	fx._process(0.001)
	check(Vector2(fx._shapes[0]["at"]) == origin + Vector2(12, 0) and Vector2(fx._shapes[1]["at"]) == origin + Vector2(12, 0), "thrust streaks and spin rings follow active movement consistently")
	var release_at: Vector2 = fx._shapes[0]["at"]
	game.player._enter_attack_phase("recover")
	fx._process(0.001)
	check(Vector2(fx._shapes[0]["at"]) == release_at, "non-arc recovery releases without jumping to a new origin")
	game.player.position.x += 18.0
	fx._process(0.001)
	check(Vector2(fx._shapes[0]["at"]) == release_at, "released non-arc tail stays fixed as the actor moves")
	game.player.position = position_before
	game.player._cancel_attack()
	# Enemy source anchoring and deterministic leading-edge sampling.
	wipe()
	var enemy_at := Vector2(700, 260)
	fx.spawn("enemy_slash", enemy_at, Vector2.LEFT, 1.0)
	var enemy_arc: Dictionary = fx._shapes[0]
	game.player.position.x += 160.0
	check(fx._arc_at(enemy_arc) == enemy_at and not enemy_arc.has("actor_ref"), "enemy slash never rides along with the hero")
	game.player.position = position_before
	var thirty: int = sweep_sample(30)
	var sixty: int = sweep_sample(60)
	check(thirty == sixty and thirty == 24, "leading-edge particles are equal at 30/60 samples and capped per stroke")
	check(profile_sample(30) == profile_sample(60), "shared-profile leading fragments have frame-rate-independent sample count")
	game.player._cancel_attack()
	# Ghosts contain immutable presentation data, including reaction stages.
	wipe()
	game.player.combo = 3
	game.player.parry_phase = "recoil"
	game.player._parry_elapsed = game.player.PARRY_RECOIL * 0.6
	game.player.animation_state = "parry_recoil"
	fx._ghost(game.player, "hero", Color.CYAN, 0.6, 0.3)
	var hero_ghost: Node = fx._ghosts.back()
	var snapshot_progress: float = hero_ghost.get_parry_progress()
	check(hero_ghost.scale == Vector2.ONE and not hero_ghost.z_as_relative and hero_ghost.z_index == 1, "outline ghost keeps native scale and stays below actors")
	hero_ghost.tick(0.02)
	check(hero_ghost.scale == Vector2.ONE and hero_ghost.max_life <= 0.14, "fading ghost never inflates or lives beyond short pixel trail")
	check(hero_ghost.airborne == (not game.player.is_on_floor()), "hero ghost snapshots airborne art selection")
	var ghost_count_before: int = fx.ghost_count()
	fx._clock += 0.05
	fx._ghost(game.player, "hero", Color.CYAN, 0.6, 0.3)
	check(fx.ghost_count() == ghost_count_before, "elapsed time alone cannot duplicate a stationary ghost")
	for sample: int in 12:
		fx._clock += 0.04
		game.player.position.x += 7.0
		fx._ghost(game.player, "hero", Color.CYAN, 0.6, 0.3)
	check(fx.ghost_count() <= fx.MAX_OWNER_GHOSTS, "one actor can own at most five outline ghosts")
	game.player.position = position_before
	game.player.combo = 1
	game.player._clear_parry()
	check(hero_ghost.combo == 3 and hero_ghost.parry_phase == "recoil", "ghost preserves combo and parry stage instead of live defaults")
	check(is_equal_approx(hero_ghost.get_parry_progress(), snapshot_progress) and snapshot_progress > 0.5, "ghost keeps a scalar snapshot of parry progress")
	var boss := Boss.new()
	game.add_child(boss)
	boss.configure(game, Vector2(900, 300))
	boss.set_physics_process(false)
	boss.reaction_state = "guard_break"
	boss.reaction_progress = 0.35
	boss.animation_state = "guard_break"
	fx._ghost(boss, "boss", Color.GOLD, 0.6, 0.3)
	var boss_ghost: Node = fx._ghosts.back()
	boss.reaction_state = "none"
	boss.reaction_progress = 0.0
	check(boss_ghost.reaction_state == "guard_break" and is_equal_approx(boss_ghost.reaction_progress, 0.35), "Boss snapshot keeps the actual break pose after actor recovery")
	check(not boss_ghost.boss_pose_snapshot.is_empty(), "Boss ghost captures the pure KatanaVisual pose description")
	check(boss_ghost.impact_flash == 0.0, "snapshot hurt flash cannot obscure the break pose")
	# Compare locked warning columns with the same friend pattern descriptors used at release.
	wipe()
	game.boss = boss
	game.player.position.x = 3000.0
	boss._begin_attack("rain", {"count": 7, "speed": 130.0, "safe_lane_half_width": 30.0})
	var warning: Dictionary = fx._warns.back()
	var rain_columns: Array = warning.get("columns", []).duplicate()
	var locked_geometry: Dictionary = boss.get_warning_geometry("rain")
	check(rain_columns == locked_geometry.get("columns", []), "rain warning snapshots the Boss pure locked geometry")
	game.player.position.x += 100.0
	boss._release_attack()
	var actual_columns: Array[float] = []
	for rain_shot: Node in get_nodes_in_group("projectiles"):
		if not rain_shot.is_queued_for_deletion() and not rain_shot._cleared:
			rain_shot.set_physics_process(false)
			actual_columns.append(rain_shot.global_position.x)
			rain_shot.clear()
	actual_columns.sort()
	rain_columns.sort()
	var columns_match: bool = actual_columns.size() == rain_columns.size() and rain_columns.size() > 0
	for i: int in mini(actual_columns.size(), rain_columns.size()):
		columns_match = columns_match and is_equal_approx(actual_columns[i], float(rain_columns[i]))
	check(columns_match, "locked rain warning and actual friend projectiles agree after player movement")
	check(rain_columns.all(func(x: Variant) -> bool: return absf(float(x)-3000.0) >= 30.0), "locked rain center safe lane stays unmarked")
	check(warning["kind"] == "rain", "rain event retains its specialized warning kind")
	game.player.position = position_before
	game.boss = null
	boss.queue_free()
	# A real projectile must survive its second cache sample, then clear without a stale tail.
	wipe()
	var shot: Node2D = game.spawn_projectile(Vector2(800, 140), Vector2.RIGHT * 30.0, false)
	shot.set_physics_process(false)
	fx._track_projectiles()
	shot.position.x += 4.0
	fx._track_projectiles()
	var id: int = shot.get_instance_id()
	check(fx._proj_trails.has(id) and fx._proj_trails[id]["pts"].size() == 2, "second projectile frame reuses Dictionary pts safely")
	shot.friendly = true
	fx._track_projectiles()
	check(fx._proj_trails[id]["friendly"], "projectile reflection updates the trail palette")
	shot.clear()
	fx._track_projectiles()
	check(not fx._proj_trails.has(id), "cleared projectile loses its tail before queued deletion")
	# Repeat rest/reset boundaries with live effects and warnings; no ambient respawn in rest.
	for cycle: int in 3:
		game.set_story_safe(false)
		wipe()
		fx.spawn("enemy_slash", Vector2(600, 250), Vector2.LEFT, 1.0)
		fx.spawn("hit", Vector2(300, 250), Vector2.RIGHT, 1.0)
		game.warning_issued.emit("unblockable_charge", Vector2(400, 250), 0.5)
		game.warning_issued.emit("armored_slash", Vector2(450, 250), 0.5)
		check(fx.warning_count() == 2 and fx._warns[0]["kind"] == "unblockable_charge" and fx._warns[1]["kind"] == "armored_slash", "warning kinds remain distinct in cycle %d" % cycle)
		game.set_story_safe(true)
		game.player.velocity.x = 160.0
		for _i: int in 10:
			fx._process(0.05)
		game.player.velocity = Vector2.ZERO
		var counts: Dictionary = fx.counts()
		check(counts.values().all(func(n: Variant) -> bool: return int(n) == 0), "rest clears old combat/ghosts/trails and suppresses ambient cycle %d" % cycle)
		fx.spawn("slash", Vector2(300, 250), Vector2.RIGHT, 2.0)
		check(fx.shape_count() == 0, "late attack events cannot redraw in rest cycle %d" % cycle)
	fx.spawn("burst", Vector2(300, 250), Vector2.UP, 3.0)
	fx.clear_hostile()
	fx._process(0.01)
	check(fx.shape_count() > 0 and fx.particle_count() > 0, "victory burst survives safe cleanup")
	game.set_story_safe(false)
	wipe()
	game.player._cancel_attack()
	game.player.animation_state = "idle"
	for _i: int in 320:
		fx.spawn("hit", Vector2(320, 250), Vector2.RIGHT, 2.0)
		fx._ghost(game.player, "hero", Color.CYAN, 0.5, 0.3)
	check(fx.particle_count() <= fx.MAX_PARTS and fx.shape_count() <= fx.MAX_SHAPES and fx.ghost_count() <= fx.MAX_GHOSTS, "parts/shapes/ghost caps hold under repeated contact")
	game.set_story_safe(true)
	fx.spawn("burst", Vector2(300, 250), Vector2.UP, 1.0)
	for _i: int in 80:
		fx._process(0.05)
	check(fx.counts().values().all(func(n: Variant) -> bool: return int(n) == 0), "all transient celebration shapes and particles expire")
	check(game.player.health == health and game.player.position == position_before and game.score == score, "VFX never changes health, position or score")
	check(Engine.time_scale == time_scale_before and not paused, "VFX leaves global time and pause unchanged")
	print("Fused FX: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
