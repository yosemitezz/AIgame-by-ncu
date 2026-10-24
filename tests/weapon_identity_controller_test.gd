extends SceneTree
## Bounded controller/geometry contract, not a playthrough or an aesthetic verdict.
const Player = preload("res://actors/player.gd")
const Profile = preload("res://combat/attack_profile.gd")
const Query = preload("res://combat/melee_query.gd")
var passed: int = 0
var failed: int = 0
var metrics: Dictionary = {}

class Arena extends Node2D:
	var story_safe: bool = false
	var _paused: bool = false
	var player: CharacterBody2D
	var releases: Array[int] = []
	var queries: int = 0
	func emit_fx(_kind: String, _at: Vector2, _dir: Vector2, _power: float) -> void: pass
	func hero_attack(_actor: Node2D, _damage: int, _reach: float, _combo: int) -> void: queries += 1
	func spawn_sword_wave(_actor: Node2D, serial: int) -> void: releases.append(serial)

class Dummy extends Node2D:
	var dead: bool = false
	var health: int = 100

func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)

func _initialize() -> void: call_deferred("run")

func wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.position = at
	body.add_child(collider)
	body.collision_layer = 1
	return body

func finish(player: CharacterBody2D, step: float = 1.0/120.0) -> void:
	for _i: int in 400:
		if player.attack_phase == "none": break
		player._advance_attack(step)

func select(player: CharacterBody2D, id: String, step: int = 1) -> void:
	player._cancel_attack()
	player.combat_freeze = 0.0
	player._hurt_lock = 0.0
	player.set_weapon(id)
	player.combo = step - 1
	player._combo_grace = 0.1 if step > 1 else 0.0
	player._start_attack()

