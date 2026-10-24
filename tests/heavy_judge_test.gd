extends SceneTree
## Pure cosmetic clock tests. No player, main scene, sound, pose or damage calls.
const Judge = preload("res://combat/friend_rhythm/heavy_judge.gd")
const Parser = preload("res://combat/friend_rhythm/chart_parser.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS ", label)
    else:
        failed += 1
        push_error("FAIL " + label)

func marks(times: Array) -> Array[Dictionary]:
    var groups: Array[Dictionary] = []
    for time: Variant in times:
        groups.append({"time": time})
    return groups

func _initialize() -> void:
    var judge: RefCounted = Judge.new()
    for error: float in [-0.125, 0.125]:
        judge.setup(marks([1.0]), 0.125, 10)
        judge.register_block(1.0 + error)
        var result: Array[Dictionary] = judge.update(1.125)
        check(result.size() == 1 and result[0]["success"], "inclusive boundary succeeds at error %.3f" % error)
        check(result[0]["matched_time"] == 1.0 + error and is_equal_approx(float(result[0]["error_seconds"]), error), "boundary retains actual matched time and signed error")
    for error: float in [-0.12501, 0.12501]:
        judge.setup(marks([1.0]))
        judge.register_block(1.0 + error)
        var result: Array[Dictionary] = judge.update(1.126)
        check(result.size() == 1 and not result[0]["success"] and result[0]["matched_time"] == null, "outside boundary remains a cosmetic miss %.5f" % error)
    judge.setup(marks([1.0]))
    judge.register_block(0.875)
    check(judge.update(1.124).is_empty(), "accepted early press waits until right edge")
    var preview: Array[Dictionary] = judge.get_visible(1.124)
    check(preview.size() == 1 and not preview[0]["judged"] and not preview[0]["success"] and preview[0]["matched_time"] == null, "preview never exposes accepted status before judgement")
    var delayed: Array[Dictionary] = judge.update(80.0)
    check(delayed.size() == 1 and delayed[0]["success"] and delayed[0]["matched_time"] == 0.875, "accepted input survives a long frame gap without global pruning")
    check(judge.update(81.0).is_empty(), "results emit only once even after a long gap")
    judge.setup(marks([1.0, 1.1, 1.2]))
    judge.register_block(1.1)
    var overlap_first: Array[Dictionary] = judge.update(1.225)
    var overlap_last: Array[Dictionary] = judge.update(1.325)
    check(overlap_first.size() == 2 and overlap_last.size() == 1, "closely spaced groups retain independent right boundaries")
    check(overlap_first[0]["success"] and overlap_first[1]["success"] and overlap_last[0]["success"], "one real press scores all overlapping marks independently")
    judge.setup(marks([1.0, 2.0, 3.0]))
    judge.register_block(1.0)
    judge.register_block(3.0)
    var mixed: Array[Dictionary] = judge.update(15.0)
    check(mixed.size() == 3 and mixed[0]["success"] and not mixed[1]["success"] and mixed[2]["success"], "dropped update across many marks preserves each success and miss")
    check(mixed[1]["error_seconds"] == null and mixed[1]["matched_time"] == null, "miss has no fabricated matched input")
    judge.setup(marks([1.0]))
    var missed: Array[Dictionary] = judge.update(1.125)
    judge.register_block(1.125)
    check(not missed[0]["success"] and judge.update(1.125).is_empty(), "input after judgement cannot retroactively replace a result")
    judge.setup(marks([1.0]), 0.125, 1)
    judge.register_block(1.0)
    judge.setup(marks([1.0]), 0.125, 2)
    var epoch: Array[Dictionary] = judge.update(1.125)
    check(epoch.size() == 1 and not epoch[0]["success"] and epoch[0]["generation"] == 2, "new setup epoch cannot inherit an old accepted press")
    judge.setup(marks([1.0]), 0.125, 2)
    check(not judge.update(1.125)[0]["success"], "restarting even the same generation clears history")
    judge.setup(marks([0.0, 5.0, 10.0]), 0.125, 3, 5.2)
    check(judge.update(5.2).is_empty(), "seek skips old right windows without stale miss results")
    var sought: Array[Dictionary] = judge.get_visible(5.2, 10.0)
    check(sought.size() == 1 and sought[0]["id"] == 2 and sought[0]["time"] == 10.0, "seek preserves original bounded source index")
    judge.setup(marks([0.0, 5.0, 10.0]), 0.125, 4, 5.125)
    judge.register_block(5.125)
    var seek_edge: Array[Dictionary] = judge.update(5.125)
    check(seek_edge.size() == 1 and seek_edge[0]["id"] == 1 and seek_edge[0]["success"], "seek retains the exact inclusive right window edge")
    judge.setup(marks([1.0, 2.0]))
    judge.update(1.125)
    judge.register_block(1.0)
    check(judge.update(0.5).is_empty() and judge.get_visible(0.5).is_empty(), "backward source time cannot emit or display stale history")
    judge.register_block(2.0)
    check(judge.update(2.125)[0]["success"], "backward attempts do not disturb the later valid window")
    judge.setup(marks([2.0, 5.0]))
    check(judge.get_visible(0.0).size() == 1, "default lead is exactly two seconds")
    check(judge.get_visible(0.01, 0.1).is_empty(), "shorter lead does not alter mark state")
    judge.register_block(2.0)
    judge.update(2.125)
    check(judge.get_visible(2.725).size() == 1 and judge.get_visible(2.726).is_empty(), "judged feedback expires after the fixed .6-second tail")
    judge.setup(marks([1.0]))
    var copy: Array[Dictionary] = judge.get_visible(0.0)
    copy[0]["judged"] = true
    copy[0]["time"] = 99.0
    judge.register_block(1.0)
    check(judge.update(1.125)[0]["success"], "UI copies cannot mutate judgement state")
    judge.setup(marks([1.0, 1.0, 1.0]))
    judge.register_block(1.0)
    var equal_marks: Array[Dictionary] = judge.update(1.125)
    check(equal_marks.size() == 3 and equal_marks[0]["id"] == 0 and equal_marks[2]["id"] == 2, "same-time groups remain independent original-index marks")
    judge.setup(marks([1.0]))
    judge.register_block(0.9)
    judge.register_block(1.0)
    check(judge.update(1.125)[0]["matched_time"] == 0.9, "first accepted time remains stable across repeated inputs")
    judge.setup(marks([2.0]), 0.0)
    judge.register_block(2.0)
    check(judge.update(2.0)[0]["success"], "zero configured window accepts its exact instant")
    judge.setup(marks([1.0]))
    judge.register_block(INF)
    judge.register_block(NAN)
    check(judge.update(INF).is_empty() and judge.get_visible(NAN).is_empty(), "non-finite transport inputs are ignored")
    judge.register_block(1.0)
    check(judge.update(1.125)[0]["success"], "invalid transport inputs do not poison later valid time")
    # Read-only validation of the existing 107-group source chart; no audio read/copied.
    var parser: RefCounted = Parser.new()
    var parsed: bool = parser.parse_file("res://boss_attack/data/if_infinity.chart.json", 203.0, 0.0, 4.0)
    check(parsed and parser.heavy_groups.size() == 107, "reviewed parser exposes all 107 existing full-song heavy groups")
    var full_groups: Array[Dictionary] = []
    full_groups.assign(parser.heavy_groups)
    judge.setup(full_groups, 0.125, 107)
    var times: Array[float] = []
    for group: Dictionary in full_groups:
        times.append(float(group["time"]))
    times.sort()
    for time: float in times:
        judge.register_block(time)
    var all_results: Array[Dictionary] = judge.update(times.back() + 3.0 if not times.is_empty() else 1.0)
    var ids: Dictionary = {}
    var all_success: bool = all_results.size() == 107
    for result: Dictionary in all_results:
        ids[result["id"]] = true
        all_success = all_success and result["success"] and absf(float(result["error_seconds"])) <= 0.125001 and int(result["id"]) >= 0 and int(result["id"]) < 107 and int(result["generation"]) == 107
    check(all_success and ids.size() == 107, "full-song long frame gap yields 107 independent retained results and bounded unique IDs")
    check(judge.update(times.back() + 4.0 if not times.is_empty() else 2.0).is_empty(), "full-song results never emit twice")
    judge.setup(full_groups, 0.125, 108)
    var fresh: Array[Dictionary] = judge.update(times.back() + 5.0 if not times.is_empty() else 3.0)
    var all_miss: bool = fresh.size() == 107
    for result: Dictionary in fresh:
        all_miss = all_miss and not result["success"] and result["generation"] == 108
    check(all_miss, "new song loop has no accepted-input carry from prior 107 marks")
    print("HEAVY_JUDGE_TEST: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
