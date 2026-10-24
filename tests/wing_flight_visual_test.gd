extends SceneTree
## Static rendering contract and immutable gameplay evidence, not input playback.
const Renderer = preload("res://presentation/actor_renderer.gd")
const Wings = preload("res://vfx/light_wings.gd")
const FX = preload("res://vfx/fx_layer.gd")
const CombatFX = preload("res://presentation/combat_vfx.gd")
const CONTRACT = "res://tests/fixtures/wing_flight_contract_7c536d1.json"
var passed: int = 0
var failed: int = 0
class Actor extends Node2D:
	var wing_amount: float=0.0
	var wing_flap: float=0.0
	var velocity: Vector2=Vector2.RIGHT*520.0
	var dash_timer: float=.17
	var dash_direction: Vector2=Vector2.RIGHT
	var airborne: bool=true
	var facing: int=1
	var frame: int=1
	var animation_state: String="dash"
	var weapon: String="light"
	var combo: int=1
	var dead: bool=false
	var invuln: float=0.0
	var attack_phase: String="none"
	var attack_serial: int=0
	var parry_phase: String="none"
	func is_on_floor() -> bool: return not airborne
class Game extends Node2D:
	signal vfx_requested(kind: String,at: Vector2,direction: Vector2,power: float)
	signal warning_issued(kind: String,at: Vector2,duration: float)
	var player: Node2D
	var boss: Node2D
	var story_safe: bool=false
	var outcome: String=""
	var _paused: bool=false
	var _overlay: String=""
func check(value: bool,label: String) -> void:
	if value: passed+=1
	else:
		failed+=1
		push_error("FAIL "+label)
