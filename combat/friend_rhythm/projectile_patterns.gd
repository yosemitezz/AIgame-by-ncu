# Adapted from yosemitezz/AIgame-by-ncu boss_attack, PR #1 by zjuan-ctrl
# and final PR #3 (head fff7526a3dc687c9625dece860a79695c00db8d0).
# MIT source only. See third_party/friend-boss-pr1/LICENSE.
# No private recording or source chart is loaded by this port.
extends RefCounted
## PR3 ProjectileSystem ring/fan/side_spray geometry, with bounded attempts.
static func vectors(kind: String, action: Dictionary, origin: Vector2, locked_target: Vector2) -> Array[Dictionary]:
    var shots: Array[Dictionary] = []
    var count: int = clampi(int(action.get("count", 3)), 1, 24)
    var speed: float = clampf(float(action.get("speed", 150.0)), 20.0, 360.0)
    var ttl: float = clampf(float(action.get("ttl_seconds", 2.0)), 0.1, 6.0)
    var offset: float = float(action.get("angle_offset_degrees", 0.0))
    var base: Vector2 = (locked_target - origin).normalized()
    if base == Vector2.ZERO:
        base = Vector2.DOWN
    base = base.rotated(deg_to_rad(offset))
    for index: int in count:
        if kind == "side_spray":
            var start: Vector2 = origin + Vector2((float(index) - float(count - 1) * 0.5) * 13.0, 0.0)
            for side: float in [-1.0, 1.0]:
                shots.append({"position": start, "velocity": Vector2(speed * 0.22, side * speed), "ttl_seconds": ttl})
        elif kind == "ring":
            var angle: float = deg_to_rad(offset + 360.0 * float(index) / float(count))
            shots.append({"position": origin, "velocity": Vector2.from_angle(angle) * speed, "ttl_seconds": ttl})
        elif kind == "fan":
            var fraction: float = 0.5 if count <= 1 else float(index) / float(count - 1)
            var angle: float = deg_to_rad(clampf(float(action.get("spread_degrees", 34.0)), 0.0, 180.0)) * (fraction - 0.5)
            shots.append({"position": origin, "velocity": base.rotated(angle) * speed, "ttl_seconds": ttl})
    return shots
