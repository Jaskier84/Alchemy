class_name CookbookOverlay
extends CanvasLayer
## Fullscreen codex of all ingredients, sorted by cost then name.

const _ENTRY_SCENE := preload("res://scenes/ui/cookbook_entry.tscn")
const _CookbookProgress := preload("res://scripts/persistence/cookbook_progress.gd")
const GRID_COLUMNS := 8

@onready var _root: Control = $OverlayRoot
@onready var _input_blocker: ColorRect = $OverlayRoot/InputBlocker
@onready var _title_label: Label = $OverlayRoot/Panel/Content/Title
@onready var _scroll: ScrollContainer = $OverlayRoot/Panel/Content/Scroll
@onready var _grid: GridContainer = $OverlayRoot/Panel/Content/Scroll/Grid
@onready var _close_button: Button = $OverlayRoot/Panel/Content/CloseButton

func _ready() -> void:
	layer = 130
	follow_viewport_enabled = true
	visible = false
	if _grid != null:
		_grid.columns = GRID_COLUMNS
	if _close_button != null and not _close_button.pressed.is_connected(hide_overlay):
		_close_button.pressed.connect(hide_overlay)
	if _input_blocker != null and not _input_blocker.gui_input.is_connected(_on_blocker_gui_input):
		_input_blocker.gui_input.connect(_on_blocker_gui_input)


func open_cookbook() -> void:
	_rebuild()
	visible = true
	if _root != null:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP


func hide_overlay() -> void:
	visible = false
	if _root != null:
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_grid()


func is_open() -> bool:
	return visible


func _rebuild() -> void:
	_clear_grid()
	if _grid == null:
		return
	var ingredients: Array = []
	if GameManager != null and GameManager.has_method("get_all_ingredients"):
		ingredients = GameManager.get_all_ingredients()
	else:
		ingredients = DefaultContent.create().all_ingredients()
	ingredients.sort_custom(_sort_ingredients)
	if _title_label != null:
		_title_label.text = "Cookbook"
	for item in ingredients:
		if item == null or not (item is IngredientData):
			continue
		var ingredient := item as IngredientData
		var entry := _ENTRY_SCENE.instantiate() as CookbookEntry
		if entry == null:
			continue
		_grid.add_child(entry)
		entry.bind(ingredient, _CookbookProgress.is_discovered(ingredient.id))


func _sort_ingredients(a: IngredientData, b: IngredientData) -> bool:
	if a.shop_cost != b.shop_cost:
		return a.shop_cost < b.shop_cost
	return a.display_name.to_lower() < b.display_name.to_lower()


func _clear_grid() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()


func _on_blocker_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			# Clicking dimmer outside panel closes; panel stops propagation itself.
			hide_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_overlay()
		get_viewport().set_input_as_handled()
