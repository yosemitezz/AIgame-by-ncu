extends Control
class_name BattleHUD
## Presentation-only HUD. Never owns HP/phase; only mirrors payloads from the game root.
## Expected signal (COLLABORATION.md): hud_updated(state: Dictionary)

signal request_pause
signal request_retry
signal request_quit_to_title

@onready var _hp_fill: ColorRect = %HpFill
@onready var _mp_fill: ColorRect = %MpFill
@onready var _boss_fill: ColorRect = %BossFill
@onready var _hp_label: Label = %HpLabel
@onready var _mp_label: Label = %MpLabel
@onready var _boss_label: Label = %BossLabel
@onready var _zone_label: Label = %ZoneLabel
@onready var _section_label: Label = %SectionLabel
@onready var _beat_label: Label = %BeatLabel
@onready var _hint_label: Label = %HintLabel
@onready var _phase_pips: HBoxContainer = %PhasePips
@onready var _outcome: Label = %OutcomeLabel

var _hp_max_width := 180.0
var _mp_max_width := 140.0
var _boss_max_width := 420.0


func _ready() -> void:
	theme = PixelThemeFactory.make()
	_hp_max_width = _hp_fill.size.x if _hp_fill.size.x > 1.0 else 180.0
	_mp_max_width = _mp_fill.size.x if _mp_fill.size.x > 1.0 else 140.0
	_boss_max_width = _boss_fill.size.x if _boss_fill.size.x > 1.0 else 420.0
	_outcome.visible = false


func bind_game(game: Object) -> void:
	## Wire from Integration when root exists. Safe no-op if signal missing.
	if game == null:
		return
	if game.has_signal("hud_updated"):
		game.connect("hud_updated", apply_state)
	if game.has_signal("boss_phase_changed"):
		game.connect("boss_phase_changed", _on_boss_phase)
	if game.has_signal("warning_issued"):
		game.connect("warning_issued", _on_warning)


func apply_state(state: Dictionary) -> void:
	var hp := float(state.get("hp", 0))
	var max_hp := maxf(float(state.get("max_hp", 1)), 1.0)
	var mp := float(state.get("mp", 0))
	var max_mp := maxf(float(state.get("max_mp", 1)), 1.0)
	var boss_hp := float(state.get("boss_hp", 0))
	var boss_max := maxf(float(state.get("boss_max", 1)), 1.0)

	_hp_fill.size.x = _hp_max_width * clampf(hp / max_hp, 0.0, 1.0)
	_mp_fill.size.x = _mp_max_width * clampf(mp / max_mp, 0.0, 1.0)
	_boss_fill.size.x = _boss_max_width * clampf(boss_hp / boss_max, 0.0, 1.0)
	_hp_label.text = "HP %d/%d" % [int(hp), int(max_hp)]
	_mp_label.text = "MP %d/%d" % [int(mp), int(max_mp)]
	_boss_label.text = str(state.get("boss_name", "BOSS"))
	_zone_label.text = str(state.get("zone", ""))
	_section_label.text = "MUSIC %s" % str(state.get("section", "fixed")).to_upper()
	_beat_label.text = "BEAT %s" % str(state.get("beat", 0))
	_hint_label.text = str(state.get("hint", ""))
	_set_phase_pips(str(state.get("phase", "I")))
	var outcome := str(state.get("outcome", ""))
	_outcome.visible = outcome != ""
	_outcome.text = outcome


func _set_phase_pips(phase: String) -> void:
	var active := 1
	match phase:
		"I", "1": active = 1
		"II", "2": active = 2
		"III", "3": active = 3
		_: active = 1
	var i := 0
	for child in _phase_pips.get_children():
		i += 1
		if child is ColorRect:
			(child as ColorRect).color = Color("e0b048") if i <= active else Color("4a4456")


func _on_boss_phase(phase: String) -> void:
	_set_phase_pips(phase)
	_hint_label.text = "Phase %s" % phase


func _on_warning(kind: String, _at: Vector2, _duration: float) -> void:
	_hint_label.text = "WARN: %s" % kind
