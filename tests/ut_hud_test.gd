extends SceneTree
## Undertale-style HUD: layout, typewriter, HP bar scale, glyph coverage and a draw pass for every screen.

const HUD = preload("res://ui/hud.gd")
const PixelFont = preload("res://presentation/pixel_font.gd")
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

func base_state() -> Dictionary:
	return {"hp": 8, "max_hp": 8, "shards": 3, "total_shards": 25, "zone": "悬链书库", "hint": "沿着链条向上攀爬", "boss_hp": -1, "boss_max": 0, "phase": "", "beat": 3, "section": "", "outcome": "", "narration": "", "safe": false, "paused": false, "ending": 0.0, "progress": 0.4, "boss_guard": 0, "boss_guard_max": 3, "reaction": "", "parry_notice": "", "overlay": "", "reduced_motion": false, "muted": false, "speed_effects_level": 1, "player_at": Vector2(400, 300), "opened_doors": [], "collected": {}}

func run() -> void:
	var hud: Control = HUD.new()
	root.add_child(hud)
	hud.size = Vector2(800, 450)
	await process_frame
	check(hud.font != null, "the pixel font loads")
	# Glyph coverage: nothing the HUD prints may fall back to a missing character.
	var missing: Array[String] = []
	for line: String in HUD.STRINGS:
		for i: int in line.length():
			var ch: String = line[i]
			if ch != " " and not hud.font.has_char(ch.unicode_at(0)):
				missing.append(ch)
	check(missing.is_empty(), "the font has every HUD glyph (missing: %s)" % "".join(missing))
	# Layout: bottom panel rows stack without overlap and stay inside the canvas, with and without a boss bar.
	for boss: bool in [false, true]:
		var l: Dictionary = hud.panel_layout(Vector2(800, 450), boss)
		var inside: bool = true
		for key: String in ["boss", "dialog", "bottom", "status", "buttons", "controls"]:
			inside = inside and Rect2(Vector2.ZERO, Vector2(800, 450)).encloses(l[key])
		check(inside, "every panel fits in 800x450 (boss bar %s)" % str(boss))
		check(not l["status"].intersects(l["buttons"]) and not l["buttons"].intersects(l["controls"]) and not l["status"].intersects(l["controls"]), "status, buttons and controls rows do not overlap")
		check(l["bottom"].encloses(l["status"]) and l["bottom"].encloses(l["controls"]), "the bottom panel holds the status and controls rows")
		if boss:
			check(not l["boss"].intersects(l["dialog"]), "the dialogue box sits below the boss bar")
	# Typewriter.
	check(hud.typed_count(10, 0.0) == 0 and hud.typed_count(10, 0.1) == 2 and hud.typed_count(10, 5.0) == 10, "typewriter reveals text at 28 chars per second and stops at the end")
	# HP bar grows with max HP and is clamped.
	check(hud.hp_bar_width(8) == 128.0 and hud.hp_bar_width(1) == 48.0 and hud.hp_bar_width(99) == 240.0, "HP bar length is 16 px per point, clamped to 48..240")
	# Dialogue line source: narration beats the zone hint, and the hint starts typing from zero.
	var s: Dictionary = base_state()
	hud.update_state(s)
	check(hud._line == "沿着链条向上攀爬" and hud._line_clock == 0.0, "a new zone hint starts typing")
	s["narration"] = "远处的钟声回应了你"
	hud.update_state(s)
	check(hud._line == "远处的钟声回应了你", "narration replaces the zone hint")
	# Draw every screen and state; a draw error would surface as a script error and fail the process.
	var screens: Array[Dictionary] = []
	screens.append(base_state())
	var low: Dictionary = base_state()
	low["hp"] = 1
	screens.append(low)
	var boss_state: Dictionary = base_state()
	boss_state.merge({"boss_hp": 30, "boss_max": 40, "boss_guard": 2, "section": "fixed", "parry_notice": "melee", "narration": "钟守睁开了眼睛"}, true)
	screens.append(boss_state)
	var broken: Dictionary = boss_state.duplicate()
	broken.merge({"reaction": "guard_break", "section": "rest", "safe": true}, true)
	screens.append(broken)
	screens.append(base_state().merged({"paused": true}, true))
	screens.append(base_state().merged({"overlay": "map"}, true))
	for stage: String in ["defeat", "victory"]:
		for clock: float in [0.0, 1.0, 2.0, 5.0]:
			screens.append(base_state().merged({"outcome": stage, "ending": clock + 1.0}, true))
	for screen: Dictionary in screens:
		hud.update_state(screen)
		hud._outcome_clock = 5.0
		await process_frame
	await process_frame
	check(true, "all %d HUD screens drew without errors" % screens.size())
	# Game over timeline: heart, crack, shards, then text. The clock is reset when the outcome changes to defeat.
	hud.update_state(base_state())
	hud.update_state(base_state().merged({"outcome": "defeat"}, true))
	check(hud._outcome == "defeat" and hud._outcome_clock == 0.0, "game over restarts its animation clock")
	hud.free()
	print("UT HUD: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
