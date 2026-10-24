extends SceneTree
## Read-only font resource validation; evidence is written only to ignored artifacts/.
## Run after Godot import: godot --headless --path . --script res://tools/font_glyph_check.gd

const PIXEL_FONT: Script = preload("res://presentation/pixel_font.gd")
const REPORT_PATH: String = "res://artifacts/font-glyph-report.json"
const SAMPLE: String = "生命 架势 破架 弹刀 重试 暂停 THE BELLKEEPER HP 08/08 0123456789"
const KEY_STRINGS: Array[String] = [
	SAMPLE,
	"生命 碎片 低血 架势 破架 休息 固定 随机 终段 双方禁伤 刀刃弹开 弹体反射",
	"移动 跳跃 冲刺 攻击 弹刀 重试 暂停 震屏 倒下了 钟声止息 第一章完成",
	"继续 返回 设置 音量 音乐 音效 开始 结束 胜利 失败 护盾 敌人 首领 进度 检查点",
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz",
	"0123456789 · / % + - = : ; , . ! ? ( ) [ ] < > _ # & @ *",
	"：，。！？（）【】《》“”×←→↑↓",
]

var _checks: Array[Dictionary] = []
var _failed: int = 0

func _initialize() -> void:
	await process_frame
	var font: FontFile = PIXEL_FONT.create()
	_check(font != null, "resource_loads_as_FontFile")
	if font == null:
		_finish({"sample": SAMPLE, "missing": [], "metrics": {}})
		return
	_check(not font.allow_system_fallback, "system_fallback_disabled")
	_check(font.fallbacks.is_empty(), "no_mixed_style_font_fallbacks")
	_check(font.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "antialiasing_disabled")
	_check(not font.multichannel_signed_distance_field, "MSDF_disabled")
	_check(not font.generate_mipmaps, "mipmaps_disabled")
	_check(font.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED, "subpixel_positioning_disabled")
	_check(font.hinting == TextServer.HINTING_NONE, "hinting_disabled")
	_check(is_equal_approx(font.oversampling, 1.0), "native_pixel_oversampling")
	_check(PIXEL_FONT.is_native_multiple(12) and PIXEL_FONT.is_native_multiple(24), "sizes_12_and_24_are_native_multiples")
	_check(not PIXEL_FONT.is_native_multiple(16), "arbitrary_16px_size_rejected_by_contract")

	var codepoints: Dictionary = {}
	var missing: Array[Dictionary] = []
	for text in KEY_STRINGS:
		for index in range(text.length()):
			var codepoint: int = text.unicode_at(index)
			if codepoints.has(codepoint):
				continue
			codepoints[codepoint] = true
			if not font.has_char(codepoint):
				missing.append({"character": String.chr(codepoint), "codepoint": "U+%04X" % codepoint})
	# Validate the actual new interface/interaction copy, beyond the legacy sample.
	for path: String in ["res://ui/hud.gd", "res://levels/bellkeep.gd"]:
		var source: String = FileAccess.get_file_as_string(path)
		for index: int in source.length():
			var codepoint: int = source.unicode_at(index)
			if codepoint >= 0x4e00 and codepoint <= 0x9fff and not codepoints.has(codepoint):
				codepoints[codepoint] = true
				if not font.has_char(codepoint):
					missing.append({"character": String.chr(codepoint), "codepoint": "U+%04X" % codepoint})
	_check(missing.is_empty(), "all_required_glyphs_present")
	var metrics: Dictionary = {}
	for size in [12, 24]:
		var font_size: int = int(size)
		var ascent: float = font.get_ascent(font_size)
		var descent: float = font.get_descent(font_size)
		var line_height: float = font.get_height(font_size)
		var digit_width: float = _width(font, "0", font_size)
		var cjk_width: float = _width(font, "生", font_size)
		var digit_widths: Array[float] = []
		for digit in "0123456789":
			var advance: float = _width(font, digit, font_size)
			digit_widths.append(advance)
			_check(is_equal_approx(advance, digit_width), "digit_%s_monospace_at_%d" % [digit, font_size])
		_check(ascent > 0.0 and descent >= 0.0, "valid_baseline_metrics_%d" % font_size)
		_check(is_equal_approx(line_height, ascent + descent), "line_height_matches_baseline_%d" % font_size)
		_check(line_height <= float(font_size + font_size / 3), "compact_line_box_%d" % font_size)
		_check(is_equal_approx(digit_width, roundf(digit_width)), "integer_digit_advance_%d" % font_size)
		_check(is_equal_approx(cjk_width, float(font_size)), "fullwidth_CJK_advance_%d" % font_size)
		metrics[str(font_size)] = {
			"ascent": ascent,
			"descent": descent,
			"height": line_height,
			"baseline_from_top": ceili(ascent),
			"integer_line_box": ceili(ascent) + ceili(descent),
			"digit_advance": digit_width,
			"CJK_advance": cjk_width,
			"digit_advances": digit_widths,
			"sample_width": _width(font, SAMPLE, font_size),
		}
	var small: Dictionary = metrics["12"]
	var large: Dictionary = metrics["24"]
	for key in ["ascent", "descent", "height", "digit_advance", "CJK_advance", "sample_width"]:
		_check(is_equal_approx(float(large[key]), float(small[key]) * 2.0), "exact_2x_%s" % key)
	_finish({
		"font_resource": PIXEL_FONT.FONT_PATH,
		"font_family": font.get_font_name(),
		"font_release": "2026.10.16",
		"font_license": "SIL Open Font License 1.1",
		"sample": SAMPLE,
		"checked_strings": KEY_STRINGS,
		"unique_codepoints_checked": codepoints.size(),
		"missing": missing,
		"metrics": metrics,
	})

func _width(font: FontFile, text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x

func _check(passed: bool, label: String) -> void:
	_checks.append({"test": label, "passed": passed})
	if not passed:
		_failed += 1
		push_error("FONT CHECK FAILED: " + label)

func _finish(report: Dictionary) -> void:
	report["checks"] = _checks
	report["passed"] = _checks.size() - _failed
	report["failed"] = _failed
	report["manual_playtest"] = false
	var directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	var output: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		_failed += 1
		push_error("Cannot write font validation evidence to artifacts/.")
	else:
		output.store_string(JSON.stringify(report, "\t", true))
		output.close()
	print("Font checks: %d passed, %d failed; missing glyphs: %s" % [_checks.size() - _failed, _failed, str(report.get("missing", []))])
	print("Font metrics: ", JSON.stringify(report.get("metrics", {})))
	quit(0 if _failed == 0 else 1)
