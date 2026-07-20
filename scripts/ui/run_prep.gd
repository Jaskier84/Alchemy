extends Control

@onready var _bag_button: IngredientBagButton = $RunPrepPanel/BagColumn/BagButton
@onready var _ready_button: WoodenButton = $RunPrepPanel/BagColumn/ReadyButton
@onready var _bag_contents: BagContentsOverlay = $RunPrepPanel/BagContentsOverlay
@onready var _aura_banner: LevelAuraBanner = $RunPrepPanel/LevelAuraBanner
@onready var _settings_gear_button: SettingsGearButton = $SettingsGearButton
@onready var _cookbook_button: CookbookButton = $CookbookButton
@onready var _cookbook_overlay: CookbookOverlay = $CookbookOverlay
@onready var _cursor_tooltip: CursorTooltip = $CursorTooltip


func _ready() -> void:
	print("RunPrep: prep scene loaded — press Ready to start brew")
	_configure_bag_button()
	_wire_controls()
	_wire_cookbook_and_tooltips()
	_refresh_preview()
	if GameManager != null and GameManager.run != null:
		preload("res://scripts/persistence/cookbook_progress.gd").discover_from_bag(
			GameManager.run.bag
		)


func _configure_bag_button() -> void:
	if _bag_button == null:
		return
	# Smaller than the old 280px bag so Ready sits fully above the bottom edge.
	_bag_button.custom_minimum_size = Vector2(176, 176)
	_bag_button.size = Vector2(176, 176)
	_bag_button.label_text = ""


func _wire_controls() -> void:
	if _bag_button != null and not _bag_button.pressed.is_connected(_on_bag_pressed):
		_bag_button.pressed.connect(_on_bag_pressed)
	if _ready_button != null and not _ready_button.pressed.is_connected(_on_ready_pressed):
		_ready_button.pressed.connect(_on_ready_pressed)
	if not GameManager.primary_keyboard_feedback.is_connected(_on_primary_keyboard_feedback):
		GameManager.primary_keyboard_feedback.connect(_on_primary_keyboard_feedback)


func _wire_cookbook_and_tooltips() -> void:
	if _cursor_tooltip != null:
		if _settings_gear_button != null:
			_settings_gear_button.tooltip_host = _cursor_tooltip
			_settings_gear_button.tip_text = "Settings"
		if _cookbook_button != null:
			_cookbook_button.tooltip_host = _cursor_tooltip
			_cookbook_button.tip_text = "Cookbook"
	if _cookbook_button != null and not _cookbook_button.open_requested.is_connected(_on_cookbook_pressed):
		_cookbook_button.open_requested.connect(_on_cookbook_pressed)


func _on_cookbook_pressed() -> void:
	if _cookbook_overlay == null:
		return
	if _cookbook_overlay.is_open():
		_cookbook_overlay.hide_overlay()
	else:
		_cookbook_overlay.open_cookbook()


func _on_primary_keyboard_feedback(action: StringName, phase: StringName) -> void:
	if action == &"ready" and _ready_button != null and _ready_button.has_method("on_keyboard_feedback"):
		_ready_button.on_keyboard_feedback(phase)


func _on_bag_pressed() -> void:
	if _bag_contents != null and GameManager.run != null:
		_bag_contents.toggle(GameManager.run.bag)


func _on_ready_pressed() -> void:
	print("RunPrep: Ready pressed — starting first brew")
	if _cookbook_overlay != null and _cookbook_overlay.is_open():
		_cookbook_overlay.hide_overlay()
	if _ready_button != null:
		_ready_button.disabled = true
	if not GameManager.press_ready_to_start_first_brew():
		if _ready_button != null:
			_ready_button.disabled = false
		return
	await SceneTransition.go_to(GameManager.GAME_SCENE_PATH)


func _refresh_preview() -> void:
	if _aura_banner == null or GameManager.run == null:
		return
	var run := GameManager.run
	_aura_banner.bind_preview(
		run.get_upcoming_brew_level(),
		run.ensure_aura_locked_for_upcoming_brew()
	)
