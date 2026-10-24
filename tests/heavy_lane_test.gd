extends SceneTree
## Cosmetic heavy lane checks; no actual song playback or gameplay input simulation.
const Lane = preload("res://ui/heavy_lane.gd")
const HUD = preload("res://ui/hud.gd")
class MusicProbe extends Node:
	var running: bool = true
	var full: bool = true
	var now: float = 0.0
	var fresh_time: Variant = null
	var on_sample: Callable
	var sample_count: int = 0
	var generation: int = 1
	var groups: Array[Dictionary] = [{"time":1.0},{"time":1.296},{"time":2.0},{"time":3.0}]
	func is_full_song() -> bool: return full
	func get_chart_time() -> float: return now
	func sample_input_chart_time() -> float:
		sample_count += 1
		if fresh_time != null: now = float(fresh_time)
		if on_sample.is_valid(): on_sample.call()
		return now
	func get_transport_generation() -> int: return generation
	func get_heavy_groups() -> Array[Dictionary]: return groups.duplicate(true)
class GameProbe extends Node:
	var music: Node
	var boss_started: bool = true
	var story_safe: bool = false
	var outcome: String = ""
	var _paused: bool = false
	var _overlay: String = ""
	var health: int = 9
	var parry_start_count: int = 0
var passed: int = 0
var failed: int = 0
func check(value: bool,label: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL "+label)
func _initialize() -> void: call_deferred("run")
func press(lane: Control,left: bool = true,echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=KEY_SHIFT
	event.keycode=KEY_SHIFT
	event.location=KEY_LOCATION_LEFT if left else KEY_LOCATION_RIGHT
	event.pressed=true
	event.echo=echo
	lane._unhandled_input(event)
func run() -> void:
	check(Lane.LEAD_SECONDS==2.0 and Lane.WINDOW_SECONDS==0.125,"two-second approach and 125ms window are exact")
	check(is_equal_approx(Lane.marker_y(12,10),Lane.ENTRY_Y),"two-second future mark starts at the lane entrance")
	check(is_equal_approx(Lane.marker_y(10,10),Lane.JUDGMENT_Y),"mark reaches the fixed line exactly at source time")
	check(is_equal_approx(Lane.marker_y(10,10.125)-Lane.JUDGMENT_Y,Lane.window_half_height()),"125ms maps exactly to the lower visual judgment boundary")
	check(is_equal_approx(Lane.JUDGMENT_Y-Lane.marker_y(10.125,10),Lane.window_half_height()),"early visual boundary is symmetric")
	var hud := HUD.new()
	var layout: Dictionary = hud.panel_layout(Vector2(800,450),true)
	for key: String in ["boss","dialog","bottom"]:
		check(not Lane.LANE_RECT.intersects(layout[key]),"left lane avoids the actual "+key+" panel")
	hud.free()
	var game := GameProbe.new()
	var music := MusicProbe.new()
	game.music=music
	root.add_child(game)
	game.add_child(music)
	var layer := CanvasLayer.new()
	layer.layer=31
	game.add_child(layer)
	var lane := Lane.new()
	layer.add_child(lane)
	lane.setup(game)
	await process_frame
	lane.set_process(false)
	check(lane.position==Lane.LANE_RECT.position and lane.size==Lane.LANE_RECT.size,"control uses the reviewed native HUD rectangle")
	check(lane.mouse_filter==Control.MOUSE_FILTER_IGNORE,"lane never intercepts GUI pointer input")
	check(lane.STRINGS[0].unicode_at(0)==0x91cd,"Chinese title survived source encoding")
	for label: String in Lane.STRINGS:
		for index: int in label.length():
			check(lane._font.has_char(label.unicode_at(index)),"native Fusion font contains the lane glyph")
	if not InputMap.has_action("parry"): InputMap.add_action("parry")
	InputMap.action_erase_events("parry")
	var binding := InputEventKey.new()
	binding.physical_keycode=KEY_SHIFT
	binding.location=KEY_LOCATION_LEFT
	InputMap.action_add_event("parry",binding)
	lane._process(0)
	check(lane.visible and lane._generation==1,"full song with running Boss enables the lane")
	music.now=0.92
	press(lane)
	music.now=1.126
	lane._process(0)
	check(lane._results.size()==1 and lane._results[0]["success"],"raw Left Shift yields cosmetic success at the right boundary")
	check(lane._feedback_text=="\u5408\u62cd".c_unescape(),"success feedback is the concise accepted label")
	music.now=1.296
	press(lane)
	music.now=1.422
	lane._process(0)
	check(lane._results.size()==2 and lane._results[1]["success"] and lane._results[1]["id"]!=lane._results[0]["id"],"marks 296ms apart judge independently of battle parry cooldown")
	music.now=2.0
	press(lane,false)
	press(lane,true,true)
	music.now=2.126
	lane._process(0)
	check(lane._results.size()==3 and not lane._results[2]["success"],"Right Shift and echoed Left Shift cannot register a mark")
	check(lane._feedback_text=="\u9519\u8fc7".c_unescape(),"miss feedback stays cosmetic and concise")
	check(game.health==9 and game.parry_start_count==0,"lane never grants contact defense or changes HP")
	music.generation=2
	music.now=0
	lane._process(0)
	check(lane._generation==2 and lane._results.is_empty() and lane._feedback_text=="","transport generation clears all old results/cursor state")
	game.story_safe=true
	music.now=0.92
	press(lane)
	music.now=1.2
	lane._process(0)
	check(lane.visible and lane._results.is_empty(),"rest keeps upcoming preview visible without judgment")
	check(lane._marks.all(func(mark: Dictionary) -> bool: return float(mark["time"])>=music.now),"rest previews future marks only")
	game.story_safe=false
	music.now=1.5
	lane._process(0)
	check(lane._results.is_empty(),"rest exit cannot award misses for skipped rest marks")
	music.now=1.92
	press(lane)
	music.now=2.126
	lane._process(0)
	check(lane._results.size()==1 and lane._results[0]["id"]==2 and lane._results[0]["success"],"rest rebase preserves source mark ID and immediately accepts valid future input")
	# A stalled render clock must not backdate a press sampled from the audio backend.
	music.generation=10
	music.now=0.95
	music.groups=[{"time":1.0}]
	lane._process(0)
	music.fresh_time=1.15
	press(lane)
	lane._process(0)
	check(lane._results.size()==1 and not lane._results[0]["success"],"stale mark-minus-50ms cache cannot accept a real mark-plus-150ms press")
	check(is_equal_approx(lane._chart_now,1.15) and music.sample_count>0,"UI input uses the existing transport fresh sample without a second clock")
	music.generation=11
	music.now=0.95
	music.fresh_time=null
	lane._process(0)
	music.fresh_time=1.05
	press(lane)
	music.fresh_time=null
	music.now=1.126
	lane._process(0)
	check(lane._results.size()==1 and lane._results[0]["success"] and is_equal_approx(float(lane._results[0]["matched_time"]),1.05),"fresh mark-plus-50ms press succeeds and keeps its source timestamp")
	# Music sampling itself can trigger safety/end/epoch transitions before UI registration.
	music.generation=12
	music.now=0.9
	lane._process(0)
	music.fresh_time=1.0
	music.on_sample=func() -> void: game.story_safe=true
	press(lane)
	music.on_sample=Callable()
	game.story_safe=false
	music.fresh_time=null
	music.now=1.126
	lane._process(0)
	check(lane._results.size()==1 and not lane._results[0]["success"],"fresh sample entering rest rechecks safety before registering")
	music.generation=13
	music.now=0.9
	lane._process(0)
	music.fresh_time=1.0
	music.on_sample=func() -> void: music.running=false
	press(lane)
	music.on_sample=Callable()
	music.running=true
	music.fresh_time=null
	music.now=1.126
	lane._process(0)
	check(lane._results.size()==1 and not lane._results[0]["success"],"fresh sample reaching EOF rechecks running before registering")
	music.generation=14
	music.now=0.95
	lane._process(0)
	music.fresh_time=1.05
	music.on_sample=func() -> void: music.generation=15
	press(lane)
	music.on_sample=Callable()
	music.fresh_time=null
	music.now=1.126
	lane._process(0)
	check(lane._generation==15 and lane._results.size()==1 and lane._results[0]["success"],"fresh sample epoch change resynchronizes before registration")
	for gate: String in ["pause","map","outcome","not_started","not_running","not_full"]:
		game._paused=gate=="pause"
		game._overlay="map" if gate=="map" else ""
		game.outcome="defeat" if gate=="outcome" else ""
		game.boss_started=gate!="not_started"
		music.running=gate!="not_running"
		music.full=gate!="not_full"
		lane._process(0)
		check(not lane.visible,"lane hides for "+gate)
	game._paused=false
	game._overlay=""
	game.outcome=""
	game.boss_started=true
	music.running=true
	music.full=true
	paused=true
	lane._process(0)
	check(not lane.visible,"tree pause hides lane")
	paused=false
	music.generation=3
	music.now=0
	music.groups.clear()
	for index: int in 60: music.groups.append({"time":0.5+index*0.01})
	lane._process(0)
	check(lane._marks.size()==Lane.MAX_VISIBLE_MARKS,"dense source charts keep visible marker count bounded")
	music.now=2
	lane._process(0)
	check(lane._results.size()==Lane.MAX_FEEDBACK,"multiple independent results keep feedback storage bounded")
	check(game.health==9 and Engine.time_scale==1.0,"all judgments remain presentation-only")
	var source: String = FileAccess.get_file_as_string("res://ui/heavy_lane.gd")
	check(not source.contains("set_input_as_handled(") and not source.contains("damage_player(") and not source.contains("parry_success("),"lane never consumes combat input or calls defense/damage")
	print("Heavy lane: %d passed, %d failed" % [passed,failed])
	quit(1 if failed else 0)
