extends Node2D
## Bounded pixel presentation. All lifetimes use real frame delta; no time scale/pause writes.
## Crescent + blade-tip trail adapted from CodingQuests/godot-hitbox-hurtbox,
## scripts/WeaponController.gd, commit 7ccc10925a07960772d83db970d56fef875a983d,
## MIT (c) 2026 CodingQuests. License: third_party/codingquests/LICENSE.
## Geometry is rasterized in generate_combat_frames.py.
## Trail start/sample/end follows actual ACTIVE phase; pixel path capped at 8,
## rounded to world pixels and faded over 0.16s instead of scaling a soft Line2D.
const ActorRenderer = preload("res://presentation/actor_renderer.gd")
const MAX_EFFECTS: int = 64
const MAX_CHIPS: int = 72
const MAX_GHOSTS: int = 3
const MAX_TRAIL_POINTS: int = 8
const TRAIL_FADE: float = 0.16
var game: Node
var _effects: Array[Dictionary] = []
var _chips: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _warnings: Array[Dictionary] = []
var _trails: Array[Dictionary] = []
var _current_trail: int = -1
var _last_serial: int = -1
var _texture_cache: Dictionary = {}
var _clock: float = 0.0
var _last_ghost_clock: float = -1000.0
var _last_ghost_at := Vector2.INF
var _rng := RandomNumberGenerator.new()

func configure(p_game: Node) -> void:
    game = p_game
    z_index = 8
    process_mode = Node.PROCESS_MODE_PAUSABLE
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _rng.seed = 90210
    if game.has_signal("warning_issued") and not game.warning_issued.is_connected(_on_warning):
        game.warning_issued.connect(_on_warning)

func _texture(name: String) -> Texture2D:
    if not _texture_cache.has(name):
        var path: String = "res://presentation/parry_frames/%s.png" % name.trim_prefix("parry/") if name.begins_with("parry/") else "res://presentation/feel_frames/%s.png" % name
        _texture_cache[name] = load(path)
    return _texture_cache[name]

func emit_effect(kind: String, at: Vector2, direction: Vector2, power: float = 1.0) -> void:
    var sign_x: int = -1 if direction.x < 0 else 1
    match kind:
        "slash", "enemy_slash":
            var combo: int = clampi(roundi(power), 1, 3)
            if kind == "slash" and is_instance_valid(game) and is_instance_valid(game.player):
                combo = clampi(int(game.player.combo), 1, 3)
            _add_effect(kind, at, sign_x, 0.14 if combo < 3 else 0.18, "slash_%d" % combo, 96, kind == "enemy_slash")
            if kind == "slash" and is_instance_valid(game) and is_instance_valid(game.player):
                var effect: Dictionary = _effects.back()
                effect["bound_owner"] = weakref(game.player)
                effect["serial"] = int(game.player.attack_serial)
                effect["owner_offset"] = at - game.player.global_position
                effect["progress"] = 0.0
        "blade_parry", "projectile_parry", "guard_break":
            if _recent(kind, at, 0.025):
                return
            var size: int = 40 if kind == "projectile_parry" else (96 if kind == "guard_break" else 80)
            var duration: float = 0.14 if kind == "projectile_parry" else (0.25 if kind == "guard_break" else 0.16)
            _add_effect(kind, at, sign_x, duration, "parry/" + kind, size)
            _effects.back()["frames"] = 6
            _contact_sparks(at, direction, 4 if kind == "projectile_parry" else (10 if kind == "guard_break" else 8), kind == "guard_break")
        "parry":
            if _recent("parry", at, 0.035):
                return
            _add_effect(kind, at, sign_x, 0.23, "parry", 80)
            _scatter(at, direction, 7, true, 1.15)
        "hit", "hurt", "impact":
            if _recent("hit", at, 0.03):
                return
            _add_effect("hit", at, sign_x, 0.16, "hit", 48)
            _scatter(at, direction, 4 if power < 1.4 else 7, kind != "hurt", 0.9 if power < 1.4 else 1.2)
        "dash", "dash_ghost":
            _snapshot_ghost()
        "dash_start":
            _scatter(at, -direction, 2, true, 0.45)
        "enemy_dash":
            _add_effect(kind, at, sign_x, 0.15, "", 0, true)
            _scatter(at, -direction, 3, false, 0.45)
        "death", "boss_defeat", "burst":
            _add_effect("burst", at, sign_x, 0.25, "hit", 48)
            _scatter(at, direction, 9 if power < 2 else 12, false, 1.35)
        "land", "jump", "air_jump":
            _scatter(at, Vector2.UP, 3, kind == "air_jump", 0.55)
        "pickup", "checkpoint":
            _add_effect(kind, at, sign_x, 0.30 if kind == "checkpoint" else 0.19)
            _scatter(at, Vector2.UP, 5 if kind == "checkpoint" else 3, true, 0.6)
        "parry_ready":
            _add_effect(kind, at, sign_x, 0.11)
        "spark", "debris":
            _scatter(at, direction, 2, false, 0.45)
        "telegraph", "warning", "charge":
            # warning_issued owns tells, so a second decorative spark does not obscure them.
            pass
    queue_redraw()

