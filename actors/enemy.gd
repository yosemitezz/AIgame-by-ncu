extends CharacterBody2D
## Mobility balance: quicker room-local approach and re-entry; HP, damage, warning and shot counts unchanged.
## Six finite enemy casts. Root owns accepted damage/projectile collision, not these tells.
const PixelActor = preload("res://assets/art/pixel_actor.gd")
const KINDS: Array[String] = ["sentry","wisp","elite","lantern","jailer","bat"]
const CASTS: Dictionary = {
    "sentry":{"hp":3,"windup":0.52,"release":0.12,"recover":0.42,"reach":48.0,"speed":70.0,"cap":0},
    "wisp":{"hp":2,"windup":0.66,"release":0.36,"recover":0.45,"reach":0.0,"speed":52.0,"cap":6},
    "elite":{"hp":9,"windup":0.58,"release":0.20,"recover":0.48,"reach":72.0,"speed":108.0,"cap":8},
    "lantern":{"hp":4,"windup":0.72,"release":0.42,"recover":0.55,"reach":0.0,"speed":40.0,"cap":12},
    "jailer":{"hp":6,"windup":0.68,"release":0.12,"recover":0.62,"reach":92.0,"speed":52.0,"cap":0},
    "bat":{"hp":2,"windup":0.55,"release":0.38,"recover":0.60,"reach":0.0,"speed":82.0,"cap":6},
}
static var _lane_owner: WeakRef = null
var game: Node
var kind: String = "sentry"
var patrol_bounds: Rect2 = Rect2()
var health: int = 3
var max_health: int = 3
var dead: bool = false
var facing: int = -1
var animation_state: String = "idle"
var frame: int = 0
var reaction: String = ""
var hurt_flash: float = 0.0
var combat_freeze: float = 0.0
var attack_serial: int = 0
var cast_phase: String = "none"
var cast_progress: float = 0.0
var _home: Vector2
var _clock: float = 0.0
var _cooldown: float = 0.8
var _windup: float = 0.0
var _windup_total: float = 1.0
var _recovery: float = 0.0
var _release_elapsed: float = 0.0
var _release_total: float = 1.0
var _stagger: float = 0.0
var _stun: float = 0.0
var _hurt_flash: float = 0.0
var _hurt_elapsed: float = 0.0
var _death_time: float = 0.0
var _attack_facing: int = -1
var _attack_target: Vector2
var _shot: bool = true
var _melee_resolved: bool = false
var _melee_window: float = 0.0
var _layers: Array[Dictionary] = []
var _seed: WeakRef = null
var _lane_remaining: float = 0.0
var _last_state: String = ""
var _last_frame: int = -1
var _last_facing: int = 0

func configure(owner_game: Node, enemy_kind: String, at: Vector2) -> void:
    game = owner_game
    kind = enemy_kind if enemy_kind in KINDS else "sentry"
    position = at
    _home = at
    max_health = int(CASTS[kind]["hp"])
    health = max_health

func _ready() -> void:
    collision_layer = 4
    collision_mask = 1
    floor_snap_length = 5.0
    if _is_flying(): motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    var collider: CollisionShape2D = CollisionShape2D.new()
    var shape: RectangleShape2D = RectangleShape2D.new()
    shape.size = Vector2(20,30) if kind in ["elite","jailer"] else (Vector2(16,30) if kind == "lantern" else Vector2(14,20 if _is_flying() else 24))
    collider.shape = shape
    collider.position = Vector2(0,-shape.size.y*0.5)
    add_child(collider)
    add_to_group("enemies")
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _exit_tree() -> void:
    _clear_owned_hostiles()
    _release_lane()

func _is_flying() -> bool:
    return kind in ["wisp","bat"]

func set_impact_freeze(seconds: float) -> void:
    if is_instance_valid(game) and bool(game.story_safe):
        combat_freeze = 0.0
        return
    combat_freeze = maxf(combat_freeze,clampf(seconds,0.0,0.12))

func _director_paused() -> bool:
    return (is_inside_tree() and get_tree().paused) or (is_instance_valid(game) and game.get("_paused") == true)

