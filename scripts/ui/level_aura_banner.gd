class_name LevelAuraBanner
extends Control

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")

const CONTENT_LEFT := 14.0
const CONTENT_RIGHT := 292.0

# Fixed geometry — description keeps full readable size; counter sits under it.
# Banner instances are taller than 106 (parent offsets ≈ 152px), so we use that room.
const LEVEL_TOP := 6.0
const LEVEL_BOTTOM := 32.0
const LEVEL_FONT := 22
const NAME_TOP := 30.0
const NAME_BOTTOM := 58.0
const NAME_FONT := 24
const DESC_TOP := 56.0
const DESC_BOTTOM := 100.0
const DESC_FONT := 16
const COUNT_TOP := 100.0
const COUNT_BOTTOM := 140.0
const COUNT_NUM_FONT := 34
const COUNT_CAP_FONT := 18

@onready var _level_label: Label = $LevelLabel
@onready var _aura_name_label: Label = $AuraNameLabel
@onready var _aura_description_label: Label = $AuraDescriptionLabel
@onready var _countdown_row: HBoxContainer = $AuraCountdownRow
@onready var _countdown_label: Label = $AuraCountdownRow/AuraCountdownLabel
@onready var _countdown_caption: Label = $AuraCountdownRow/AuraCountdownCaption
@onready var _practice_restart_button: Control = $PracticeRestartButton

var _preview_mode: bool = false


func _ready() -> void:
	_connect_refresh_signals()
	# Clip only the description box so wrap stays inside its rect — not so short
	# that multi-line aura text disappears.
	if _aura_description_label != null:
		_aura_description_label.clip_contents = true
		_aura_description_label.clip_text = false
	_apply_stable_layout()
	call_deferred("refresh_interval_countdown")


func _connect_refresh_signals() -> void:
	if not GameManager.run_changed.is_connected(_on_run_changed):
		GameManager.run_changed.connect(_on_run_changed)
	if not GameManager.brew_updated.is_connected(_on_brew_updated):
		GameManager.brew_updated.connect(_on_brew_updated)
	if not GameManager.brew_stats_presented.is_connected(_on_brew_stats_presented):
		GameManager.brew_stats_presented.connect(_on_brew_stats_presented)
	if not GameManager.presentation_idle.is_connected(_on_presentation_idle):
		GameManager.presentation_idle.connect(_on_presentation_idle)


func _on_run_changed() -> void:
	refresh_interval_countdown()


func _on_brew_updated(_ctx: BrewContext) -> void:
	# Don't tick In Rhythm / Bubbling Brew countdown when a card is only just applied;
	# wait for the card to present (land) so the number matches the visible cauldron.
	if GameManager.is_presentation_in_progress():
		return
	refresh_interval_countdown()


func _on_brew_stats_presented(_ctx: BrewContext) -> void:
	refresh_interval_countdown()


func _on_presentation_idle() -> void:
	refresh_interval_countdown()


func bind_preview(level: int, aura: AuraData) -> void:
	_preview_mode = true
	if _level_label != null:
		_level_label.text = "Level %d" % level
	if aura == null:
		if _aura_name_label != null:
			_aura_name_label.text = ""
		if _aura_description_label != null:
			_aura_description_label.text = ""
		modulate = Color.WHITE
	else:
		if _aura_name_label != null:
			_aura_name_label.text = aura.display_name
		var is_boss := GameConstants.is_boss_level(level)
		if _aura_description_label != null:
			if is_boss:
				_aura_description_label.text = (
					"%s\n%s" % [aura.description, GameConstants.BOSS_AURA_WARNING]
				)
			else:
				_aura_description_label.text = aura.description
		modulate = Color(1.0, 0.58, 0.58, 1.0) if is_boss else Color.WHITE
	if _countdown_row != null:
		_countdown_row.visible = false
	if _practice_restart_button != null:
		_practice_restart_button.visible = false
	_apply_stable_layout()


func refresh_interval_countdown() -> void:
	if _preview_mode:
		return
	var show_countdown := false
	var countdown := 0
	if GameManager.run != null and GameManager.run.brew_session != null:
		var session := GameManager.run.brew_session
		var aura: AuraData = session.context.current_aura
		if (
			session.context.outcome == BrewOutcome.Outcome.IN_PROGRESS
			and _AuraEffects.uses_interval_countdown(aura)
		):
			countdown = session.get_aura_interval_countdown()
			show_countdown = countdown > 0
	if _countdown_label != null and show_countdown:
		_countdown_label.text = str(countdown)
	if _countdown_row != null:
		_countdown_row.visible = show_countdown
	_apply_stable_layout()


func _apply_stable_layout() -> void:
	_place_label(_level_label, LEVEL_TOP, LEVEL_BOTTOM, LEVEL_FONT)
	_place_label(_aura_name_label, NAME_TOP, NAME_BOTTOM, NAME_FONT)
	_place_label(_aura_description_label, DESC_TOP, DESC_BOTTOM, DESC_FONT)

	if _countdown_row != null:
		_countdown_row.offset_left = CONTENT_LEFT
		_countdown_row.offset_right = CONTENT_RIGHT
		_countdown_row.offset_top = COUNT_TOP
		_countdown_row.offset_bottom = COUNT_BOTTOM
		_countdown_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if _countdown_label != null:
		_countdown_label.add_theme_font_size_override("font_size", COUNT_NUM_FONT)
	if _countdown_caption != null:
		_countdown_caption.add_theme_font_size_override("font_size", COUNT_CAP_FONT)


func _place_label(label: Label, top: float, bottom: float, font_size: int) -> void:
	if label == null:
		return
	label.offset_left = CONTENT_LEFT
	label.offset_right = CONTENT_RIGHT
	label.offset_top = top
	label.offset_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", font_size)
