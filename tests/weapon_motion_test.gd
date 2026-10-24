extends SceneTree
## Static animation and exact-contour contracts; no input playback or encounter simulation.
const Renderer = preload("res://presentation/actor_renderer.gd")
const Profile = preload("res://combat/attack_profile.gd")
const FX = preload("res://vfx/fx_layer.gd")
var passed: int = 0
var failed: int = 0
class Actor extends Node2D:
	var weapon: String = "light"
	var combo: int = 3
	var frame: int = 4
	var facing: int = 1
	var attack_phase: String = "active"
	var attack_serial: int = 1
	var attack_sweep_from: float = 0.45
	var attack_sweep_to: float = 0.55
	var attack_previous_position: Vector2 = Vector2(-12,0)
	var dead: bool = false
	var progress: float = .55
	func get_attack_progress() -> float: return progress
class Game extends Node:
	signal vfx_requested(kind: String, at: Vector2, direction: Vector2, power: float)
	signal warning_issued(kind: String, at: Vector2, duration: float)
	var player: Node2D
	var boss: Node2D
	var story_safe: bool = false
	var outcome: String = ""
	var _paused: bool = false
	var _overlay: String = ""
func check(value: bool, label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/feel_frames/manifest.json"))
	var hero: Dictionary = manifest["hero"]
	check(Renderer.HERO_SIZE == Vector2(144,128) and Renderer.HERO_ANCHOR == Vector2(66,108),"knight cell and feet anchor remain stable")
	var total_frames: int = int(hero["total_frames"])
	check(total_frames >= 155,"original 155 pixel cells remain while new flight clips may append")
	# Published three-weapon clip indices are a compatibility contract. New air
	# directions append, rather than shifting any attack, guard or locomotion row.
	var original_mapping: Dictionary = {
		"idle":[0,6],"run":[6,8],"jump":[14,3],"apex":[17,2],"fall":[19,3],"land":[22,3],"air_jump":[25,6],
		"crouch_in":[31,3],"crouch":[34,4],"crouch_out":[38,3],"crouch_walk":[41,6],"dash":[47,4],"hurt":[51,4],"dead":[55,4],
		"cut_1_windup":[59,4],"cut_1_attack":[63,8],"cut_1_recover":[71,4],"cut_2_windup":[75,4],"cut_2_attack":[79,8],"cut_2_recover":[87,4],
		"cut_3_windup":[91,4],"cut_3_attack":[95,8],"cut_3_recover":[103,4],"air_cut_1_windup":[107,4],"air_cut_1_attack":[111,8],"air_cut_1_recover":[119,4],
		"air_cut_2_windup":[123,4],"air_cut_2_attack":[127,8],"air_cut_2_recover":[135,4],"air_cut_3_windup":[139,4],"air_cut_3_attack":[143,8],"air_cut_3_recover":[151,4]
	}
	var mapping_preserved: bool = true
	for key: String in original_mapping:
		var descriptor: Dictionary = hero["states"].get(key,{})
		mapping_preserved = mapping_preserved and int(descriptor.get("start",-1)) == int(original_mapping[key][0]) and int(descriptor.get("count",-1)) == int(original_mapping[key][1])
	check(mapping_preserved,"all original locomotion and three-weapon state indices/counts stay unchanged")
	var air_mapping: Dictionary = {"air_dash_side":[155,4],"air_dash_up":[159,4],"air_dash_down":[163,4]}
	var air_clips_present: bool = true
	for key: String in air_mapping:
		var descriptor: Dictionary = hero["states"].get(key,{})
		air_clips_present = air_clips_present and int(descriptor.get("start",-1)) == int(air_mapping[key][0]) and int(descriptor.get("count",-1)) == int(air_mapping[key][1]) and int(descriptor.get("start",-1)) + int(descriptor.get("count",0)) <= total_frames
	check(air_clips_present,"side/up/down air dash clips append beyond the original weapon cells")
	var expected_size: Vector2i = Vector2i(8 * 144,ceili(float(total_frames)/8.0)*128)
	for wid: String in ["light","heavy","great"]:
		var atlas: Texture2D = load(Renderer.hero_sheet("res://presentation/feel_frames/hero_atlas.png",wid))
		var image: Image = atlas.get_image()
		check(image.get_size() == expected_size,wid+" atlas dimensions match its declared whole-frame count")
		var air_in_bounds: bool = true
		for key: String in air_mapping:
			for f: int in 4:
				var cell: Rect2 = Renderer.hero_region(key,f)
				air_in_bounds = air_in_bounds and Rect2(Vector2.ZERO,atlas.get_size()).encloses(cell)
				air_in_bounds = air_in_bounds and image.get_region(Rect2i(cell)).get_used_rect().has_area()
		check(air_in_bounds,wid+" directional air dash cells are mapped, in bounds and nonempty")
		var in_bounds: bool = true
		for combo: int in [1,2,3]:
			var descriptor: Dictionary = hero["states"]["cut_%d_attack" % combo]
			in_bounds = in_bounds and int(descriptor["count"]) == 8
			for f: int in 8:
				var cell: Rect2 = Renderer.hero_region("attack",f,combo,false)
				in_bounds = in_bounds and Rect2(Vector2.ZERO,atlas.get_size()).encloses(cell)
				in_bounds = in_bounds and image.get_region(Rect2i(cell)).get_used_rect().has_area()
		check(in_bounds,wid+" all ground attacks have eight nonempty mapped cells")
		var data: Dictionary = hero["weapons"][wid]
		check(data["weapon_tips"]["cut_3_attack"].size()==8 and data["pose_joints"]["cut_3_attack"].size()==8,wid+" blade and body landmarks are exported per frame")
	var light: Array = hero["weapons"]["light"]["weapon_tips"]["cut_1_attack"]
	var ylow: float = 1000; var yhigh: float = -1000
	for point: Array in light:
		ylow=minf(ylow,float(point[1]));yhigh=maxf(yhigh,float(point[1]))
	check(yhigh-ylow<=12,"light first strike remains a narrow point-led thrust")
	var heavy: Array = hero["weapons"]["heavy"]["weapon_tips"]["cut_1_attack"]
	check(float(heavy[0][1]) < -60 and float(heavy[7][1]) > -10,"heavy descending cut carries steel from overhead to floor")
	var great: Array = hero["weapons"]["great"]["weapon_tips"]["cut_3_attack"]
	var left: bool=false;var right: bool=false
	for point: Array in great:
		left = left or float(point[0]) < -50
		right = right or float(point[0]) > 50
	check(left and right,"greatsword steel has actual front and rear poses")
	var joints: Dictionary = hero["weapons"]["light"]["pose_joints"]
	var drill: Array = joints["cut_3_attack"]
	check(float(drill[3]["foot_f"][1])<0 and float(drill[4]["foot_b"][1])<0,"drill launches with knees tucked before its braced finish")
	check(drill[2]["foot_f"]!=drill[4]["foot_f"] and drill[2]["shoulder"]!=drill[4]["shoulder"],"drill re-articulates shoulder and legs rather than translating one pose")
	var air: Array = joints["air_cut_3_attack"]
	check(air[0]["foot_f"]!=drill[0]["foot_f"] and air[7]["foot_b"]!=drill[7]["foot_b"],"air finisher uses separate leg counterbalance")
	var arena := Game.new();root.add_child(arena)
	var actor := Actor.new();arena.add_child(actor);arena.player=actor
	var fx := FX.new();arena.add_child(fx);fx.setup(arena);fx.set_process(false)
	for wid: String in ["light","heavy","great"]:
		fx.clear_hostile();actor.weapon=wid;Profile.set_weapon(wid);actor.attack_serial+=1
		actor.attack_phase="active";actor.progress=.55
		fx.spawn("slash",Vector2.ZERO,Vector2.RIGHT,3)
		var shape: Dictionary={}
		for candidate: Dictionary in fx._shapes:
			if bool(candidate.get("profile",false)):shape=candidate
		check(not shape.is_empty() and str(shape.get("mode",""))==Profile.kind(3,wid),wid+" primary VFX follows its actual weapon mode")
		if shape.is_empty():continue
		check(shape["polygon"]==Profile.world_polygon(actor,.45,.55),wid+" primary contour is the exact current damage polygon")
		check(fx._shapes.size()==1,wid+" miss emits one primary stroke without fake shockwave rings")
		var previous: PackedVector2Array=shape["polygon"].duplicate()
		check(fx._sync_slash(shape) and shape["polygon"]==previous,wid+" local hold cannot advance the contour")
		actor.attack_phase="none"
		check(not fx._sync_slash(shape),wid+" cancellation removes the bound contour")
	Profile.set_weapon("light")
	arena.queue_free();await process_frame
	print("Weapon motion: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
