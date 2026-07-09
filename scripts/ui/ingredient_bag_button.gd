class_name IngredientBagButton
extends TextureButton

@export var label_text: String = "Draw":
	set(value):
		label_text = value
		_update_label()

@onready var _label: Label = $Label

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0
const REFERENCE_SIZE := Vector2(256.0, 256.0)
const FONT_SIZE := 72

var _base_scale := Vector2.ONE


func _ready() -> void:
	# Preserve explicit min sizes (e.g. run-prep). Brew lays out via offsets + scale.
	z_index = 14
	if _label:
		_label.custom_minimum_size = Vector2.ZERO
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_pivot()
	_base_scale = scale
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	_apply_label_layout()
	_update_label()


func _on_resized() -> void:
	_update_pivot()
	_update_label()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


## Global rect as if scale were at rest (ignores hover grow).
## Uses parent transform + local position so current hover scale is ignored.
func get_rest_global_rect() -> Rect2:
	var parent_item := get_parent() as CanvasItem
	var parent_xf := (
		parent_item.get_global_transform()
		if parent_item != null
		else Transform2D.IDENTITY
	)
	var layout_origin := parent_xf * position
	var pivot := pivot_offset
	var top_left := layout_origin + pivot * (Vector2.ONE - _base_scale)
	return Rect2(top_left, size * _base_scale)


func _apply_label_layout() -> void:
	if _label == null:
		return
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.anchor_left = 0.08
	_label.anchor_top = 0.58
	_label.anchor_right = 0.92
	_label.anchor_bottom = 0.96
	_label.offset_left = 0.0
	_label.offset_right = 0.0
	_label.offset_top = 0.0
	_label.offset_bottom = 0.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _update_label() -> void:
	if _label == null:
		return
	_label.text = label_text
	var scale_factor := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	_label.add_theme_font_size_override("font_size", maxi(18, int(FONT_SIZE * scale_factor)))


func _on_mouse_entered() -> void:
	_tween_scale(_base_scale * HOVER_SCALE)


func _on_mouse_exited() -> void:
	_tween_scale(_base_scale)


func _on_pressed() -> void:
	scale = _base_scale


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / SCALE_SPEED)