class_name BagInventorySlot
extends Control

const ART_SIZE := Vector2(72.0, 72.0)
const DEFAULT_SLOT_SIZE := Vector2(88.0, 88.0)
const SELL_SLOT_SIZE := Vector2(88.0, 108.0)
const SELECTED_MODULATE := Color(1.15, 1.08, 0.75, 1.0)

@onready var _art: TextureRect = $Art
@onready var _count_label: Label = $CountLabel
@onready var _value_label: Label = get_node_or_null("ValueLabel") as Label
@onready var _selection_frame: ColorRect = get_node_or_null("SelectionFrame") as ColorRect

signal slot_gui_input(event: InputEvent)

const _TRINKET_ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"

var _pending_ingredient: IngredientData
var _pending_trinket: TrinketData
var _pending_count: int = 0
var _show_count: bool = true
var _interactive: bool = false
var _show_sell_value: bool = false
var _sell_value: int = 0
var _selected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_sync_art_layout)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	_ensure_value_label()
	_ensure_selection_frame()
	_refresh_display()


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _on_gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	slot_gui_input.emit(event)
	accept_event()


func bind_entry(ingredient: IngredientData, count: int, show_count: bool = true) -> void:
	_pending_trinket = null
	_clear_trinket_meta()
	_pending_ingredient = ingredient
	_pending_count = count
	_show_count = show_count
	_store_ingredient(ingredient)
	_refresh_display()


func bind_trinket(trinket: TrinketData, selected: bool, show_selection: bool = true) -> void:
	_pending_ingredient = null
	_clear_ingredient_meta()
	_pending_trinket = trinket
	_pending_count = 1 if selected else 0
	_show_count = show_selection
	_show_sell_value = false
	_selected = false
	_store_trinket(trinket)
	_refresh_display()


func set_sell_value_display(value: int, enabled: bool) -> void:
	_show_sell_value = enabled
	_sell_value = maxi(0, value)
	_apply_slot_size()
	_refresh_value_label()
	call_deferred("_sync_art_layout")


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_selection_visual()


func is_selected() -> bool:
	return _selected


func _refresh_display() -> void:
	_resolve_nodes()
	_apply_slot_size()
	if _pending_trinket != null:
		if _count_label != null:
			_count_label.visible = _show_count and _pending_count > 0
			_count_label.text = str(_pending_count)
		_apply_trinket_art(_pending_trinket)
		_refresh_value_label()
		_apply_selection_visual()
		call_deferred("_sync_art_layout")
		return
	if _pending_ingredient == null:
		return
	if _count_label != null:
		_count_label.visible = _show_count
		_count_label.text = str(maxi(1, _pending_count))
	_apply_art(_pending_ingredient)
	_refresh_value_label()
	_apply_selection_visual()
	call_deferred("_sync_art_layout")


func _apply_slot_size() -> void:
	var target := SELL_SLOT_SIZE if _show_sell_value else DEFAULT_SLOT_SIZE
	custom_minimum_size = target
	size = target


func _refresh_value_label() -> void:
	_ensure_value_label()
	if _value_label == null:
		return
	if not _show_sell_value:
		_value_label.visible = false
		return
	_value_label.visible = true
	_value_label.text = str(_sell_value)


func _apply_selection_visual() -> void:
	_ensure_selection_frame()
	if _selection_frame != null:
		_selection_frame.visible = _selected
	modulate = SELECTED_MODULATE if _selected else Color.WHITE


func _resolve_nodes() -> void:
	if _art == null:
		_art = get_node_or_null("Art") as TextureRect
	if _count_label == null:
		_count_label = get_node_or_null("CountLabel") as Label
	if _value_label == null:
		_value_label = get_node_or_null("ValueLabel") as Label
	if _selection_frame == null:
		_selection_frame = get_node_or_null("SelectionFrame") as ColorRect


func _ensure_value_label() -> void:
	if _value_label != null and is_instance_valid(_value_label):
		return
	_value_label = get_node_or_null("ValueLabel") as Label
	if _value_label != null:
		return
	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3, 1.0))
	_value_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	_value_label.add_theme_constant_override("outline_size", 3)
	_value_label.add_theme_font_size_override("font_size", 16)
	add_child(_value_label)


func _ensure_selection_frame() -> void:
	if _selection_frame != null and is_instance_valid(_selection_frame):
		return
	_selection_frame = get_node_or_null("SelectionFrame") as ColorRect
	if _selection_frame != null:
		return
	_selection_frame = ColorRect.new()
	_selection_frame.name = "SelectionFrame"
	_selection_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_frame.color = Color(0.95, 0.78, 0.25, 0.28)
	_selection_frame.visible = false
	_selection_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_selection_frame)
	move_child(_selection_frame, 0)


func get_art_center_global() -> Vector2:
	if _art != null:
		return _art.get_global_rect().get_center()
	return get_global_rect().get_center()


func _apply_art(ingredient: IngredientData) -> void:
	if _art == null or ingredient == null:
		return
	var art_path := "res://assets/cards/ingredients/%s.png" % ingredient.get_art_filename()
	if ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
		_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art.modulate = Color.WHITE
		_art.visible = true
	else:
		_art.texture = null
		_art.modulate = Color(0.35, 0.38, 0.45, 1.0)
		_art.visible = false


func _apply_trinket_art(trinket: TrinketData) -> void:
	if _art == null or trinket == null:
		return
	var art_path := _TRINKET_ART_PATH_TEMPLATE % trinket.get_art_filename()
	if ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
		_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art.modulate = Color.WHITE
		_art.visible = true
	else:
		_art.texture = null
		_art.modulate = Color(0.35, 0.38, 0.45, 1.0)
		_art.visible = false


func _sync_art_layout() -> void:
	if _art == null:
		return
	var host_size := size
	var art_top := 4.0 if _show_sell_value else (host_size.y - ART_SIZE.y) * 0.5
	var art_pos := Vector2((host_size.x - ART_SIZE.x) * 0.5, art_top)
	_art.position = art_pos
	_art.size = ART_SIZE
	if _value_label != null and _show_sell_value:
		_value_label.position = Vector2(0.0, art_pos.y + ART_SIZE.y + 1.0)
		_value_label.size = Vector2(host_size.x, 22.0)


func get_ingredient() -> IngredientData:
	if not has_meta("ingredient"):
		return null
	return get_meta("ingredient") as IngredientData


func get_trinket() -> TrinketData:
	if not has_meta("trinket"):
		return null
	return get_meta("trinket") as TrinketData


func get_count() -> int:
	return _pending_count


func set_count_visible(show_count: bool) -> void:
	_resolve_nodes()
	if _count_label != null:
		_count_label.visible = show_count and _show_count


func _store_ingredient(ingredient: IngredientData) -> void:
	set_meta("ingredient", ingredient)


func _store_trinket(trinket: TrinketData) -> void:
	set_meta("trinket", trinket)


func _clear_ingredient_meta() -> void:
	if has_meta("ingredient"):
		remove_meta("ingredient")


func _clear_trinket_meta() -> void:
	if has_meta("trinket"):
		remove_meta("trinket")