func _physics_process(delta: float) -> void:
    if _director_paused(): return
    _tick_lane(delta)
    var story_rest: bool = is_instance_valid(game) and bool(game.story_safe)
    if story_rest:
        _cancel_cast(true)
        combat_freeze = 0.0
        _stagger = 0.0
    if combat_freeze > 0.0:
        combat_freeze = maxf(0.0,combat_freeze-delta)
        queue_redraw()
        return
    _clock += delta
    _hurt_flash = maxf(0.0,_hurt_flash-delta)
    hurt_flash = _hurt_flash
    modulate = Color(2.5,2.1,1.7,1) if hurt_flash > 0.065 else Color.WHITE
    _stagger = maxf(0.0,_stagger-delta)
    _stun = maxf(0.0,_stun-delta)
    if _stagger <= 0 and _stun <= 0: reaction = ""
    _cooldown = maxf(0.0,_cooldown-delta)
    if dead:
        _death_time += delta
        animation_state = "dead"
        frame = mini(3,int(_death_time*10.0))
        _publish_animation()
        queue_redraw()
        if _death_time > 0.36: queue_free()
        return
    if not is_instance_valid(game) or not is_instance_valid(game.player):
        _cancel_cast(true)
        return
    var target: Node2D = game.player
    var offset: Vector2 = target.global_position-global_position
    var safe: bool = story_rest or bool(target.dead) or not _target_in_room(target.global_position) or not _on_screen()
    if not _is_flying(): velocity.y = minf(velocity.y+900.0*delta,620.0)
    if safe:
        _cancel_cast(true)
        velocity.x = move_toward(velocity.x,0.0,1000.0*delta)
        if _is_flying(): velocity.y = 0.0
        animation_state = "idle"
    elif _stagger > 0.0:
        _cancel_cast(true)
        _hurt_elapsed += delta
        velocity.x = move_toward(velocity.x,0.0,(190.0 if kind == "elite" else 280.0)*delta)
        if _is_flying(): velocity.y = move_toward(velocity.y,0.0,160.0*delta)
        animation_state = "hurt"
    elif cast_phase != "none":
        velocity.x = move_toward(velocity.x,0.0,1200.0*delta)
        if _is_flying(): velocity.y = 0.0
        _advance_cast(delta)
    else:
        facing = 1 if offset.x > 0 else -1
        _update_motion(offset,delta)
    if patrol_bounds.has_area() and _stagger <= 0:
        if global_position.x <= patrol_bounds.position.x+7 and velocity.x < 0: velocity.x = 0.0
        if global_position.x >= patrol_bounds.end.x-7 and velocity.x > 0: velocity.x = 0.0
    move_and_slide()
    _sync_animation()
    if global_position.y > 720.0: _die()
    _publish_animation()
    queue_redraw()

func _target_in_room(at: Vector2) -> bool:
    if absf(at.y-_home.y) >= 120.0: return false
    if patrol_bounds.has_area() and not patrol_bounds.grow(24).has_point(at): return false
    if is_instance_valid(game):
        var level: Variant = game.get("level")
        if level is Node and level.has_method("room_at"):
            var own: Dictionary = level.room_at(_home)
            var other: Dictionary = level.room_at(at)
            if str(own.get("id","")) != str(other.get("id","")): return false
    return true

func _on_screen() -> bool:
    if not is_inside_tree(): return false
    var camera: Camera2D = get_viewport().get_camera_2d()
    if camera == null: return true
    var view: Vector2 = get_viewport_rect().size / camera.zoom
    return Rect2(camera.get_screen_center_position()-view*0.5,view).grow(96).has_point(global_position)

func _has_los(from: Vector2,to: Vector2) -> bool:
    if not is_inside_tree(): return false
    var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from,to,1)
    return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _attack_allowed() -> bool:
    if dead or not is_instance_valid(game) or bool(game.story_safe) or get_tree().paused or game.get("_paused") == true: return false
    if not is_instance_valid(game.player) or bool(game.player.dead): return false
    var outcome: Variant = game.get("outcome")
    if outcome is String and not outcome.is_empty(): return false
    var at: Vector2 = game.player.global_position
    return global_position.distance_to(at) <= 420.0 and _target_in_room(at) and _on_screen() and _has_los(global_position+Vector2(0,-16),at+Vector2(0,-14))

