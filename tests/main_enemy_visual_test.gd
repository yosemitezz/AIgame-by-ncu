extends SceneTree
## Native pixel-cast contract and one fixed draw frame, never an automated playthrough.
const Visual = preload("res://presentation/enemy_visual.gd")
const Renderer = preload("res://presentation/actor_renderer.gd")
const Enemy = preload("res://actors/enemy.gd")
const HERO_SHA: String = "a544f3443546e66ccddcd19ed566ed2af3fa000f189fd2eef9861a81158a4ea8"
const IMPACT_SHA: String = "4bff7680dc43e6615561771b3d688b2d4fc3663e646fa70ce26a612c44ed9a48"
class Probe extends Node2D:
	var cast_phase: String = "none"
	var cast_progress: float = 0.0
	var enemy_pose_snapshot: Dictionary = {}
var passed: int = 0
var failed: int = 0
func check(value: bool,label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL "+label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(FileAccess.get_sha256("res://presentation/feel_frames/hero_atlas.png")==HERO_SHA,"long-limb Hero source atlas remains byte-identical")
	check(FileAccess.get_sha256("res://combat/impact_feedback.gd")==IMPACT_SHA,"primary heavy-impact source remains byte-identical")
	check(Renderer.HERO_SIZE==Vector2(144,128) and Renderer.HERO_ANCHOR==Vector2(66,108),"Hero native drawing contract is unchanged")
	check(Visual.CELL==Vector2(80,80) and Visual.ANCHOR==Vector2(40,76),"six-kind native cell and feet anchor are stable")
	check(Visual.data().get("kinds",{}).size()==6 and not Visual.supports("unknown_kind"),"six distinct kind dispatches never silently fall back to a sentry")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://presentation/enemy_frames/asset-report.json"))
	var hashes: Dictionary = {}
	for kind: String in Visual.KINDS:
		var metadata: Dictionary = Visual.data()["kinds"][kind]
		var image: Texture2D = load(Visual.ROOT+metadata["atlas"])
		check(image.get_size()==Vector2(320,640),kind+" atlas is eight states by four native cells")
		var hash: String = FileAccess.get_sha256(Visual.ROOT+metadata["atlas"])
		hashes[hash]=true
		check(int(report["kinds"][kind]["unique_frames"])>=24 and int(report["kinds"][kind]["opaque_palette_colors"])<=32,kind+" contains real distinct poses with a bounded pixel palette")
		for state: String in ["idle","run","windup","attack","recover","hurt","parry","dead"]:
			check(Visual.states(kind).has(state) and int(Visual.states(kind)[state]["count"])==4,kind+" has four "+state+" cells")
			for frame: int in 4:
				check(Rect2(0,0,320,640).encloses(Visual.region(kind,state,frame)),kind+" "+state+" native region is in bounds")
				for key: String in ["hand","weapon_tip","guard_point"]:
					var value: Variant = Visual.landmark(kind,state,frame,key)
					check(value==null or Rect2(-40,-76,80,80).has_point(value),kind+" "+state+" "+key+" stays in its source cell")
	check(hashes.size()==6,"all six silhouettes use different source images, not a palette-swapped atlas")
	var probe := Probe.new()
	root.add_child(probe)
	for phase: String in ["windup","release","recover"]:
		probe.cast_phase=phase
		probe.cast_progress=0.62
		var pose: Dictionary = Visual.describe(probe,"lantern","idle",0)
		check(pose["state"]=={"windup":"windup","release":"attack","recover":"recover"}[phase] and int(pose["frame"])==2,"cast "+phase+" selects the actual frozen stage fraction")
		var frozen: Dictionary = pose.duplicate(true)
		check(Visual.describe(probe,"lantern","idle",3)==frozen,"unrelated animation frame cannot advance a held cast")
	check(Visual.describe(probe,"jailer","hurt",1)["state"]=="hurt","hit reaction takes priority over a stale cast")
	check(Visual.describe(probe,"bat","dead",3)["state"]=="dead","death takes priority over casting")
	check(Visual.describe(probe,"unknown_kind","idle",0).is_empty(),"unknown kind produces no mismatched sprite")
	probe.enemy_pose_snapshot={"kind":"bat","state":"attack","frame":1,"progress":0.3}
	check(Visual.describe(probe,"bat","run",3)==probe.enemy_pose_snapshot,"snapshot pose stays immutable across actor phase changes")
	probe.queue_free()
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.music.stop_score()
	game.music.set_process(false)
	for actor: Node in get_nodes_in_group("enemies"):actor.set_physics_process(false)
	var hp: int=game.player.health
	var at: Vector2=game.player.position
	var time_before: float=Engine.time_scale
	var spawned: Array[Node]=[]
	for index: int in Visual.KINDS.size():
		var kind: String=Visual.KINDS[index]
		var enemy:=Enemy.new()
		enemy.configure(game,kind,Vector2(500+index*90,280))
		game.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.animation_state="windup"
		enemy.frame=2
		var pose: Dictionary=Visual.describe(enemy,kind,enemy.animation_state,enemy.frame)
		check(pose["kind"]==kind and pose["state"] in ["idle","windup"],kind+" real actor reaches its own visual adapter")
		enemy.queue_redraw()
		spawned.append(enemy)
	await process_frame
	var fx: Node=game.get_node("FxLayer")
	for style: String in ["lantern_fan","bat_seed","bat_bloom","jailer_link"]:
		check(fx._trail_ramp(style,false)==style,style+" hostile tail uses its matching core family")
		check(fx._trail_ramp(style,true)=="reflected_tail",style+" reflection becomes friendly cyan")
	check(game.player.health==hp and game.player.position==at and Engine.time_scale==time_before,"sprite integration never writes damage, player movement or global time")
	for enemy: Node in spawned:enemy.queue_free()
	print("Main enemy visual: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
