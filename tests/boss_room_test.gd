extends SceneTree
const Room = preload("res://levels/boss_room.gd")
const Overlay = preload("res://ui/calibration_overlay.gd")

class MusicProbe extends Node:
    var running: bool = false
    var full: bool = true
    var now: float = 0.0
    var generation: int = 1
    var groups: Array[Dictionary] = []
    var timeline: Dictionary = {"offset_ms": 245.0, "music_volume_db": -8.0}
    var _dummy: bool = true
    var _audio: AudioStreamPlayer
    func is_full_song() -> bool: return full
    func get_chart_time() -> float: return now
    func get_transport_generation() -> int: return generation
    func get_heavy_groups() -> Array[Dictionary]: return groups.duplicate(true)

class GameProbe extends Node:
    var player: Node2D
    var music: Node
    var story_safe: bool = false

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
    call_deferred("run")

func check(value: bool, label: String) -> void:
    if value:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func make_room() -> Dictionary:
    var game := GameProbe.new()
    game.player = Node2D.new()
    game.add_child(game.player)
    game.music = MusicProbe.new()
    game.add_child(game.music)
    root.add_child(game)
    var room := Room.new()
    root.add_child(room)
    room.setup(game)
    return {"game": game, "music": game.music, "room": room}

func run() -> void:
    var fixture: Dictionary = make_room()
    var game: GameProbe = fixture["game"]
    var music: MusicProbe = fixture["music"]
    var room: Node2D = fixture["room"]
    check(room.active, "setup activates the room without starting calibration")
    check(not room.calibrating and not room.battle_running, "setup never starts a calibration or battle")
    check(Room.SPAWN == Vector2(2706, 300) and Room.BOSS_POSITION == Vector2(2990, 300), "spawn and boss anchors use the chamber baseline")
    check(Room.platform_layer_y(0) == 0.0 and Room.platform_layer_y(1) == 150.0 and Room.platform_layer_y(2) == 300.0 and Room.platform_layer_y(3) == 450.0 and Room.platform_layer_y(4) == 600.0, "five layer centres are 0/150/300/450/600")
    var spec: Dictionary = room.get_room_spec()
    check(spec["id"] == "boss" and spec["title"] == "THE HOLLOW BELFRY", "room spec keeps the Boss identity")
    check(spec["spawn"] == Room.SPAWN and spec["checkpoint"] == Room.SPAWN and spec["portal_at"] == Room.SPAWN, "spawn, checkpoint and portal share the entry anchor")
    check(spec["boss_spawn"] == Room.BOSS_POSITION and spec["fall_limit"] == 720.0, "boss anchor and fall limit are room-specific")
    check(spec["bounds"] == Room.WORLD_BOUNDS and spec["platforms"].is_empty(), "legacy solid platforms are gone from the spec")
    check(spec["shard_indices"] == [11], "the old chamber shard stays collectable")
    check(room.get_map_bounds(Vector2(3000, 200)) == Rect2(2580, -120, 840, 640), "map window follows the player")
    check(room.room_at(Vector2(-9999, -9999))["title"] == "THE HOLLOW BELFRY", "room record is unconditional in the infinite room")
    check(room.climb_at(Vector2.ZERO).is_empty() and not room.water_at(Vector2.ZERO) and room.portal_at(Vector2.ZERO).is_empty(), "traversal queries stay inert")
    check(room.interaction_hint(Vector2.ZERO) == "" and not room.try_interact(Vector2.ZERO) and room.get_opened_ids().is_empty(), "interaction queries stay inert")
    check(not room.has_method("get_attack_bounds"), "Boss attack arena is not overridden by the room")

    game.player.position = Vector2(0, 300)
    room._update_platforms()
    check(room._platforms.size() == 45, "nine cells per layer surround the player")
    var platforms_ok: bool = true
    var y_values: Dictionary = {}
    for body: StaticBody2D in room._platforms.values():
        platforms_ok = platforms_ok and body.collision_layer == 1 and body.collision_mask == 0
        y_values[body.position.y] = true
        var shape_node: CollisionShape2D = body.get_child(0) as CollisionShape2D
        platforms_ok = platforms_ok and shape_node != null and shape_node.one_way_collision
        platforms_ok = platforms_ok and is_equal_approx(shape_node.one_way_collision_margin, 4.0)
    check(platforms_ok, "every cell is a layer-1 mask-0 one-way body")
    check(y_values.keys().size() == 5, "bodies exist on exactly five layers")
    check(room._platforms["2:0"].position.x == 100.0, "cell x is index times spacing plus half width")

    game.player.position = Vector2(2000, 300)
    room._update_platforms()
    check(room._platforms.size() == 45 and not room._platforms.has("0:-4") and room._platforms.has("0:6"), "cells outside the surround are removed")
    check(room._platforms["2:6"].position.x == 1300.0, "window re-centres on the new player x")

    if not InputMap.has_action("climb_down"):
        InputMap.add_action("climb_down")
    Input.action_press("climb_down")
    room._update_platforms()
    var all_disabled: bool = true
    for body: StaticBody2D in room._platforms.values():
        all_disabled = all_disabled and (body.get_child(0) as CollisionShape2D).disabled
    Input.action_release("climb_down")
    check(all_disabled, "drop-through disables every platform shape")
    room._update_platforms()
    var all_enabled: bool = true
    for body: StaticBody2D in room._platforms.values():
        all_enabled = all_enabled and not (body.get_child(0) as CollisionShape2D).disabled
    check(all_enabled, "releasing drop-through restores every platform shape")

    music.running = true
    music.now = 0.0
    music.generation = 1
    music.groups = [{"time": 1.0}, {"time": 2.0}, {"time": 3.0}]
    var requests: Array[float] = []
    var clears: Array[int] = [0]
    room.heavy_clash_requested.connect(func(at: float) -> void: requests.append(at))
    room.heavy_history_cleared.connect(func() -> void: clears[0] += 1)
    room.begin_battle(null)
    room._process_heavy_groups()
    check(requests.is_empty(), "future groups do not fire early")
    music.now = 1.0
    room._process_heavy_groups()
    room._process_heavy_groups()
    check(requests == [1.0], "each group is emitted once")
    music.generation = 2
    music.now = 1.5
    room._process_heavy_groups()
    check(clears[0] == 1, "generation change clears history")
    check(requests == [1.0], "historical group from the previous epoch is skipped")
    music.now = 2.0
    room._process_heavy_groups()
    check(requests == [1.0, 2.0], "new epoch emits its first due group")
    game.story_safe = true
    music.now = 3.0
    room._process_heavy_groups()
    check(requests == [1.0, 2.0], "rest advances the cursor without emitting")
    game.story_safe = false
    room._process_heavy_groups()
    check(requests == [1.0, 2.0], "leaving rest does not replay a backlog")
    music.now = 0.5
    room._process_heavy_groups()
    check(clears[0] == 2, "backward jump also clears history")

    music.full = false
    var emitted: Array[float] = []
    room.calibration_complete.connect(func(value: float) -> void: emitted.append(value))
    room.start_room_entry()
    check(emitted.size() == 1 and not room.calibrating, "non-full-song skips calibration synchronously")
    music.full = true
    music.groups = [{"time": 40.74}, {"time": 41.18}, {"time": 41.62}, {"time": 42.06}, {"time": 42.50}]
    room.start_room_entry()
    check(emitted.size() == 2 and not room.calibrating, "Dummy audio skips calibration synchronously")

    var overlay: Control = Overlay.new()
    root.add_child(overlay)
    await process_frame
    var strings: Array[String] = ["节拍校准", "听到重鼓时按任意键；每轮重新校准。", "重鼓  %d / %d", "校准完成：%.0f ms", "没有采足 5 下，马上重新播放。", "已跳过校准。"]
    var glyphs_ok: bool = true
    for text: String in strings:
        for index: int in text.length():
            var codepoint: int = text.unicode_at(index)
            if codepoint == 32:
                continue
            glyphs_ok = glyphs_ok and overlay._font.has_char(codepoint)
    check(glyphs_ok, "overlay text is fully covered by the pixel font")

    game.queue_free()
    room.queue_free()
    overlay.queue_free()
    await process_frame
    print("Boss room: %d passed, %d failed" % [passed, failed])
    quit(1 if failed else 0)