func _recent(kind: String, at: Vector2, seconds: float) -> bool:
    for effect: Dictionary in _effects:
        if effect["kind"] == kind and float(effect["age"]) < seconds and Vector2(effect["at"]).distance_to(at) < 18:
            return true
    return false

func _add_effect(kind: String, at: Vector2, facing: int, duration: float, image: String = "", size: int = 0, hostile: bool = false) -> void:
    _effects.append({"kind": kind, "at": at.round(), "facing": facing, "age": 0.0, "duration": duration, "image": image, "size": size, "hostile": hostile})
    if _effects.size() > MAX_EFFECTS:
        _effects.pop_front()

func _scatter(at: Vector2, direction: Vector2, amount: int, cyan: bool, force: float) -> void:
    for i: int in amount:
        var normal: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.UP
        var spread: float = _rng.randf_range(-1.3, 1.3)
        var speed: float = _rng.randf_range(35, 95) * force
        _chips.append({"at": at.round(), "motion": normal.rotated(spread) * speed, "age": 0.0, "duration": _rng.randf_range(0.16, 0.31), "cyan": cyan, "size": 2 if i % 3 else 3})
    while _chips.size() > MAX_CHIPS:
        _chips.pop_front()

func _contact_sparks(at: Vector2, direction: Vector2, amount: int, heavy: bool) -> void:
    var normal: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
    for i: int in amount:
        # Short orange/gold fan: deliberately distinct from the colored outer ribbon.
        var spread: float = lerpf(-0.95, 0.95, float(i) / maxf(1, amount - 1))
        var speed: float = _rng.randf_range(60, 130) * (1.15 if heavy else 1.0)
        var color: Color = Color("ffd27b") if i % 3 == 0 else Color("f0a150")
        _chips.append({"at": at.round(), "motion": normal.rotated(spread) * speed, "age": 0.0, "duration": _rng.randf_range(0.10, 0.18), "cyan": false, "size": 2 if i % 3 == 0 else 1, "color": color, "trail_len": 5.0 if heavy else 4.0})
    while _chips.size() > MAX_CHIPS:
        _chips.pop_front()

func _snapshot_ghost() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        return
    var actor: Node2D = game.player
    var position_now: Vector2 = actor.global_position.round()
    if _clock - _last_ghost_clock < 0.035 or position_now.distance_squared_to(_last_ghost_at) < 36.0:
        return
    _last_ghost_clock = _clock
    _last_ghost_at = position_now
    var region: Rect2 = ActorRenderer.hero_region(str(actor.animation_state), int(actor.frame), int(actor.combo), ActorRenderer.is_airborne(actor))
    _ghosts.append({"at": actor.global_position.round(), "region": region, "facing": int(actor.facing), "age": 0.0, "duration": 0.15})
    while _ghosts.size() > MAX_GHOSTS:
        _ghosts.pop_front()

func _on_warning(kind: String, at: Vector2, duration: float) -> void:
    if is_instance_valid(game) and not bool(game.story_safe):
        _warnings.append({"kind": kind, "at": at.round(), "age": 0.0, "duration": maxf(duration, 0.01)})
        if _warnings.size() > 12:
            _warnings.pop_front()

func clear_hostile() -> void:
    _warnings.clear()
    for i: int in range(_effects.size() - 1, -1, -1):
        if bool(_effects[i]["hostile"]) or _effects[i]["kind"] in ["slash", "enemy_slash"]:
            _effects.remove_at(i)
    # Blade trails are remnants of a cancelled attack, not ambient decoration.
    _trails.clear()
    _current_trail = -1
    _last_serial = -1
    queue_redraw()

func counts() -> Dictionary:
    return {"effects": _effects.size(), "chips": _chips.size(), "ghosts": _ghosts.size(), "warnings": _warnings.size(), "trails": _trails.size()}

