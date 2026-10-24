extends SceneTree
const Parser = preload("res://combat/friend_rhythm/chart_parser.gd")
func _initialize() -> void:
    var parser: RefCounted = Parser.new()
    parser.fast_interval_threshold_beats = 1.1
    var path: String = "res://boss_attack/data/if_infinity.chart.json"
    var ok: bool = parser.parse_file(path, 203.0, 245.0, 4.0)
    var stats: Dictionary = parser.get_stats()
    var basic: int = 0
    var fast: int = 0
    for phrase: Dictionary in parser.action_phrases:
        if str(phrase.get("mode", "")) == "fast": fast += 1
        else: basic += 1
    stats["endbeat_records"] = parser.lasers.size()
    var ordinary: int = 0
    for laser: Dictionary in parser.lasers:
        if not laser.has("fixed_attack_index"): ordinary += 1
    stats["ordinary_lasers"] = ordinary
    stats["basic_phrases"] = basic
    stats["fast_phrases"] = fast
    stats["source_sha256"] = FileAccess.get_sha256(path)
    stats["errors"] = parser.errors
    var expected: Dictionary = {"notes":1172,"timed_notes":1171,"unique_times":862,"timing_groups":703,"heavy_groups":107,"endbeat_records":230,"ordinary_lasers":182,"phases":21,"paired_note_groups":315,"action_phrases":228,"fixed_attack_events":24,"laser_formations":48,"basic_phrases":141,"fast_phrases":87}
    var mismatches: Array[String] = []
    for key: String in expected:
        if int(stats.get(key,-1)) != int(expected[key]): mismatches.append(key)
    stats["mismatches"] = mismatches
    var report: FileAccess = FileAccess.open("res://artifacts/friend-source-chart-parser-audit.json",FileAccess.WRITE)
    report.store_string(JSON.stringify(stats,"  "))
    report.close()
    print(JSON.stringify(stats))
    print("Friend source chart: ",expected.size()-mismatches.size()," passed, ",mismatches.size()," failed")
    quit(0 if ok and mismatches.is_empty() else 1)