func _update_motion(offset: Vector2,delta: float) -> void:
    var ranged: bool = kind in ["wisp","lantern","bat"]
    var reach: float = float(CASTS[kind]["reach"])
    if _cooldown <= 0 and ((ranged and offset.length() >= (110.0 if kind == "bat" else 90.0)) or (not ranged and absf(offset.x) < reach-6 and absf(offset.y) < 34)):
        if _begin_attack(): return
    if _is_flying():
        var target_y: float = _home.y-12.0+sin(_clock*2.3)*10.0
        var direction: float = float(facing) if absf(offset.x) > 176 else -float(facing)*0.38
        velocity.x = move_toward(velocity.x,direction*float(CASTS[kind]["speed"]),150.0*delta)
        velocity.y = clampf((target_y-global_position.y)*3,-35,35)
    else:
        var direction: int = facing
        var move: bool = absf(offset.x) > (150.0 if ranged else reach*0.75) and absf(offset.x) < 340.0
        if ranged and absf(offset.x) < 110.0:
            direction = -facing
            move = true
        if move and is_on_floor() and not _floor_ahead(direction): move = false
        var speed: float = float(CASTS[kind]["speed"])
        velocity.x = move_toward(velocity.x,direction*speed if move else 0.0,850.0*delta)
        if kind == "elite" and is_on_floor() and offset.y < -32 and absf(offset.x) < 160: velocity.y = -280.0
    animation_state = "run" if absf(velocity.x) > 6 else "idle"

func _is_blocking_cast() -> bool:
    return kind in ["lantern","jailer","bat"] or (kind == "elite" and health*2 <= max_health)

func _claim_lane(duration: float) -> bool:
    if _director_paused(): return false
    var owner: Object = _lane_owner.get_ref() if _lane_owner != null else null
    if is_instance_valid(owner):
        if owner == self and _lane_remaining > 0: return false
        if owner != self and owner.is_inside_tree() and not owner.is_queued_for_deletion() and not owner.dead and owner.game == game and owner._lane_remaining > 0 and owner._on_screen() and (owner.cast_phase != "none" or owner._source_count() > 0): return false
        if owner != self: owner._cancel_cast(true)
    _lane_owner = weakref(self)
    _lane_remaining = minf(duration,3.8)
    return true

func _owns_lane() -> bool:
    return _lane_owner != null and _lane_owner.get_ref() == self

func _release_lane() -> void:
    if _owns_lane():
        _lane_owner = null
    _lane_remaining = 0.0

func _tick_lane(delta: float) -> void:
    # The lease belongs to active simulation time. Pause/menu wall time cannot
    # expire a live cast or erase its projectiles on the first resumed tick.
    if not _owns_lane() or _director_paused(): return
    _lane_remaining = maxf(0.0,_lane_remaining-delta)
    if _lane_remaining <= 0:
        _cancel_cast(true)
    elif cast_phase == "none" and _source_count() == 0:
        _release_lane()

func _source_count() -> int:
    var count: int = 0
    if not is_inside_tree(): return count
    for shot: Node in get_tree().get_nodes_in_group("projectiles"):
        if is_instance_valid(shot) and shot.get_meta("enemy_source_id",-1) == get_instance_id() and not bool(shot.get("friendly")): count += 1
    return count

func _clear_owned_hostiles() -> void:
    if not is_inside_tree(): return
    for shot: Node in get_tree().get_nodes_in_group("projectiles"):
        if is_instance_valid(shot) and shot.get_meta("enemy_source_id",-1) == get_instance_id() and not bool(shot.get("friendly")) and shot.has_method("clear"): shot.clear()

