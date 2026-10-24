extends RefCounted
## Original six-kind pixel cast. Controller clocks/state are read only.
const ROOT: String = "res://presentation/enemy_frames/"
const KINDS: Array[String] = ["sentry", "wisp", "elite", "lantern", "jailer", "bat"]
const CELL := Vector2(80,80)
const ANCHOR := Vector2(40,76)
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}

static func supports(kind: String) -> bool:
	return kind in KINDS

static func data() -> Dictionary:
	if _manifest.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
		if parsed is Dictionary: _manifest = parsed
	return _manifest

static func states(kind: String) -> Dictionary:
	return data().get("kinds",{}).get(kind,{}).get("states",{})

static func describe(actor: Object, kind: String, state: String, frame: int) -> Dictionary:
	if not supports(kind): return {}
	var snapshot: Variant = actor.get("enemy_pose_snapshot")
	if snapshot is Dictionary and not snapshot.is_empty(): return snapshot.duplicate(true)
	var clip: String = state
	var index: int = clampi(frame,0,3)
	var progress: float = float(index)/3.0
	# Damage/death reactions take priority over an interrupted cast; no wall-clock animation.
	if state not in ["hurt","dead","parry"]:
		var phase: Variant = actor.get("cast_phase")
		if phase != null and str(phase) in ["windup","release","recover"]:
			clip = {"windup":"windup","release":"attack","recover":"recover"}[str(phase)]
			var value: Variant = actor.get("cast_progress")
			if value != null:
				progress = clampf(float(value),0.0,1.0)
				index = clampi(int(progress*4.0),0,3)
	if not states(kind).has(clip): clip = "idle"
	return {"kind":kind,"state":clip,"frame":index,"progress":progress}

static func region(kind: String, state: String, frame: int) -> Rect2:
	var descriptor: Dictionary = states(kind).get(state,states(kind).get("idle",{}))
	var index: int = int(descriptor.get("start",0)) + clampi(frame,0,3)
	return Rect2(Vector2(index%4,index/4)*CELL,CELL)

static func landmark(kind: String, state: String, frame: int, key: String) -> Variant:
	var frames: Array = states(kind).get(state,{}).get("frames",[])
	if frames.is_empty(): return null
	var value: Variant = frames[clampi(frame,0,3)].get(key)
	if value is Array: return Vector2(float(value[0]),float(value[1]))
	return null

static func _texture(kind: String, flash: bool) -> Texture2D:
	var file: String = data().get("kinds",{}).get(kind,{}).get("flash" if flash else "atlas", "")
	if file == "": return null
	if not _textures.has(file): _textures[file] = load(ROOT+file)
	return _textures[file]

static func paint(canvas: Node2D, kind: String, state: String, frame: int, facing: int) -> void:
	var pose: Dictionary = describe(canvas,kind,state,frame)
	if pose.is_empty(): return
	var flash: Variant = canvas.get("hurt_flash")
	if flash == null: flash = canvas.get("_hurt_flash")
	var flashing: bool = flash != null and float(flash)>0.055 and str(pose["state"]) != "dead"
	var texture: Texture2D = _texture(kind,flashing)
	if texture == null: return
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(float(facing),1))
	canvas.draw_texture_rect_region(texture,Rect2(-ANCHOR,CELL),region(kind,pose["state"],int(pose["frame"])))
	canvas.draw_set_transform(Vector2.ZERO)
