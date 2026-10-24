extends Control
## Read-only rhythm feedback. Raw Left Shift is observed independently of combat parry/CD.
## This control never grants defense, damages an actor, consumes input, or changes a clock.
const PixelFont = preload("res://presentation/pixel_font.gd")
const JUDGE_PATH: String = "res://combat/friend_rhythm/heavy_judge.gd"
const LANE_RECT := Rect2(12,108,68,178)
const LEAD_SECONDS: float = 2.0
const WINDOW_SECONDS: float = 0.125
const ENTRY_Y: float = 36.0
const JUDGMENT_Y: float = 120.0
const MARK_X: float = 34.0
const MAX_VISIBLE_MARKS: int = 24
const MAX_FEEDBACK: int = 16
const STRINGS: Array[String] = ["重鼓", "节拍", "±125ms", "左SHIFT", "合拍", "错过", "休息"]
const WHITE := Color("f3f5e9")
const ORANGE := Color("f4b95f")
const CYAN := Color("73f6df")
const GRAY := Color("78818c")
var game: Node
var _font: Font
var _judge: Variant = null
var _generation: int = -1
var _was_safe: bool = false
var _marks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _chart_now: float = 0.0
var _feedback_text: String = ""
var _feedback_until: float = -1.0
var _feedback_success: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = LANE_RECT.position
	size = LANE_RECT.size
	_font = PixelFont.create()
	visible = false

func setup(owner_game: Node) -> void:
	game = owner_game
	_generation = -1
	_judge = null
	_marks.clear()
	_results.clear()
	_feedback_text = ""
	_feedback_until = -1.0
	_was_safe = false
	queue_redraw()

static func marker_y(mark_time: float, chart_now: float) -> float:
	return JUDGMENT_Y - (mark_time-chart_now) * (JUDGMENT_Y-ENTRY_Y)/LEAD_SECONDS

static func window_half_height() -> float:
	return (JUDGMENT_Y-ENTRY_Y) * WINDOW_SECONDS/LEAD_SECONDS

func _music() -> Node:
	if not is_instance_valid(game): return null
	var value: Variant = game.get("music")
	return value as Node if value != null and is_instance_valid(value) else null

func _can_show() -> bool:
	var music: Node = _music()
	if music == null or not music.has_method("is_full_song") or not music.has_method("get_chart_time") or not music.has_method("get_transport_generation") or not music.has_method("get_heavy_groups"):
		return false
	if not bool(music.call("is_full_song")) or not bool(music.get("running")) or not bool(game.get("boss_started")):
		return false
	if get_tree().paused or bool(game.get("_paused")) or str(game.get("outcome")) != "":
		return false
	var overlay: Variant = game.get("_overlay")
	return overlay == null or str(overlay) == ""

func _sync_transport(now: float, skip_past: bool = false) -> bool:
	var music: Node = _music()
	if music == null or not is_finite(now): return false
	var generation: int = int(music.call("get_transport_generation"))
	if _judge == null or generation != _generation or skip_past:
		if not ResourceLoader.exists(JUDGE_PATH): return false
		var script: Script = load(JUDGE_PATH)
		if script == null: return false
		_judge = script.new()
		var groups: Array[Dictionary] = []
		for item: Variant in music.call("get_heavy_groups"):
			if item is Dictionary:
				var copy: Dictionary = item.duplicate(true)
				# Keep the original array index/ID, but never judge a mark that happened in rest.
				if skip_past and float(copy.get("time",0.0)) < now:
					copy["time"] = null
				groups.append(copy)
		_generation = generation
		# A rest is preview-only. At its exit ignore all marks before the current source time.
		_judge.setup(groups,WINDOW_SECONDS,generation,now)
		_marks.clear()
		_results.clear()
		_feedback_text = ""
		_feedback_until = -1.0
	return true

func _record_results(results: Array) -> void:
	for value: Variant in results:
		if not value is Dictionary: continue
		var result: Dictionary = value.duplicate(true)
		_results.append(result)
		while _results.size() > MAX_FEEDBACK: _results.pop_front()
		_feedback_success = bool(result.get("success",false))
		_feedback_text = "合拍" if _feedback_success else "错过"
		_feedback_until = float(result.get("feedback_until",_chart_now+0.6))

func _process(_delta: float) -> void:
	if not _can_show():
		visible = false
		_marks.clear()
		return
	var music: Node = _music()
	_chart_now = float(music.call("get_chart_time"))
	var safe: bool = bool(game.get("story_safe"))
	if not _sync_transport(_chart_now,_was_safe and not safe):
		visible = false
		return
	visible = true
	_was_safe = safe
	# The music transport is the sole time source. No judge calls advance inside story rest.
	if not safe: _record_results(_judge.update(_chart_now))
	_marks.clear()
	for value: Variant in _judge.get_visible(_chart_now,LEAD_SECONDS):
		if not value is Dictionary: continue
		var mark: Dictionary = value
		if safe and float(mark.get("time",0.0)) < _chart_now: continue
		_marks.append(mark.duplicate(true))
		if _marks.size() >= MAX_VISIBLE_MARKS: break
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode != KEY_SHIFT or event.location != KEY_LOCATION_LEFT: return
	if not InputMap.event_is_action(event,"parry"): return
	var music: Node = _music()
	if music == null: return
	var now: float
	# Sample this press from the existing music transport, never the previous render cache.
	if music.has_method("sample_input_chart_time"):
		now = float(music.call("sample_input_chart_time"))
	elif music.has_method("get_chart_time"):
		now = float(music.call("get_chart_time"))
	else:
		return
	# Sampling may cross rest/EOF or change the transport epoch; check gates afterwards.
	if not _can_show() or bool(game.get("story_safe")): return
	if not _sync_transport(now,_was_safe): return
	_chart_now = now
	_was_safe = false
	_judge.register_block(now)
	# Do not call set_input_as_handled: this same press still belongs to the real combat controller.

func _text(y: float, value: String, ink: Color) -> void:
	var width: float = _font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(_font,Vector2(roundf((size.x-width)*0.5),y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)

func _draw() -> void:
	if not visible or _font == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.055,0.90))
	draw_rect(Rect2(Vector2.ZERO,size),Color("4f5b6c"),false,1.0)
	_text(14,"重鼓",WHITE)
	_text(28,"节拍",GRAY)
	var half: float = roundf(window_half_height())
	draw_rect(Rect2(22,JUDGMENT_Y-half,24,half*2+1),Color("344e5b"))
	draw_rect(Rect2(32,ENTRY_Y,4,JUDGMENT_Y-ENTRY_Y),Color("242d3a"))
	draw_rect(Rect2(10,JUDGMENT_Y-1,48,2),WHITE)
	for mark: Dictionary in _marks:
		var y: float = roundf(marker_y(float(mark.get("time",0.0)),_chart_now))
		if y < ENTRY_Y-1 or y > JUDGMENT_Y+half: continue
		var ink: Color = ORANGE
		if bool(mark.get("judged",false)):
			ink = CYAN if bool(mark.get("success",false)) else GRAY
		var at := Vector2(MARK_X,y)
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-4),at+Vector2(5,0),at+Vector2(0,4),at+Vector2(-5,0)]),ink)
		draw_rect(Rect2(at-Vector2.ONE,Vector2(2,2)),WHITE if not bool(mark.get("judged",false)) else ink)
	_text(145,"±125ms",GRAY)
	if bool(game.get("story_safe")):
		_text(160,"休息",GRAY)
	elif _chart_now <= _feedback_until:
		_text(160,_feedback_text,CYAN if _feedback_success else GRAY)
	_text(174,"左SHIFT",WHITE)