func _cancel_cast(clear_hostiles: bool = false) -> void:
    cast_phase = "none"
    cast_progress = 0.0
    _windup = 0.0
    _recovery = 0.0
    _melee_window = 0.0
    _melee_resolved = true
    _layers.clear()
    _seed = null
    _shot = true
    if clear_hostiles: _clear_owned_hostiles()
    _release_lane()

func _begin_attack() -> bool:
    if not _attack_allowed() or _stagger > 0: return false
    _windup_total = float(CASTS[kind]["windup"])
    _release_total = float(CASTS[kind]["release"])
    var lease: float = _windup_total+_release_total+2.4
    if _is_blocking_cast() and not _claim_lane(lease):
        _cooldown = maxf(_cooldown,0.16)
        return false
    attack_serial += 1
    _windup = _windup_total
    _cooldown = maxf(lease+0.25 if _is_blocking_cast() else 0.0,_windup_total+_release_total+float(CASTS[kind]["recover"])+0.48)
    _attack_facing = facing
    _attack_target = game.player.global_position+Vector2(0,-14)
    _shot = false
    _melee_resolved = false
    _layers.clear()
    cast_phase = "windup"
    cast_progress = 0.0
    if game.has_signal("warning_issued"): game.emit_signal("warning_issued","mob_"+kind,global_position+Vector2(facing*22,-16),_windup)
    game.emit_fx("mob_"+kind,global_position+Vector2(0,-24),Vector2(facing,0),_windup)
    return true

func _execute_attack() -> void:
    if _shot or not _attack_allowed():
        if not _shot: _cancel_cast(true)
        return
    _shot = true
    _windup = 0.0
    _release_elapsed = 0.0
    cast_phase = "release"
    cast_progress = 0.0
    _melee_window = 0.12 if kind in ["sentry","elite","jailer"] else 0.0
    if _melee_window > 0:
        game.emit_fx("enemy_slash",global_position+Vector2(_attack_facing*22,-17),Vector2(_attack_facing,0),1.0 if kind == "jailer" else (0.8 if kind == "elite" else 0.5))
        _check_melee_contact()
        if cast_phase == "none": return
    match kind:
        "wisp":
            _layers = [{"at":0.0,"angles":[0.0],"speed":130.0,"style":"wisp_seed"},{"at":0.28,"angles":[-24.0,24.0],"speed":110.0,"style":"wisp_seed"}]
        "lantern":
            _layers = [{"at":0.0,"angles":[-54.0,-28.0,28.0,54.0],"speed":130.0,"style":"lantern_fan"},{"at":0.34,"angles":[-60.0,-34.0,34.0,60.0],"speed":130.0,"style":"lantern_fan"}]
        "bat":
            _layers = [{"at":0.0,"angles":[0.0],"speed":75.0,"style":"bat_seed","head":true},{"at":0.30,"angles":[-32.0,-12.0,12.0,32.0],"speed":140.0,"style":"bat_bloom","bloom":true}]
        "elite":
            if health*2 <= max_health: _layers = [{"at":0.12,"angles":[-26.0,0.0,26.0],"speed":120.0,"style":"elite_rune"}]
    _advance_layers()

func _advance_cast(delta: float) -> void:
    if not _attack_allowed():
        _cancel_cast(true)
        return
    match cast_phase:
        "windup":
            _windup = maxf(0.0,_windup-delta)
            if _windup <= 0: _execute_attack()
        "release":
            _release_elapsed += delta
            _advance_layers()
            if _melee_window > 0:
                _check_melee_contact()
                _melee_window = maxf(0.0,_melee_window-delta)
            if cast_phase == "release" and _release_elapsed >= _release_total:
                cast_phase = "recover"
                _recovery = float(CASTS[kind]["recover"])
        "recover":
            _recovery = maxf(0.0,_recovery-delta)
            if _recovery <= 0:
                cast_phase = "none"
                _layers.clear()
                if _source_count() == 0: _release_lane()