func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	var hero: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://presentation/feel_frames/manifest.json"))["hero"]
	check(int(hero["total_frames"])==167,"three four-frame directional air clips append after155")
	check(Vector2(float(hero["canvas"][0]),float(hero["canvas"][1]))==Vector2(144,128) and Vector2(float(hero["anchor"][0]),float(hero["anchor"][1]))==Vector2(66,108),"native144x128cell and66,108feet anchor preserved")
	for name: String in contract["old_states"]:
		check(hero["states"][name]==contract["old_states"][name],"original index and count preserved: "+name)
	var suffixes: Dictionary={"light":"","heavy":"_heavy","great":"_great"}
	for wid: String in ["light","heavy","great"]:
		for variant: String in ["atlas","flash","silhouette"]:
			var image:=Image.new()
			image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://presentation/feel_frames/hero_%s%s.png" % [variant,suffixes[wid]]))
			image.convert(Image.FORMAT_RGBA8)
			check(image.get_size()==Vector2i(1152,2688),wid+" "+variant+" 167-cell dimensions")
			var pixels:=PackedByteArray()
			for name: String in contract["protected_states"]:
				var entry: Dictionary=contract["old_states"][name]
				for index: int in range(int(entry["start"]),int(entry["start"])+int(entry["count"])):
					pixels.append_array(image.get_region(Rect2i((index%8)*144,(index/8)*128,144,128)).get_data())
			check(digest(pixels)==str(contract["weapons"][wid]["pixel_sha256"][variant]),wid+" "+variant+" all141 protected cells byte-exact")
		check(hero["weapons"][wid]["weapon_tips"]==contract["weapons"][wid]["weapon_tips"],wid+" every ground/air attack tip preserved")
		check(hero["weapons"][wid]["pose_joints"]==contract["weapons"][wid]["pose_joints"],wid+" every ground/air attack joint preserved")
		var flight: Dictionary=hero["weapons"][wid]["flight_pose_joints"]
		var upright: bool=true
		var attached: bool=true
		for key: String in flight:
			for pose: Dictionary in flight[key]:
				upright=upright and float(pose["rotation_degrees"])==0.0 and float(pose["head"][1])<float(pose["hip"][1])-12.0
				attached=attached and Vector2(float(pose["wing_root"][0]),float(pose["wing_root"][1])).distance_to(Vector2(float(pose["shoulder"][0]),float(pose["shoulder"][1])))<6.0
		check(upright,wid+" every airborne flight pose keeps head above hip without somersault")
		check(attached,wid+" wing attachment follows every actual shoulder")
	for rel: String in contract["parry_files"]:
		check(FileAccess.get_sha256("res://"+rel)==str(contract["parry_files"][rel]),"parry pixels unchanged: "+rel)
	for rel: String in contract["runtime_files"]:
		check(FileAccess.get_file_as_string("res://"+rel).replace("\r\n","\n").sha256_text()==str(contract["runtime_files"][rel]),"gameplay source unchanged (canonical LF): "+rel)
	var game:=Game.new();root.add_child(game)
	var actor:=Actor.new();game.add_child(actor);game.player=actor
	var wings:=Wings.new();actor.add_child(wings);wings.set_process(false)
	var before: Array=[actor.wing_amount,actor.wing_flap,actor.velocity,actor.dash_timer,actor.dash_direction]
	var state: Dictionary=Wings.presentation_state(actor)
	check(float(state["open"])>=.9 and actor.wing_amount==0.0,"first airborne dash shows wings without inventing an air jump")
	wings._process(.016)
	check(before==[actor.wing_amount,actor.wing_flap,actor.velocity,actor.dash_timer,actor.dash_direction],"wings never mutate physics/dodge/wing gameplay fields")
	var directions: Dictionary={"air_dash_side":Vector2.RIGHT,"air_dash_up":Vector2.UP,"air_dash_down":Vector2.DOWN}
	for key: String in directions:
		actor.dash_direction=directions[key]
		var entry: Dictionary=hero["states"][key]
		var index: int=int(entry["start"])+actor.frame
		var expected:=Rect2(Vector2(index%8,index/8)*Vector2(144,128),Vector2(144,128))
		check(Renderer.hero_region_for(actor,"dash",actor.frame)==expected,"runtime direction chooses "+key)
		var anchor: Vector2=Renderer.wing_anchor(actor)
		var point: Array=hero["weapons"]["light"]["flight_pose_joints"][key][actor.frame]["wing_root"]
		check(anchor==Vector2(float(point[0]),float(point[1])),"wing root matches "+key+" frame")
	actor.airborne=false
	check(Renderer.hero_region_for(actor,"dash",1)==Renderer.hero_region("dash",1),"ground dash retains original cell")
	check(float(Wings.presentation_state(actor)["open"])==0.0,"ground dash cannot force wings open")
	actor.airborne=true;actor.dash_timer=0.0;actor.wing_amount=.4
	check(is_equal_approx(float(Wings.presentation_state(actor)["open"]),.4),"outside dash the original gradual landing fold amount is preserved")
	actor.wing_amount=0.0;wings._process(.2)
	check(wings._dash_tail==0.0,"exhaust fully expires within100ms")
	actor.dead=true
	check(float(Wings.presentation_state(actor)["open"])==0.0,"dead hero has no forced flight wings")
	actor.dead=false;actor.dash_timer=.17;actor.dash_direction=Vector2.UP;actor.animation_state="dash"
	var fx:=FX.new();game.add_child(fx);fx.setup(game);fx.set_process(false)
	fx._ghost(actor,"hero",Color.WHITE,.5,.15)
	check(fx._ghosts.size()==1 and fx._ghosts[0].dash_direction==Vector2.UP,"ghost snapshots actual upward dash direction")
	actor.dash_direction=Vector2.DOWN
	if not fx._ghosts.is_empty():
		var ghost: Node2D=fx._ghosts[0]
		check(Renderer.hero_region_for(ghost,ghost.state,ghost.frame_index)==Renderer.hero_region("dash",1,1,true,Vector2.UP),"afterimage retains launch pose when live actor changes direction")
	var crisp:=CombatFX.new();game.add_child(crisp);crisp.configure(game);crisp.set_process(false)
	crisp._snapshot_ghost()
	check(not crisp._ghosts.is_empty() and crisp._ghosts[0]["region"]==Renderer.hero_region("dash",1,1,true,Vector2.DOWN),"pixel afterimage records its own down-flight region")
	actor.animation_state="attack";actor.combo=3;actor.frame=3
	var attack_pose: Dictionary=hero["weapons"]["light"]["pose_joints"]["air_cut_3_attack"][3]
	var shoulder: Array=attack_pose["shoulder"]
	check(Renderer.wing_anchor(actor).distance_to(Vector2(float(shoulder[0])-3.36,float(shoulder[1])+2.52))<.01,"air attack transitions keep wing root on existing shoulder landmarks")
	check(Engine.time_scale==1.0,"presentation never changes the music time scale")
	game.queue_free();await process_frame
	print("Wing flight visual: %d passed, %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
