class_name CursorTooltip
extends CanvasLayer
## Lightweight cursor-following label for compact HUD buttons and effect icons.

const OFFSET := Vector2(14.0, 18.0)
const MAX_WIDTH := 320.0
const GROUP_NAME := &"cursor_tooltip"

var _label: Label
var _active: bool = false


func _ready() -> void:
	layer = 200
	follow_viewport_enabled = true
	add_to_group(GROUP_NAME)
	_label = Label.new()
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 1))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)
	set_process(false)


func show_tip(text: String) -> void:
	if _label == null:
		return
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		hide_tip()
		return
	_label.text = cleaned
	_label.visible = true
	_active = true
	set_process(true)
	_fit_label_size()
	_follow_cursor()


func hide_tip() -> void:
	_active = false
	set_process(false)
	if _label != null:
		_label.visible = false


func _fit_label_size() -> void:
	if _label == null:
		return
	# Prefer a single line when short; wrap long ingredient/trinket blurbs.
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size = Vector2.ZERO
	_label.reset_size()
	var natural := _label.get_minimum_size()
	if natural.x <= MAX_WIDTH:
		_label.size = natural
		return
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(MAX_WIDTH, 0.0)
	_label.reset_size()
	_label.size = _label.get_minimum_size()


func _process(_delta: float) -> void:
	if not _active:
		return
	_follow_cursor()


func _follow_cursor() -> void:
	if _label == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var size := _label.size
	if size.x < 1.0 or size.y < 1.0:
		size = _label.get_minimum_size()
	var pos := mouse + OFFSET
	var viewport_size := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, viewport_size.x - size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, viewport_size.y - size.y - 4.0))
	_label.position = pos