func _advance_layers() -> void:
    # Pop BEFORE attempting a spawn: a capacity rejection still consumes this finite layer.
    while not _layers.is_empty() and float(_layers[0]["at"]) <= _release_elapsed+0.00001:
        var layer: Dictionary = _layers.pop_front()
        if not _attack_allowed():
            _cancel_cast(true)
            return
        var origin: Vector2 = global_position+Vector2(_attack_facing*8,-16)
        if bool(layer.get("bloom",false)):
            var seed: Object = _seed.get_ref() if _seed != null else null
            if not is_instance_valid(seed) or bool(seed.get("friendly")) or not seed.is_in_group("projectiles"): continue
            origin = seed.global_position
            seed.clear()
            _seed = null
            if origin.distance_to(game.player.global_position+Vector2(0,-13)) < 52: continue
        var aim: Vector2 = (_attack_target-origin).normalized()
        if aim.length_squared() < 0.5: aim = Vector2(_attack_facing,0)
        for angle: float in layer["angles"]:
            var shot: Node2D = _spawn_shot(origin,aim.rotated(deg_to_rad(angle))*float(layer["speed"]),str(layer["style"]))
            if bool(layer.get("head",false)) and is_instance_valid(shot): _seed = weakref(shot)

func _spawn_shot(at: Vector2,motion: Vector2,style: String) -> Node2D:
    if not _attack_allowed() or _source_count() >= int(CASTS[kind]["cap"]): return null
    var shot: Node2D = game.spawn_projectile(at,motion,false,style)
    if is_instance_valid(shot):
        shot.set_meta("enemy_source_id",get_instance_id())
        if shot.get("lifetime") != null: shot.set("lifetime",2.4)
    return shot

func _check_melee_contact() -> void:
    if _melee_resolved or not _attack_allowed(): return
    var player: Node2D = game.player
    var offset: Vector2 = player.global_position-global_position
    var reach: float = float(CASTS[kind]["reach"])
    if absf(offset.x) > reach or absf(offset.y) > 32 or offset.x*_attack_facing < -8: return
    _melee_resolved = true
    var blade_root: Vector2 = global_position+Vector2(_attack_facing*8,-17)
    var blade_tip: Vector2 = global_position+Vector2(_attack_facing*reach,-17)
    var guard: Vector2 = player.global_position+Vector2(int(player.facing)*18,-18)
    var contact: Vector2 = Geometry2D.get_closest_point_to_segment(guard,blade_root,blade_tip)
    if player.parry_success(self,contact,"melee",attack_serial):
        receive_hit(1,player.global_position)
        _stagger = maxf(_stagger,0.70 if kind == "jailer" else 0.55)
        _cooldown = 1.1
    else:
        game.damage_player(1,global_position)

func _floor_ahead(direction: int) -> bool:
    var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position+Vector2(direction*15,-4),global_position+Vector2(direction*15,20),1)
    return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _sync_animation() -> void:
    if animation_state == "hurt":
        frame = mini(3,int(_hurt_elapsed*14))
        return
    match cast_phase:
        "windup":
            animation_state = "windup"
            cast_progress = clampf(1.0-_windup/_windup_total,0,1)
        "release":
            animation_state = "attack"
            cast_progress = clampf(_release_elapsed/_release_total,0,1)
        "recover":
            animation_state = "recover"
            cast_progress = clampf(1.0-_recovery/float(CASTS[kind]["recover"]),0,1)
        _:
            cast_progress = 0.0
    frame = mini(3,int(cast_progress*4)) if cast_phase != "none" else int(_clock*(12.0 if animation_state == "run" else 7.0))%4

func _publish_animation() -> void:
    if animation_state == _last_state and frame == _last_frame and facing == _last_facing: return
    _last_state = animation_state
    _last_frame = frame
    _last_facing = facing
    if is_instance_valid(game) and game.has_signal("animation_event"): game.emit_signal("animation_event",self,animation_state,frame,facing)

