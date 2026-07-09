class_name WoodenButton
extends TextureButton

@export var label_text: String = "Button":
	set(value):
		label_text = value
		_update_label()

## When true, label is centered on the raised wood face (excludes bottom lip/thickness).
## When false, uses the previous full-hitbox layout (kept for Save and Quit).
@export var center_on_visual_face: bool = true:
	set(value):
		center_on_visual_face = value
		_apply_label_layout()
		_update_label()

@onready var _label: Label = $Label

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0
const HOLD_CANCEL_SEC := 2.0
const LONG_LABEL_CHARS := 12
const REFERENCE_SIZE := Vector2(505.0, 260.0)
const SHORT_FONT_SIZE := 140
const LONG_FONT_SIZE := 110

# Face-aware layout: the art's clickable top surface sits above the 3D bottom lip.
const FACE_INSET_X := 0.06
const FACE_TOP := 0.08
const FACE_BOTTOM := 0.72

# Legacy full-control layout (pre face-centering pass).
const LEGACY_ANCHOR_LEFT := 0.04
const LEGACY_ANCHOR_TOP := 0.10
const LEGACY_ANCHOR_RIGHT := 0.96
const LEGACY_ANCHOR_BOTTOM := 0.90
const LEGACY_Y_OFFSET := -15.0

var _base_scale := Vector2.ONE
var _holding: bool = false
var _hold_cancelled: bool = false
var _hold_timer: SceneTreeTimer = null
var _scale_tween: Tween = null
var _keyboard_held: bool = false


func _ready() -> void:
	if custom_minimum_size.length_squared() < 1.0:
		custom_minimum_size = size
	_update_pivot()
	_base_scale = scale
	# Fire pressed on release so we can cancel a long hold.
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)
	resized.connect(_on_resized)
	_apply_label_layout()
	_update_label()


func _on_resized() -> void:
	_update_pivot()
	_apply_label_layout()
	_update_label()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _apply_label_layout() -> void:
	if _label == null:
		return
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	if center_on_visual_face:
		_label.anchor_left = FACE_INSET_X
		_label.anchor_top = FACE_TOP
		_label.anchor_right = 1.0 - FACE_INSET_X
		_label.anchor_bottom = FACE_BOTTOM
		_label.offset_left = 0.0
		_label.offset_right = 0.0
		_label.offset_top = 0.0
		_label.offset_bottom = 0.0
	else:
		_label.anchor_left = LEGACY_ANCHOR_LEFT
		_label.anchor_top = LEGACY_ANCHOR_TOP
		_label.anchor_right = LEGACY_ANCHOR_RIGHT
		_label.anchor_bottom = LEGACY_ANCHOR_BOTTOM
		_label.offset_left = 0.0
		_label.offset_right = 0.0
		_label.offset_top = LEGACY_Y_OFFSET
		_label.offset_bottom = LEGACY_Y_OFFSET
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _update_label() -> void:
	if _label == null:
		return
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
		if label_text.length() > LONG_LABEL_CHARS
		else TextServer.AUTOWRAP_OFF
	)
	var base_size := LONG_FONT_SIZE if label_text.length() > LONG_LABEL_CHARS else SHORT_FONT_SIZE
	var scale_factor := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	_label.add_theme_font_size_override("font_size", maxi(18, int(base_size * scale_factor)))


func set_base_scale(rest: Vector2) -> void:
	_base_scale = rest
	if not _holding and not _keyboard_held:
		scale = rest
	_update_pivot()


func _on_mouse_entered() -> void:
	if _holding or _keyboard_held or disabled:
		return
	_tween_scale(_base_scale * HOVER_SCALE)


func _on_mouse_exited() -> void:
	if _holding or _keyboard_held:
		return
	_tween_scale(_base_scale)


func _on_button_down() -> void:
	if disabled:
		return
	_holding = true
	_hold_cancelled = false
	_update_pivot()
	# Pressed look: snap toward rest after a hover pop.
	_tween_scale(_base_scale * HOVER_SCALE)
	_hold_timer = get_tree().create_timer(HOLD_CANCEL_SEC)
	_hold_timer.timeout.connect(_on_hold_timeout, CONNECT_ONE_SHOT)


func _on_hold_timeout() -> void:
	if not _holding or _hold_cancelled:
		return
	_hold_cancelled = true
	_tween_scale(_base_scale)
	# Abort press so ACTION_MODE_BUTTON_RELEASE won't fire pressed.
	var was_disabled := disabled
	disabled = true
	await get_tree().process_frame
	if is_instance_valid(self):
		disabled = was_disabled
		_holding = false


func _on_button_up() -> void:
	_holding = false
	_hold_timer = null
	if _hold_cancelled:
		_hold_cancelled = false
		_tween_scale(_base_scale)
		return
	if not _keyboard_held:
		_tween_scale(_base_scale)


func _on_pressed() -> void:
	# Fired on release when hold was not cancelled.
	if _hold_cancelled:
		return
	scale = _base_scale


## Keyboard: hold starts (pressed look) / cancels / activates.
func on_keyboard_feedback(phase: StringName) -> void:
	match phase:
		&"started":
			_keyboard_held = true
			_update_pivot()
			_tween_scale(_base_scale * HOVER_SCALE)
		&"cancelled":
			_keyboard_held = false
			_tween_scale(_base_scale)
		&"activated":
			_keyboard_held = false
			_tween_scale(_base_scale * HOVER_SCALE)
			var tween := create_tween()
			tween.tween_property(self, "scale", _base_scale, 0.07)


func play_press_feedback() -> void:
	on_keyboard_feedback(&"activated")


func _tween_scale(target: Vector2) -> void:
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target, 1.0 / SCALE_SPEED)
