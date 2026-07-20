class_name SettingsGearButton
extends TextureButton
## Compact gear control that opens the global Settings overlay.

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0

@export var tooltip_host: CursorTooltip
@export var tip_text: String = "Settings"

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
	_apply_click_mask()


func _apply_click_mask() -> void:
	## Visual hole stays transparent, but the center still counts as hover/click.
	if texture_normal == null:
		return
	var image: Image = texture_normal.get_image()
	if image == null or image.is_empty():
		return
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()
	var mask := BitMap.new()
	mask.create_from_image_alpha(image, 0.1)
	_fill_enclosed_transparent_center(mask, image)
	texture_click_mask = mask


func _fill_enclosed_transparent_center(mask: BitMap, image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return
	var start := Vector2i(width / 2, height / 2)
	if start.x < 0 or start.y < 0 or start.x >= width or start.y >= height:
		return
	# Already solid at center — nothing to fill.
	if mask.get_bit(start.x, start.y):
		return
	var stack: Array[Vector2i] = [start]
	var seen := {}
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= width or p.y >= height:
			continue
		var key := p.x + p.y * width
		if seen.has(key):
			continue
		seen[key] = true
		# Stop at opaque gear body — only fill the enclosed transparent hole.
		if mask.get_bit(p.x, p.y):
			continue
		mask.set_bit(p.x, p.y, true)
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))


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
	Settings.open()


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / SCALE_SPEED)
