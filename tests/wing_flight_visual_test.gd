extends SceneTree
## Static rendering contract and immutable gameplay evidence, not input playback.
const Renderer = preload("res://presentation/actor_renderer.gd")
const Wings = preload("res://vfx/light_wings.gd")
const FX = preload("res://vfx/fx_layer.gd")
const CombatFX = preload("res://presentation/combat_vfx.gd")
const Motion = preload("res://vfx/motion_blur.gd")
const CONTRACT = "res://tests/fixtures/wing_flight_contract_7c536d1.json"
var passed: int = 0
var failed: int = 0
class Actor extends Node2D:
	var game: Node
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
	var room_id: String="dungeon"
	var speed_effects_level: int=1
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
	var designs: Dictionary={"light":"rapier","heavy":"iron_slab","great":"long_crossblade"}
	var steel_colors: Array[Color]=[Color("ffffff"),Color("c3cfdc"),Color("8d9bab"),Color("f0f6fb"),Color("b9c6d4"),Color("8c9db0"),Color("6f7f93")]
	for wid: String in ["light","heavy","great"]:
		var color_image:=Image.new()
		color_image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://presentation/feel_frames/hero_atlas%s.png" % suffixes[wid]))
		for variant: String in ["atlas","flash","silhouette"]:
			var image:=Image.new()
			image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://presentation/feel_frames/hero_%s%s.png" % [variant,suffixes[wid]]))
			check(image.get_size()==Vector2i(1152,2688),wid+" "+variant+" retains167 native cells")
			check(image.get_used_rect().has_area(),wid+" "+variant+" contains actual new weapon drawing")
		var steel_tips: bool=true
		var missing_steel: Array[String]=[]
		var mapped_attacks: bool=true
		for air: bool in [false,true]:
			for combo: int in [1,2,3]:
				var key: String=("air_" if air else "")+"cut_%d_attack" % combo
				var tips: Array=hero["weapons"][wid]["weapon_tips"][key]
				var joints: Array=hero["weapons"][wid]["pose_joints"][key]
				mapped_attacks=mapped_attacks and tips.size()==8 and joints.size()==8
				for frame: int in 8:
					var region: Rect2i=Rect2i(Renderer.hero_region("attack",frame,combo,air))
					var point: Vector2i=Vector2i((Renderer.weapon_tip_local(combo,frame,air,wid)+Renderer.HERO_ANCHOR).round())
					var found: bool=false
					for x: int in range(-3,4):
						for y: int in range(-3,4):
							var at: Vector2i=point+Vector2i(x,y)
							if Rect2i(Vector2i.ZERO,Vector2i(144,128)).has_point(at):
								var pixel: Color=color_image.get_pixelv(region.position+at)
								if pixel.a==1.0 and steel_colors.has(pixel):found=true
					steel_tips=steel_tips and found
					if not found:missing_steel.append(key+":"+str(frame))
		check(mapped_attacks,wid+" new ground/air attack landmarks retain all eight active cells")
		check(steel_tips,wid+" actual exported attack tips touch newly drawn steel"+("; missing "+",".join(missing_steel) if not missing_steel.is_empty() else ""))
		check(str(hero["weapons"][wid]["weapon_design"])==str(designs[wid]),wid+" has its own newly constructed weapon silhouette")
		var flight: Dictionary=hero["weapons"][wid]["flight_pose_joints"]
		var upright: bool=true
		var attached: bool=true
		var rear_carry: bool=true
		for key: String in flight:
			for pose: Dictionary in flight[key]:
				upright=upright and float(pose["rotation_degrees"])==0.0 and float(pose["head"][1])<float(pose["hip"][1])-12.0
				attached=attached and Vector2(float(pose["wing_root"][0]),float(pose["wing_root"][1])).distance_to(Vector2(float(pose["shoulder"][0]),float(pose["shoulder"][1])))<6.0
				if key in ["jump","apex","fall","air_jump"]:rear_carry=rear_carry and float(pose["weapon_tip"][0])<float(pose["hand"][0])-8.0
		check(upright,wid+" every airborne flight pose keeps head above hip without somersault")
		check(attached,wid+" wing attachment follows every actual shoulder")
		check(rear_carry,wid+" repeated jumps carry the sword naturally behind the hand")
	for rel: String in contract["parry_files"]:
		var image:=Image.new();image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://"+rel))
		check(image.get_size()==Vector2i(576,384) and image.get_used_rect().has_area(),"new weapon parry art retains native mapped guard sheets: "+rel)
	for rel: String in contract["runtime_files"]:
		check(FileAccess.get_file_as_string("res://"+rel).replace("\r\n","\n").sha256_text()==str(contract["runtime_files"][rel]),"gameplay source unchanged (canonical LF): "+rel)
	var game:=Game.new();root.add_child(game)
	var actor:=Actor.new();actor.game=game;game.add_child(actor);game.player=actor
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
	var motion:=Motion.new();motion.name="MotionBlur";game.add_child(motion);motion.setup(game);motion.set_process(false)
	var trail: Node=motion.get_node("MovementTrail");trail.set_process(false);trail.clear()
	actor.velocity=Vector2.UP*520;actor.position=Vector2.ZERO
	trail._process(0.0)
	for i: int in 5:
		actor.position+=Vector2.UP*13.0;trail._process(.025)
	check(int(trail.counts()["snapshots"])>0 and int(trail.counts()["snapshots"])<=int(trail.counts()["max_snapshots"]),"one MovementTrail owner stores bounded actual past flight poses")
	var history: Dictionary=trail._samples[0].duplicate(true) if not trail._samples.is_empty() else {}
	actor.dash_direction=Vector2.DOWN;actor.weapon="heavy"
	check(not history.is_empty() and history["region"]==Renderer.hero_region("dash",1,1,true,Vector2.UP) and history["weapon"]=="light","past afterimage retains its captured upward pose and weapon after live changes")
	check(not history.is_empty() and Vector2(history["at"]).distance_to(actor.global_position)>1.0,"movement ghost is a historical position rather than a copy at the live body")
	var fx:=FX.new();game.add_child(fx);fx.setup(game);fx.set_process(false)
	fx._ghost(actor,"hero",Color.WHITE,.5,.15)
	check(fx._ghosts.is_empty(),"legacy gradient movement ghosts stay disabled under the real history owner")
	var crisp:=CombatFX.new();game.add_child(crisp);crisp.configure(game);crisp.set_process(false)
	crisp._snapshot_ghost()
	check(crisp._ghosts.is_empty(),"legacy pixel movement ghosts cannot double the real history owner")
	actor.weapon="light"
	actor.animation_state="attack";actor.combo=3;actor.frame=3
	var attack_pose: Dictionary=hero["weapons"]["light"]["pose_joints"]["air_cut_3_attack"][3]
	var shoulder: Array=attack_pose["shoulder"]
	check(Renderer.wing_anchor(actor).distance_to(Vector2(float(shoulder[0])-3.36,float(shoulder[1])+2.52))<.01,"air attack transitions keep wing root on existing shoulder landmarks")
	check(Engine.time_scale==1.0,"presentation never changes the music time scale")
	game.queue_free();await process_frame
	print("Wing flight visual: %d passed, %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