func _start_trail(serial: int) -> void:
    _end_trail()
    _trails.append({"serial": serial, "points": [], "ended": false, "age": 0.0})
    _current_trail = _trails.size() - 1
    _last_serial = serial

func _update_trail(actor: Node2D) -> void:
    if _current_trail < 0 or _current_trail >= _trails.size():
        return
    var local_tip: Vector2 = ActorRenderer.weapon_tip_local(int(actor.combo), int(actor.frame), ActorRenderer.is_airborne(actor))
    local_tip.x *= int(actor.facing)
    var tip: Vector2 = (actor.global_position + local_tip).round()
    var points: Array = _trails[_current_trail]["points"]
    if points.is_empty() or Vector2(points.back()).distance_squared_to(tip) > 1.0:
        points.append(tip)
    if points.size() > MAX_TRAIL_POINTS:
        points.pop_front()

func _end_trail() -> void:
    if _current_trail >= 0 and _current_trail < _trails.size():
        _trails[_current_trail]["ended"] = true
        _trails[_current_trail]["age"] = 0.0
    _current_trail = -1

func _sample_player_trail() -> void:
    if not is_instance_valid(game) or not is_instance_valid(game.player) or bool(game.story_safe):
        _end_trail()
        return
    var actor: Node2D = game.player
    var phase: Variant = actor.get("attack_phase")
    if phase == "active":
        var serial: int = int(actor.get("attack_serial"))
        if _current_trail < 0 or serial != _last_serial:
            _start_trail(serial)
        _update_trail(actor)
    else:
        _end_trail()

func _process(delta: float) -> void:
    _clock += delta
    for i: int in range(_effects.size() - 1, -1, -1):
        var effect: Dictionary = _effects[i]
        if effect.has("bound_owner"):
            var owner_actor: Node2D = effect["bound_owner"].get_ref()
            if not is_instance_valid(owner_actor) or owner_actor.attack_phase != "active" or int(owner_actor.attack_serial) != int(effect["serial"]):
                _effects.remove_at(i)
                continue
            # Actual ACTIVE progress owns this pose: local hit-stop freezes the crescent
            # together with the body/blade. Cancel/new serial removes it immediately.
            var progress: float = float(owner_actor.get_attack_progress()) if owner_actor.has_method("get_attack_progress") else float(owner_actor.get("_phase_elapsed")) / maxf(0.001, float(owner_actor.call("_phase_duration")))
            effect["progress"] = clampf(progress, 0, 1)
            effect["at"] = (owner_actor.global_position + Vector2(effect["owner_offset"])).round()
        else:
            effect["age"] += delta
            if float(effect["age"]) >= float(effect["duration"]):
                _effects.remove_at(i)
    for collection: Array in [_ghosts, _warnings]:
        for i: int in range(collection.size() - 1, -1, -1):
            collection[i]["age"] += delta
            if float(collection[i]["age"]) >= float(collection[i]["duration"]):
                collection.remove_at(i)
    for i: int in range(_chips.size() - 1, -1, -1):
        _chips[i]["age"] += delta
        _chips[i]["at"] += _chips[i]["motion"] * delta
        _chips[i]["motion"] += Vector2(0, 180) * delta
        if float(_chips[i]["age"]) >= float(_chips[i]["duration"]):
            _chips.remove_at(i)
    _sample_player_trail()
    for i: int in range(_trails.size() - 1, -1, -1):
        if bool(_trails[i]["ended"]):
            _trails[i]["age"] += delta
            if float(_trails[i]["age"]) >= TRAIL_FADE:
                _trails.remove_at(i)
                if _current_trail > i:
                    _current_trail -= 1
    queue_redraw()

