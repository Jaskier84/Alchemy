class_name CookbookOverlay
extends CanvasLayer
## Fullscreen codex of all ingredients, sorted by cost then name.
## Grid shows art/silhouettes only; discovered entries hover a full scroll card.

const _ENTRY_SCENE := preload("res://scenes/ui/cookbook_entry.tscn")
const _CookbookProgress := preload("res://scripts/persistence/cookbook_progress.gd")

## Leave room at edges so the floating scroll card can fully fit.
const PANEL_MARGIN := Vector2(56.0, 48.0)
const GRID_COLUMNS := 8
const GRID_H_SEP := 18.0
const GRID_V_SEP := 18.0
const ENTRY_MIN := 72.0
const ENTRY_MAX := 112.0
const PREVIEW_SCALE := 0.36
const PREVIEW_MARGIN := 20.0

@onready var _root: Control = $OverlayRoot
@onready var _input_blocker: ColorRect = $OverlayRoot/InputBlocker
@onready var _panel: PanelContainer = $OverlayRoot/Panel
@onready var _title_label: Label = $OverlayRoot/Panel/Content/Title
@onready var _scroll: ScrollContainer = $OverlayRoot/Panel/Content/Scroll
@onready var _grid: GridContainer = $OverlayRoot/Panel/Content/Scroll/Grid
@onready var _close_button: Button = $OverlayRoot/Panel/Content/CloseButton
@onready var _preview_layer: CanvasLayer = $PreviewLayer
@onready var _preview_card: IngredientCard = $PreviewLayer/PreviewCard

var _hovered_entry: CookbookEntry
var _preview_rest_position := Vector2.ZERO
var _entry_size := Vector2(88.0, 88.0)
var _grid_built: bool = false
var _last_discovery_count: int = -1


func _ready() -> void:
	layer = 130
	follow_viewport_enabled = true
	visible = false
	_apply_panel_margins()
	if _grid != null:
		_grid.columns = GRID_COLUMNS
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_theme_constant_override("h_separation", int(GRID_H_SEP))
		_grid.add_theme_constant_override("v_separation", int(GRID_V_SEP))
	if _scroll != null:
		_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if not _scroll.resized.is_connected(_on_scroll_resized):
			_scroll.resized.connect(_on_scroll_resized)
		var vbar := _scroll.get_v_scroll_bar()
		if vbar != null and not vbar.value_changed.is_connected(_on_scroll_changed):
			vbar.value_changed.connect(_on_scroll_changed)
	if _close_button != null and not _close_button.pressed.is_connected(hide_overlay):
		_close_button.pressed.connect(hide_overlay)
	if _input_blocker != null and not _input_blocker.gui_input.is_connected(_on_blocker_gui_input):
		_input_blocker.gui_input.connect(_on_blocker_gui_input)
	_setup_preview_card()
	set_process(false)


func _apply_panel_margins() -> void:
	if _panel == null:
		return
	_panel.offset_left = PANEL_MARGIN.x
	_panel.offset_top = PANEL_MARGIN.y
	_panel.offset_right = -PANEL_MARGIN.x
	_panel.offset_bottom = -PANEL_MARGIN.y


func _setup_preview_card() -> void:
	if _preview_layer != null:
		_preview_layer.layer = layer + 5
		_preview_layer.visible = false
	if _preview_card == null:
		return
	_preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_card.focus_mode = Control.FOCUS_NONE
	_preview_card.disabled = true
	_preview_card.set_external_icon_strip(true)
	_preview_card.scale = Vector2.ONE * PREVIEW_SCALE
	_preview_rest_position = _preview_card.position
	_hide_preview()


func open_cookbook() -> void:
	_ensure_grid()
	visible = true
	if _root != null:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	call_deferred("_relayout_grid")


func hide_overlay() -> void:
	visible = false
	if _root != null:
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_hide_preview()
	# Keep the grid — rebuilding 40+ tiles every open was a major hitch.


func is_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	if not visible or _hovered_entry == null:
		return
	if not is_instance_valid(_hovered_entry):
		_hide_preview()
		return
	# Keep preview attached while still over the entry rect.
	if not _hovered_entry.get_global_rect().has_point(get_viewport().get_mouse_position()):
		# Allow a bit of leeway while over the floating card.
		if _preview_card != null and _preview_card.visible:
			if _preview_card.get_global_rect().has_point(get_viewport().get_mouse_position()):
				return
		_hide_preview()
		return
	_align_preview_to_entry(_hovered_entry)


func _ensure_grid() -> void:
	var discovery_count := _CookbookProgress.discovered_count()
	if _grid_built and _grid != null and _grid.get_child_count() > 0:
		if discovery_count != _last_discovery_count:
			_refresh_discovery_states()
			_last_discovery_count = discovery_count
		return
	_rebuild()
	_last_discovery_count = discovery_count


func _rebuild() -> void:
	_clear_grid()
	_hide_preview()
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
	_compute_entry_size()
	for item in ingredients:
		if item == null or not (item is IngredientData):
			continue
		var ingredient := item as IngredientData
		var entry := _ENTRY_SCENE.instantiate() as CookbookEntry
		if entry == null:
			continue
		_grid.add_child(entry)
		entry.bind(ingredient, _CookbookProgress.is_discovered(ingredient.id))
		entry.apply_tile_size(_entry_size)
		if not entry.hover_started.is_connected(_on_entry_hover_started):
			entry.hover_started.connect(_on_entry_hover_started)
		if not entry.hover_ended.is_connected(_on_entry_hover_ended):
			entry.hover_ended.connect(_on_entry_hover_ended)
	_force_grid_fill_width()
	_grid_built = true


