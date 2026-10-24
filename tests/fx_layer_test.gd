extends SceneTree
## VFX safety checks: every effect kind spawns and expires, caps hold, rest sections draw no telegraph,
## and effects never change gameplay state. It does not judge how the effects look.

const KINDS: Array[String] = ["slash", "enemy_slash", "parry", "parry_ready", "hit", "hurt", "dash", "jump", "air_jump", "land",
	"pickup", "checkpoint", "death", "burst", "boss_defeat", "spark", "warning", "telegraph", "unknown_kind"]
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
		enemy.set_physics_process(false)
	var fx: Node = game.get_node_or_null("FxLayer")
	check(fx != null, "FxLayer is attached to the game")
	var health: int = game.player.health
	var pos: Vector2 = game.player.position
	var score: int = game.score
	# Doubled-up contact events must collapse into one deflect, not stack.
	for kind: String in ["blade_parry", "projectile_parry", "guard_break", "dash_start", "enemy_dash", "dash_ghost", "unblockable_charge", "impact", "debris", "lunge"]:
		game.emit_fx(kind, Vector2(300, 250), Vector2.RIGHT, 1.2)
	fx._process(0.2)
	for kind: String in KINDS:
		var before: int = fx.particle_count() + fx.shape_count()
		game.emit_fx(kind, Vector2(300, 250), Vector2.RIGHT, 1.5)
		var after: int = fx.particle_count() + fx.shape_count()
		check(after >= before, "%s does not crash and keeps state consistent" % kind)
	check(fx.particle_count() > 0 and fx.shape_count() > 0, "effects produced particles and shapes")
	# The deflect must be a burst, not a ring: it should spawn many shapes and sparks at once.
	for _i: int in 100:
		fx._process(0.05)
	game.emit_fx("parry", Vector2(300, 250), Vector2.RIGHT, 1.4)
	check(fx.shape_count() >= 8 and fx.particle_count() >= 60, "parry deflect is a full burst (%d shapes, %d particles)" % [fx.shape_count(), fx.particle_count()])
	# Let the engine run its real draw passes (headless still executes _draw); engine errors would fail the run.
	for _i: int in 20:
		await process_frame
	check(fx.shape_count() > 0, "deflect survives real draw frames")
	# Variety: no two swings in a row look alike, and every personality shows up.
	var kinds_seen: Dictionary = {}
	var prev_kind: int = -1
	var prev_hue: float = -1.0
	var repeats: int = 0
	var close_hue: int = 0
	for _i: int in 80:
		game.emit_fx("slash", Vector2(300, 250), Vector2.RIGHT, float(1 + _i % 3))
		kinds_seen[fx.style_kind] = true
		if fx.style_kind == prev_kind:
			repeats += 1
		if prev_hue >= 0.0 and absf(fposmod(fx._hue_shift - prev_hue + 0.5, 1.0) - 0.5) < 0.2:
			close_hue += 1
		prev_kind = fx.style_kind
		prev_hue = fx._hue_shift
		fx._process(0.1)
	check(repeats == 0, "no swing repeats the previous swing style (%d repeats)" % repeats)
	check(kinds_seen.size() == 6, "all six swing personalities appear (%d)" % kinds_seen.size())
	check(close_hue <= 4, "consecutive swings differ in hue (%d too close of 80)" % close_hue)
	var hit_kinds: Dictionary = {}
	for _i: int in 40:
		game.emit_fx("hit", Vector2(300, 250), Vector2.RIGHT, 1.0)
		hit_kinds[fx._last_hit_kind] = true
		fx._process(0.1)
	check(hit_kinds.size() == 4, "all four hit looks appear (%d)" % hit_kinds.size())
	# Hammer the caps.
	for _i: int in 300:
		game.emit_fx("burst", Vector2(300, 250), Vector2.ZERO, 3.0)
	check(fx.particle_count() <= 800 and fx.shape_count() <= 64, "particle and shape caps hold (%d / %d)" % [fx.particle_count(), fx.shape_count()])
	for _i: int in 4:
		await process_frame
	# Everything expires.
	for _i: int in 100:
		fx._process(0.05)
	# Ambient motes keep spawning by design, so only shapes and afterimages must drain completely.
	check(fx.shape_count() == 0 and fx.ghost_count() == 0, "all shapes and afterimages expire")
	check(fx.particle_count() <= 800, "ambient particles stay bounded")
	# Afterimages: a parry spawns one, and the cap holds under repeated dashes.
	game.player.set("dash_timer", 1.0)
	for _i: int in 200:
		fx._process(0.03)
	check(fx.ghost_count() > 0 and fx.ghost_count() <= 28, "dash afterimages spawn and stay capped (%d)" % fx.ghost_count())
	game.player.set("dash_timer", 0.0)
	for _i: int in 60:
		fx._process(0.05)
	check(fx.ghost_count() == 0, "afterimages drain after the dash ends")
	# Running leaves a trail: scarf particles, heel dust and a faint afterimage, without a dash.
	game.player.set("velocity", Vector2(160.0, 0.0))
	var ran_ghost: bool = false
	for _i: int in 40:
		fx._process(0.03)
		ran_ghost = ran_ghost or fx.ghost_count() > 0
	check(ran_ghost, "running spawns afterimages and trail particles")
	game.player.set("velocity", Vector2.ZERO)
	# Impact blur and heavier camera shake: strong, bounded, decays fully, respects reduced motion.
	var blur: Node = game.get_node_or_null("MotionBlur")
	check(blur != null, "MotionBlur layer is attached")
	for _i: int in 120:
		blur._process(0.05)   # earlier checks fired hundreds of events; let the blur settle first
	check(not blur.is_active(), "blur is hidden while idle")
	game.emit_fx("guard_break", Vector2(300, 250), Vector2.RIGHT, 1.7)
	blur._process(0.016)
	check(blur.is_active() and blur.blur_vec.length() > 0.05 and blur.radial > 0.2, "guard break produces a strong blur (%.3f / %.2f)" % [blur.blur_vec.length(), blur.radial])
	check(blur.blur_vec.length() <= blur.MAX_BLUR + 0.0001 and blur.radial <= blur.MAX_RADIAL + 0.0001 and blur.chroma <= blur.MAX_CHROMA + 0.0001, "blur stays inside its caps")
	for _i: int in 40:
		blur._process(0.016)
	check(not blur.is_active(), "blur decays to nothing and hides itself")
	game.impact.reduced_motion = true
	game.emit_fx("hit", Vector2(300, 250), Vector2.RIGHT, 2.0)
	blur._process(0.016)
	check(not blur.is_active(), "reduced motion (F2) disables the blur")
	game.impact.reduced_motion = false
	game.set_story_safe(true)
	game.emit_fx("hit", Vector2(300, 250), Vector2.RIGHT, 2.0)
	blur._process(0.016)
	check(not blur.is_active(), "no blur in story-safe sections")
	game.set_story_safe(false)
	game.impact.request(game.player, null, false, true, "break")
	var peak: float = 0.0
	for _i: int in 6:
		peak = maxf(peak, game.impact.sample_camera(1.0 / 60.0).length())
	check(peak >= 5.0 and peak <= game.impact.MAX_OFFSET + 0.001, "guard break shakes the camera hard but within the cap (peak %.1f px)" % peak)
	for _i: int in 240:
		game.impact.sample_camera(1.0 / 60.0)
	check(game.impact.sample_camera(1.0 / 60.0).length() < 0.05, "camera shake settles completely")
	# Warning lanes: in the merged game combat_vfx owns telegraphs, so this layer draws none by default.
	game.emit_signal("warning_issued", "melee", Vector2(400, 280), 0.5)
	check(fx.warning_count() == 0, "gradient layer leaves telegraph drawing to the pixel layer by default")
	fx.draw_warnings = true
	# Warning lanes: shown while awake, never in a story-safe section.
	game.emit_signal("warning_issued", "melee", Vector2(400, 280), 0.5)
	check(fx.warning_count() == 1, "warning lane recorded when enabled")
	game.set_story_safe(true)
	game.emit_signal("warning_issued", "melee", Vector2(400, 280), 0.5)
	fx._process(0.01)
	check(fx.warning_count() == 0, "no warning lane while story-safe")
	game.set_story_safe(false)
	check(game.player.health == health and game.player.position == pos and game.score == score, "effects do not change gameplay state")
	print("FX layer: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