func _draw() -> void:
    for ghost: Dictionary in _ghosts:
        var t: float = float(ghost["age"]) / float(ghost["duration"])
        var at: Vector2 = Vector2(ghost["at"]) + Vector2(int(ghost["facing"]) * roundf(6 * t), 0)
        draw_set_transform(at, 0, Vector2(float(ghost["facing"]), 1))
        draw_texture_rect_region(ActorRenderer.silhouette_texture(), Rect2(-ActorRenderer.HERO_ANCHOR, ActorRenderer.HERO_SIZE), ghost["region"], Color(0.6, 1, 1, (1 - t) * 0.24))
        draw_set_transform(Vector2.ZERO)
    for warning: Dictionary in _warnings:
        var at: Vector2 = warning["at"]
        var t: float = float(warning["age"]) / float(warning["duration"])
        var gold := Color("ef8580") if warning["kind"] == "unblockable_charge" else Color("e9bb68")
        if warning["kind"] == "rain":
            for x: int in [-96, -48, 48, 96]:
                for y: int in range(133, 293, 16):
                    draw_rect(Rect2(at.x + x - 1, y, 2, 5), Color(0.91, 0.73, 0.4, 0.6))
                draw_line(Vector2(at.x + x - 9, 298), Vector2(at.x + x + 9, 298), gold, 2, false)
        else:
            draw_line(at + Vector2(-15, 8), at + Vector2(15, 8), gold, 1, false)
            draw_rect(Rect2(at + Vector2(-15, 11), Vector2(30 * t, 2)), gold)
            if warning["kind"] == "unblockable_charge":
                draw_line(at + Vector2(-5, -13), at + Vector2(5, -3), gold, 2, false)
                draw_line(at + Vector2(5, -13), at + Vector2(-5, -3), gold, 2, false)
            elif warning["kind"] == "armored_slash":
                draw_line(at + Vector2(-12, -13), at + Vector2(-12, -5), gold, 1, false)
                draw_line(at + Vector2(12, -13), at + Vector2(12, -5), gold, 1, false)
                for i: int in 3:
                    draw_rect(Rect2(at + Vector2(-7 + i * 6, -11), Vector2(3, 3)), Color("b08ae5"))
            else:
                draw_line(at + Vector2(0, -12), at + Vector2(0, -6), gold, 2, false)
                draw_rect(Rect2(at + Vector2(-1, -3), Vector2(2, 2)), gold)
    for trail: Dictionary in _trails:
        var points: Array = trail["points"]
        var fade: float = 1.0 - float(trail["age"]) / TRAIL_FADE if bool(trail["ended"]) else 1.0
        for i: int in range(1, points.size()):
            var ink := Color(0.68, 0.92, 0.91, fade * (float(i) / points.size()) * 0.7)
            draw_line(points[i - 1], points[i], ink, 2 if i > points.size() - 3 else 1, false)
    for effect: Dictionary in _effects:
        var at: Vector2 = effect["at"]
        var t: float = float(effect.get("progress", float(effect["age"]) / float(effect["duration"])))
        if effect["image"] != "":
            var size: int = effect["size"]
            var frame_count: int = int(effect.get("frames", 5))
            var frame: int = mini(frame_count - 1, int(t * frame_count))
            var tint := Color(1, 1, 1, 1.0 if t < 0.5 else (1 - t) * 2.0)
            if bool(effect["hostile"]):
                tint = Color(1.25, 0.85, 0.36, tint.a)
            draw_set_transform(at, 0, Vector2(float(effect["facing"]), 1))
            draw_texture_rect_region(_texture(effect["image"]), Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), Rect2(frame * size, 0, size, size), tint)
            draw_set_transform(Vector2.ZERO)
        elif effect["kind"] == "enemy_dash":
            var ink := Color(0.9, 0.7, 0.35, (1 - t) * 0.6)
            var facing: int = effect["facing"]
            for i: int in 3:
                var y: float = float(i - 1) * 7
                var length: float = 8 + (1 - t) * 14
                draw_line(at + Vector2(-facing * 8, y), at + Vector2(-facing * length, y), ink, 1, false)
        elif effect["kind"] == "parry_ready":
            var ink := Color(0.45, 0.94, 0.89, (1 - t) * 0.9)
            draw_line(at + Vector2(4, -8), at + Vector2(7, -5), ink, 1)
            draw_line(at + Vector2(7, -5), at + Vector2(7, 5), ink, 1)
            draw_line(at + Vector2(7, 5), at + Vector2(4, 8), ink, 1)
        else:
            var r: float = roundf(3 + t * 12)
            var ink := Color(0.45, 0.94, 0.89, (1 - t) * 0.8)
            draw_line(at + Vector2(-r, 0), at + Vector2(0, -r * 0.6), ink, 1)
            draw_line(at + Vector2(0, -r * 0.6), at + Vector2(r, 0), ink, 1)
    for chip: Dictionary in _chips:
        var at: Vector2 = Vector2(chip["at"]).round()
        var t: float = float(chip["age"]) / float(chip["duration"])
        var ink: Color = chip.get("color", Color("72c6c7") if bool(chip["cyan"]) else Color("bcaa7b"))
        ink.a = minf(1, (1 - t) * 1.5)
        var velocity: Vector2 = chip["motion"]
        if t < 0.45:
            draw_line(at, (at - velocity.normalized() * float(chip.get("trail_len", 4))).round(), ink, 1, false)
        draw_rect(Rect2(at, Vector2.ONE * int(chip["size"])), ink)
