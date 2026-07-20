class_name CookbookButton
extends TextureButton
## Compact book control that opens the cookbook overlay.

signal open_requested

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0

@export var tooltip_host: CursorTooltip
@export var tip_text: String = "Cookbook"

var _base_scale := Vector2.ONE


func _ready() -> void:
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


func _on_resized() -> void:
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _on_mouse_entered() -> void:
	if disabled:
		return
	_tween_scale(_base_scale * HOVER_SCALE)
	if tooltip_host != null:
		tooltip_host.show_tip(tip_text)


func _on_mouse_exited() -> void:
	_tween_scale(_base_scale)
	if tooltip_host != null:
		tooltip_host.hide_tip()


func _on_pressed() -> void:
	scale = _base_scale
	if tooltip_host != null:
		tooltip_host.hide_tip()
	open_requested.emit()


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / SCALE_SPEED)
