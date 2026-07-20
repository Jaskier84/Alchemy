class_name CursorTooltip
extends CanvasLayer
## Lightweight cursor-following label for compact HUD buttons.

const OFFSET := Vector2(14.0, 18.0)

var _label: Label
var _active: bool = false


func _ready() -> void:
	layer = 200
	follow_viewport_enabled = true
	_label = Label.new()
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 1))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
	set_process(false)


func show_tip(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = true
	_active = true
	set_process(true)
	_follow_cursor()


func hide_tip() -> void:
	_active = false
	set_process(false)
	if _label != null:
		_label.visible = false


func _process(_delta: float) -> void:
	if not _active:
		return
	_follow_cursor()


func _follow_cursor() -> void:
	if _label == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var size := _label.get_minimum_size()
	var pos := mouse + OFFSET
	var viewport_size := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, viewport_size.x - size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, viewport_size.y - size.y - 4.0))
	_label.position = pos
