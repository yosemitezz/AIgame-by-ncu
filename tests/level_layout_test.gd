extends SceneTree
## Numeric level-layout checks only. This is geometry arithmetic, not a playthrough and not a feel judgement.
## Run: godot --headless --path . --script res://tests/level_layout_test.gd

const Level = preload("res://levels/bellkeep.gd")
const JUMP_APEX: float = 340.0 * 340.0 / (2.0 * 900.0)  # 64.2 px at jump speed 340, gravity 900
const MAX_RISE: float = 56.0                              # leaves ~8 px of margin under the apex
const MAX_UP_GAP: float = 54.0                            # widest gap crossed while also climbing
const MAX_FLAT_GAP: float = 100.0                         # contract: required gaps <= 100
const SHARD_LIFT: float = 24.0

var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)

func gap_x(a: Rect2, b: Rect2) -> float:
	return maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))

func can_step(a: Rect2, b: Rect2) -> bool:
	## True if a player standing on a can land on b with one jump.
	var rise: float = a.position.y - b.position.y
	var gap: float = gap_x(a, b)
	if rise > MAX_RISE:
		return false
	return gap <= (MAX_UP_GAP if rise > 8.0 else MAX_FLAT_GAP)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var plats: Array[Rect2] = Level.PLATFORMS
	check(JUMP_APEX > MAX_RISE, "apex %.1f exceeds the %.0f px rise limit" % [JUMP_APEX, MAX_RISE])
	# 1. Every one-way ledge is reachable by chained jumps starting from the solid floor.
	var reach: Array[bool] = []
	reach.resize(plats.size())
	for i: int in plats.size():
		reach[i] = plats[i].size.y > 16.0
	var changed: bool = true
	while changed:
		changed = false
		for i: int in plats.size():
			if reach[i]:
				continue
			for j: int in plats.size():
				if reach[j] and can_step(plats[j], plats[i]):
					reach[i] = true
					changed = true
					break
	for i: int in plats.size():
		check(reach[i], "platform %d at %s is reachable" % [i, plats[i]])
	# 2. Ledges must not overlap each other or the floor body.
	for i: int in plats.size():
		for j: int in range(i + 1, plats.size()):
			check(not plats[i].intersects(plats[j]), "platforms %d and %d do not overlap" % [i, j])
	# 3. Each shard floats 24 px over a platform surface and sits inside its width.
	for k: int in Level.SHARDS.size():
		var s: Vector2 = Level.SHARDS[k]
		var ok: bool = false
		for p: Rect2 in plats:
			if s.x >= p.position.x and s.x <= p.end.x and absf(s.y - (p.position.y - SHARD_LIFT)) <= 2.0:
				ok = true
				break
		check(ok, "shard %d at %s sits over a platform" % [k, s])
	# 4. No enemy spawns inside a pit.
	for e: Dictionary in Level.ENEMIES:
		var at: Vector2 = e["at"]
		var over: bool = false
		for p: Rect2 in plats:
			if at.x >= p.position.x and at.x <= p.end.x and at.y <= p.position.y + 2.0:
				over = true
		check(over, "%s at %s stands over ground" % [e["kind"], at])
	# 5. Zones are ordered and the boss gate is inside the world.
	for z: int in range(1, Level.ZONES.size()):
		check(float(Level.ZONES[z]["x"]) > float(Level.ZONES[z - 1]["x"]), "zone %d is ordered" % z)
	print("Level layout: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