func run() -> void:
	for action: String in ["move_left","move_right","climb_up","climb_down","attack","jump","dash","parry"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var arena := Arena.new()
	root.add_child(arena)
	var player: CharacterBody2D = Player.new()
	arena.player = player
	player.configure(arena)
	arena.add_child(player)
	player.set_physics_process(false)
	await process_frame
	check(Profile.kind(1,"light") == "thrust" and Profile.kind(3,"light") == "thrust", "light has axial thrust geometry")
	check(Profile.kind(1,"heavy") == "arc" and Profile.kind(3,"heavy") == "arc", "heavy has true cleave geometry")
	check(Profile.kind(1,"great") == "spin" and Profile.kind(3,"great") == "spin", "two-handed sword has around-body geometry")
	for wid: String in ["light","heavy","great"]:
		for combo: int in [1,2,3]:
			check(Profile.sweep_polygon(combo,0.0,0.24,wid).is_empty(), "%s%d anticipation never damages" % [wid,combo])
			check(int(Profile.profile(combo,wid).get("active_frames",0)) == 8, "%s%d has eight active poses" % [wid,combo])
	var front := Dummy.new()
	var behind := Dummy.new()
	var above := Dummy.new()
	arena.add_child(front); arena.add_child(behind); arena.add_child(above)
	front.position = Vector2(100,0); behind.position = Vector2(-100,0); above.position = Vector2(100,-90)
	for wid: String in ["light","heavy","great"]:
		player._cancel_attack(); player.set_weapon(wid)
		player.combo = 1; player.attack_phase = "active"; player.facing = 1
		var hits: Array[Node2D] = Query.collect(player,[front,behind,above],0.25,1.0,0)
		check(hits.has(front), wid+" reaches a front target")
		check(hits.has(behind) == (wid == "great"), wid+" correct front/back boundary")
		if wid == "light": check(not hits.has(above), "thrust does not inherit a broad overhead arc")
	# A full circumference has no center-to-edge overlap/self-crossing spike.
	var full: PackedVector2Array = Profile.sweep_polygon(1,0.25,1.0,"great")
	check(full.size() > 100 and Geometry2D.is_point_in_polygon(Profile.origin(),full), "full spin polygon includes center without crossing")
	player._cancel_attack(); player.set_weapon("light"); player.combo=3; player.attack_phase="active"
	player.position = Vector2(200,0); player.attack_previous_position = Vector2.ZERO
	front.position = Vector2(80,0)
	check(Query.collect(player,[front],0.4,0.6,0).has(front), "drill swept path hits a target already crossed this physics step")
	behind.position = Vector2(-20,0)
	check(not Query.collect(player,[behind],0.4,0.6,0).has(behind), "drill never reaches behind the prior start")
	player.position = Vector2.ZERO; player.attack_previous_position=Vector2.INF
	var barrier: StaticBody2D = wall(Vector2(50,-80),Vector2(12,200))
	arena.add_child(barrier)
	await physics_frame; await physics_frame
	front.position=Vector2(100,0)
	check(Query.collect(player,[front],0.25,1.0,1).is_empty(), "thrust cannot hit through a real solid wall")
	player._cancel_attack(); player.set_weapon("great"); player.combo=1; player.attack_phase="active"
	check(Query.collect(player,[front],0.25,1.0,1).is_empty(), "circular sweep cannot hit through a real solid wall")
	barrier.queue_free(); await process_frame; await physics_frame
	# Only the heavy third hit releases a wave, and phase overrun cannot duplicate it.
	for wid: String in ["light","heavy","great"]:
		for combo: int in [1,2,3]:
			arena.releases.clear(); select(player,wid,combo); finish(player,0.8)
			check(arena.releases.size() == (1 if wid=="heavy" and combo==3 else 0), "%s%d wave release count" % [wid,combo])
	arena.releases.clear(); select(player,"heavy",3)
	player._advance_attack(Profile.duration(3,"windup")+Profile.duration(3,"active")*0.24)
	check(arena.releases.is_empty(), "heavy wave waits until blade contact starts")
	player._cancel_attack(); player._advance_attack(1.0)
	check(arena.releases.is_empty(), "cancelled windup never spawns a late wave")
	for fps: int in [30,60,120]:
		arena.releases.clear(); select(player,"heavy",3); finish(player,1.0/float(fps))
		check(arena.releases.size()==1, "heavy wave remains once at %dHz" % fps)
	select(player,"light",3)
	player._advance_attack(Profile.duration(3,"windup"))
	var lunge: float = player._lunge_timer
	player.confirm_attack_hit()
	check(player._lunge_timer==lunge and player._recoil_time==0.0, "drill confirm retains forward drive without reverse recoil")
	player.queued_attack=true; player.set_impact_freeze(0.04)
	check(player.queued_attack, "attack input remains buffered during local hit stop")
	check(not player.set_weapon("great") and player.weapon=="light" and player._weapon_request=="great", "direct sword switch is deferred until active attack ends")
	player.combat_freeze=0.0; finish(player)
	player._apply_weapon_request(false)
	check(player.weapon=="great", "deferred switch applies after the swing")
	select(player,"light",2)
	player.queued_attack=true
	player.set_weapon("heavy")
	finish(player)
	player._apply_weapon_request(false)
	arena.releases.clear()
	check(player.weapon=="heavy" and player.combo==0 and player.queued_attack, "weapon change preserves buffered intent but resets cross-weapon combo")
	player._start_attack()
	check(player.combo==1 and player.weapon=="heavy", "light second hit cannot skip straight to the heavy finisher")
	finish(player)
	check(arena.releases.is_empty(), "newly equipped heavy starts first cut without a free wave")
	select(player,"light",3)
	player._advance_attack(Profile.duration(3,"windup"))
	player._phase_elapsed=0.6*Profile.duration(3,"active"); player._set_animation("attack",0)
	check(player.frame==4, "controller actually exposes the new eight active frames")
	player.invuln=0; player.receive_hit(1,Vector2(-20,0))
	check(player.attack_phase=="none" and not player.attack_previous_position.is_finite() and player._lunge_timer==0.0, "damage closes drill movement and pending sweep")
	player.revive(Vector2.ZERO)
	check(not player._wave_released and player.attack_phase=="none", "revive clears wave release state")
	# Real movement on physical floor: ground drill, wall stop, air variant, cliff stop.
	var floor: StaticBody2D = wall(Vector2(0,10),Vector2(1200,20))
	arena.add_child(floor)
	await physics_frame; await physics_frame
	player._weapon_request=""; player._cancel_attack(); player.invuln=0.0; player.velocity=Vector2.ZERO; player.position=Vector2.ZERO
	for _i: int in 3:
		await physics_frame; player._physics_process(1.0/60.0)
	select(player,"light",3)
	var grounded: bool = player.is_on_floor()
	var x0: float = player.position.x
	for _i: int in 28:
		await physics_frame; player._physics_process(1.0/60.0)
	var travel: float = player.position.x-x0
	metrics["ground_drill_px_at_60hz"] = travel
	check(grounded and travel>=140.0 and travel<=190.0, "ground drill travels 140-190px through physics (%.2f)" % travel)
	check(is_zero_approx(player.invuln) and player.dash_timer<=0.0, "drill grants no dodge/infinite immunity")
	player.revive(Vector2.ZERO); player.invuln=0
	barrier=wall(Vector2(100,-50),Vector2(10,100)); arena.add_child(barrier)
	await physics_frame; await physics_frame
	for _i: int in 3: player._physics_process(1.0/60.0); await physics_frame
	select(player,"light",3)
	for _i: int in 35: player._physics_process(1.0/60.0); await physics_frame
	metrics["wall_stop_x"] = player.position.x
	check(player.position.x<89.0, "drill stops in front of a real wall (x%.2f)" % player.position.x)
	barrier.queue_free(); floor.queue_free(); await process_frame; await physics_frame
	floor=wall(Vector2(-170,10),Vector2(500,20)); arena.add_child(floor)
	await physics_frame; await physics_frame
	player.revive(Vector2.ZERO); player.invuln=0
	for _i: int in 3: player._physics_process(1.0/60.0); await physics_frame
	select(player,"light",3)
	for _i: int in 35: player._physics_process(1.0/60.0); await physics_frame
	metrics["pit_stop"] = [player.position.x,player.position.y]
	check(player.position.x<72.0 and player.position.y<2.0, "ground drill stops before a pit without dragging the hero off (%.2f,%.2f)" % [player.position.x,player.position.y])
	floor.queue_free(); await process_frame; await physics_frame
	player.revive(Vector2(0,-200)); player.invuln=0
	await physics_frame; player._physics_process(1.0/60.0)
	select(player,"light",3); x0=player.position.x; var y0: float=player.position.y
	for _i: int in 28: player._physics_process(1.0/60.0); await physics_frame
	travel=player.position.x-x0
	metrics["air_drill_px_at_60hz"] = travel
	metrics["air_fall_px"] = player.position.y-y0
	check(travel>=115.0 and travel<175.0 and player.position.y>y0, "air drill retains gravity and reduced travel (%.2f)" % travel)
	check(Engine.time_scale==1.0, "controller never changes the music/global time scale")
	Profile.set_weapon("light"); remove_meta("bellkeep_weapon") if has_meta("bellkeep_weapon") else null
	arena.queue_free(); await process_frame
	metrics["passed"] = passed; metrics["failed"] = failed
	var evidence: FileAccess = FileAccess.open("res://artifacts/weapon-identity-controller.json",FileAccess.WRITE)
	if evidence != null: evidence.store_string(JSON.stringify(metrics,"  "))
	print("Weapon identity controller: %d passed, %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