func receive_hit(amount: int, origin: Vector2) -> void:
    if dead or amount <= 0 or _hurt_flash > 0.06 or (is_instance_valid(game) and bool(game.story_safe)):
        return
    _cancel_cast(true)
    var heavy: bool = amount >= 2
    health = maxi(0, health - amount)
    _hurt_flash = 0.15 if heavy else 0.12
    hurt_flash = _hurt_flash
    _hurt_elapsed = 0.0
    _stagger = maxf(_stagger, (0.30 if heavy else 0.18) if kind == "elite" else (0.36 if heavy else 0.23))
    _windup = 0.0
    _recovery = 0.0
    _cooldown = maxf(_cooldown, _stagger + 0.24)
    var impulse: float = (155.0 if heavy else 90.0) if kind == "elite" else (230.0 if heavy else 145.0)
    velocity.x = (1.0 if global_position.x >= origin.x else -1.0) * impulse
    velocity.y = -110.0 if heavy else -52.0
    modulate = Color(2.5, 2.1, 1.7, 1.0)
    animation_state = "hurt"
    frame = 0
    _publish_animation()
    if is_instance_valid(game):
        game.emit_fx("hit", global_position + Vector2(0.0, -18.0), (global_position - origin).normalized(), 1.35 if heavy else 0.75)
    if health <= 0:
        _die()

## Extra reaction on top of receive_hit: "knockback" shoves, "stun" leaves the enemy dizzy, "launch" throws it up.
## Elites resist: shorter stun, lower launch. Wisps drift instead of falling.
func react(kind: String, origin: Vector2) -> void:
    if dead or kind == "" or (is_instance_valid(game) and bool(game.story_safe)):
        return
    _cancel_cast(true)
    var away: float = 1.0 if global_position.x >= origin.x else -1.0
    var tough: float = 0.55 if kind_is_elite() else 1.0
    reaction = kind
    match kind:
        "knockback":
            velocity.x = away * 260.0 * tough
            _stagger = maxf(_stagger, 0.3)
        "stun":
            _stun = 1.0 * tough
            _stagger = maxf(_stagger, _stun)
            _cooldown = maxf(_cooldown, _stagger + 0.3)
            velocity.x = away * 40.0
            if is_instance_valid(game):
                game.emit_fx("stun", global_position + Vector2(0.0, -32.0 if kind_is_elite() else -28.0), Vector2.UP, 1.0)
        "launch":
            velocity = Vector2(away * 210.0 * tough, -330.0 * tough)
            _stagger = maxf(_stagger, 0.7 * tough)
            _cooldown = maxf(_cooldown, _stagger + 0.3)
            if not _is_flying() and is_instance_valid(game):
                game.emit_fx("launch", global_position + Vector2(0.0, -6.0), Vector2(away, -1.0), 1.0)
    animation_state = "hurt"
    _publish_animation()

func kind_is_elite() -> bool:
    return kind == "elite"

func _die() -> void:
    if dead:
        return
    _cancel_cast(true)
    dead = true
    animation_state = "dead"
    frame = 0
    _publish_animation()
    collision_layer = 0
    collision_mask = 0
    remove_from_group("enemies")
    if is_instance_valid(game):
        game.emit_fx("death", global_position + Vector2(0.0, -16.0), Vector2.UP, 1.4 if kind == "elite" else 0.8)
        game.on_enemy_defeated(self)

func _draw() -> void:
    PixelActor.paint(self, kind, animation_state, frame, facing)
    if _windup > 0.0:
        draw_rect(Rect2(-2.0, -41.0, 4.0, 8.0), Color("ffd77c"))
        draw_rect(Rect2(-2.0, -31.0, 4.0, 3.0), Color("fff1bd"))
    if _stun > 0.0 and not dead:
        # Dizzy halo: three small diamonds orbiting the head.
        for i: int in 3:
            var a: float = _clock * 7.0 + TAU * float(i) / 3.0
            var p: Vector2 = Vector2(cos(a) * 9.0, -36.0 + sin(a) * 3.0).round()
            draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)]), Color("fff1bd"))
    if health < max_health and not dead:
        draw_rect(Rect2(-14.0, -45.0, 28.0, 3.0), Color("161829"))
        draw_rect(Rect2(-14.0, -45.0, 28.0 * health / max_health, 3.0), Color("f07873"))
