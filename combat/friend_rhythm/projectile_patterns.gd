# Adapted from zjuan-ctrl, AIgame-by-ncu PR #1, commit 4e79620503bc9fd05a2154018ec97ec76f227557.
# Original source MIT, Copyright (c) 2026 yosemitezz. See root THIRD_PARTY_NOTICES.md.
# No private recording or reference chart is included.
extends RefCounted
## Actual aimed/spread/radial/rain vector math adapted from ProjectileSystem.
## Descriptors go to the root's swept, parryable projectiles and global cap.
static func vectors(pattern_id: String, parameters: Dictionary, origin: Vector2, target: Vector2, arena_rect: Rect2) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var count: int = clampi(int(parameters.get("count", 1)), 1, 48)
    var speed: float = clampf(float(parameters.get("speed", 118.0)), 20.0, 360.0)
    var spread: float = clampf(float(parameters.get("spread_degrees", 60.0)), 0.0, 180.0)
    var base_direction: Vector2 = (target - origin).normalized()
    if base_direction.length_squared() < 0.1:
        base_direction = Vector2.LEFT
    match pattern_id:
        "aimed", "spread":
            for index: int in count:
                var angle: float = 0.0
                if count > 1:
                    angle = deg_to_rad(spread) * ((float(index) / float(count - 1)) - 0.5)
                result.append({"position": origin, "velocity": base_direction.rotated(angle) * speed})
        "radial":
            var start_angle: float = float(parameters.get("start_angle_degrees", 0.0))
            var gap_center: float = deg_to_rad(float(parameters.get("gap_center_degrees", -90.0)))
            var gap_half: float = deg_to_rad(float(parameters.get("gap_half_degrees", 0.0)))
            for index: int in count:
                var angle: float = deg_to_rad(start_angle + 360.0 * float(index) / float(count))
                if gap_half > 0.0 and absf(wrapf(angle - gap_center, -PI, PI)) <= gap_half:
                    continue
                result.append({"position": origin, "velocity": Vector2.from_angle(angle) * speed})
        "rain":
            for index: int in count:
                var lane_t: float = (float(index) + 0.5) / float(count)
                var at: Vector2 = Vector2(lerpf(arena_rect.position.x + 12.0, arena_rect.end.x - 12.0, lane_t), arena_rect.position.y - 8.0)
                var safe_x: float = float(parameters.get("safe_lane_x", INF))
                if absf(at.x - safe_x) < float(parameters.get("safe_lane_half_width", 0.0)):
                    continue
                result.append({"position": at, "velocity": Vector2.DOWN * speed})
    return result