func _refresh_discovery_states() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		var entry := child as CookbookEntry
		if entry == null:
			continue
		var ingredient := entry.get_ingredient()
		if ingredient == null:
			continue
		entry.set_discovered(_CookbookProgress.is_discovered(ingredient.id))


func _sort_ingredients(a: IngredientData, b: IngredientData) -> bool:
	if a.shop_cost != b.shop_cost:
		return a.shop_cost < b.shop_cost
	return a.display_name.to_lower() < b.display_name.to_lower()


func _clear_grid() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	_hovered_entry = null
	_grid_built = false


func _on_scroll_resized() -> void:
	if not visible:
		return
	_relayout_grid()


func _relayout_grid() -> void:
	if _grid == null or not visible:
		return
	_compute_entry_size()
	_force_grid_fill_width()
	for child in _grid.get_children():
		var entry := child as CookbookEntry
		if entry != null:
			entry.apply_tile_size(_entry_size)


func _compute_entry_size() -> void:
	var avail_w := 0.0
	if _scroll != null and _scroll.size.x > 1.0:
		# Reserve a little room for the vertical scrollbar.
		avail_w = maxf(0.0, _scroll.size.x - 12.0)
	elif _panel != null:
		avail_w = maxf(0.0, _panel.size.x - 64.0)
	else:
		avail_w = 800.0
	var cols := maxi(1, GRID_COLUMNS)
	var cell := (avail_w - GRID_H_SEP * float(cols - 1)) / float(cols)
	cell = clampf(cell, ENTRY_MIN, ENTRY_MAX)
	_entry_size = Vector2(cell, cell)


func _force_grid_fill_width() -> void:
	## GridContainer inside ScrollContainer only sizes to content min width by
	## default, which packs tiles to the left half. Size the grid to the full
	## scroll width (matched by entry cell size) so icons span the window.
	if _grid == null or _scroll == null:
		return
	var content_w := _entry_size.x * float(GRID_COLUMNS) + GRID_H_SEP * float(GRID_COLUMNS - 1)
	var target_w := content_w
	if _scroll.size.x > 1.0:
		target_w = maxf(content_w, _scroll.size.x - 12.0)
	_grid.custom_minimum_size = Vector2(target_w, 0.0)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_entry_hover_started(entry: CookbookEntry) -> void:
	if entry == null or not entry.is_discovered():
		_hide_preview()
		return
	_hovered_entry = entry
	_show_preview(entry.get_ingredient())
	_align_preview_to_entry(entry)


func _on_entry_hover_ended(entry: CookbookEntry) -> void:
	if _hovered_entry == entry:
		# Delay hide slightly so moving onto the preview card doesn't flicker.
		call_deferred("_maybe_hide_preview_after_exit")


func _maybe_hide_preview_after_exit() -> void:
	if _hovered_entry == null:
		return
	var mouse := get_viewport().get_mouse_position()
	if _hovered_entry.get_global_rect().has_point(mouse):
		return
	if _preview_card != null and _preview_card.visible and _preview_card.get_global_rect().has_point(mouse):
		return
	_hide_preview()


func _show_preview(ingredient: IngredientData) -> void:
	if _preview_layer == null or _preview_card == null or ingredient == null:
		return
	_preview_card.bind_preview(ingredient, true)
	_preview_card.visible = true
	_preview_layer.visible = true


func _hide_preview() -> void:
	_hovered_entry = null
	if _preview_card != null:
		_preview_card.visible = false
	if _preview_layer != null:
		_preview_layer.visible = false


func _align_preview_to_entry(entry: CookbookEntry) -> void:
	if _preview_card == null or entry == null or not _preview_card.visible:
		return
	_preview_card.position = _preview_rest_position
	var entry_center := entry.get_art_center_global()
	var preview_art_center := _preview_card.get_art_global_center()
	_preview_card.global_position += entry_center - preview_art_center
	_clamp_preview_to_viewport()


func _clamp_preview_to_viewport() -> void:
	if _preview_card == null:
		return
	var rect := _preview_card.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	var delta := Vector2.ZERO
	if rect.position.x < PREVIEW_MARGIN:
		delta.x = PREVIEW_MARGIN - rect.position.x
	elif rect.end.x > viewport_size.x - PREVIEW_MARGIN:
		delta.x = (viewport_size.x - PREVIEW_MARGIN) - rect.end.x
	if rect.position.y < PREVIEW_MARGIN:
		delta.y = PREVIEW_MARGIN - rect.position.y
	elif rect.end.y > viewport_size.y - PREVIEW_MARGIN:
		delta.y = (viewport_size.y - PREVIEW_MARGIN) - rect.end.y
	_preview_card.global_position += delta


func _on_scroll_changed(_value: float) -> void:
	_hide_preview()


func _on_blocker_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			hide_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_overlay()
		get_viewport().set_input_as_handled()
