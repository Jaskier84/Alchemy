extends CanvasLayer
## Portrait settings popup. Owned by the Settings autoload.

const MOUSE_ONLY_TOOLTIP_TEXT := "disable enter and spacebar functionality"
const TOOLTIP_CURSOR_OFFSET := Vector2(14.0, 18.0)
## Final on-screen icon size (border included) — matches stock checkbox scale.
const CHECKBOX_DISPLAY_SIZE := 16
## Draw larger then downsample for smooth rounded edges.
const CHECKBOX_SUPERSAMPLE := 4

@onready var _root: Control = $OverlayRoot
@onready var _music_check: CheckBox = $OverlayRoot/Panel/Content/MusicRow/MusicCheck
@onready var _sound_check: CheckBox = $OverlayRoot/Panel/Content/SoundRow/SoundCheck
@onready var _volume_slider: HSlider = $OverlayRoot/Panel/Content/VolumeSlider
@onready var _mouse_only_row: Control = $OverlayRoot/Panel/Content/MouseOnlyRow
@onready var _mouse_only_label: Label = $OverlayRoot/Panel/Content/MouseOnlyRow/MouseOnlyLabel
@onready var _mouse_only_check: CheckBox = $OverlayRoot/Panel/Content/MouseOnlyRow/MouseOnlyCheck
@onready var _back_button: WoodenButton = $OverlayRoot/Panel/Content/BackButton
@onready var _exit_button: WoodenButton = $OverlayRoot/Panel/Content/ExitButton
@onready var _mouse_only_tooltip: Label = $OverlayRoot/MouseOnlyTooltip

var _syncing_ui: bool = false
var _tooltip_hovering: bool = false
var _checkbox_unchecked_icon: Texture2D
var _checkbox_checked_icon: Texture2D


func _ready() -> void:
	layer = 200
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_build_checkbox_icons()
	_style_all_checkboxes()
	if _music_check != null and not _music_check.toggled.is_connected(_on_music_toggled):
		_music_check.toggled.connect(_on_music_toggled)
	if _sound_check != null and not _sound_check.toggled.is_connected(_on_sound_toggled):
		_sound_check.toggled.connect(_on_sound_toggled)
	if _volume_slider != null and not _volume_slider.value_changed.is_connected(_on_volume_changed):
		_volume_slider.value_changed.connect(_on_volume_changed)
	if _mouse_only_check != null and not _mouse_only_check.toggled.is_connected(_on_mouse_only_toggled):
		_mouse_only_check.toggled.connect(_on_mouse_only_toggled)
	if _back_button != null and not _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.connect(_on_back_pressed)
	if _exit_button != null and not _exit_button.pressed.is_connected(_on_exit_pressed):
		_exit_button.pressed.connect(_on_exit_pressed)
	_wire_mouse_only_tooltip()
	if not Settings.settings_changed.is_connected(_on_settings_changed):
		Settings.settings_changed.connect(_on_settings_changed)
	_sync_from_settings()


func _process(_delta: float) -> void:
	if _tooltip_hovering:
		_position_tooltip_at_mouse()


func show_settings() -> void:
	_sync_from_settings()
	_hide_mouse_only_tooltip()
	visible = true
	if _root != null:
		_root.visible = true


func hide_settings() -> void:
	_hide_mouse_only_tooltip()
	visible = false
	if _root != null:
		_root.visible = false


func _build_checkbox_icons() -> void:
	_checkbox_unchecked_icon = _make_checkbox_texture(false)
	_checkbox_checked_icon = _make_checkbox_texture(true)


func _make_checkbox_texture(checked: bool) -> ImageTexture:
	## Supersample rounded cream square + gold rim, then downsample for smooth edges.
	var ss := CHECKBOX_SUPERSAMPLE
	var size := CHECKBOX_DISPLAY_SIZE * ss
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var fill := Color(0.93, 0.88, 0.72, 1.0)
	var border := Color(0.78, 0.62, 0.28, 1.0)
	var mark := Color(0.1, 0.07, 0.04, 1.0)

	# Dimensions in supersampled pixels (border is part of overall size).
	var pad := 1.0 * ss
	var radius := 3.5 * ss
	var border_w := 1.6 * ss
	var center := Vector2(size * 0.5, size * 0.5)
	var half := size * 0.5 - pad

	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _rounded_rect_sdf(p, center, Vector2(half, half), radius)
			# Soft outer coverage for anti-aliased silhouette.
			var outer_a := 1.0 - smoothstep(-0.75, 0.75, d)
			if outer_a <= 0.001:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# 0 at outer edge → 1 deep inside; border near the rim.
			var inside := 1.0 - smoothstep(-border_w - 0.5, -border_w + 0.5, d)
			var col := border.lerp(fill, inside)
			col.a = outer_a
			img.set_pixel(x, y, col)

	if checked:
		_draw_cartoon_check(img, mark, ss)

	img.resize(CHECKBOX_DISPLAY_SIZE, CHECKBOX_DISPLAY_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _rounded_rect_sdf(p: Vector2, center: Vector2, half_extents: Vector2, radius: float) -> float:
	var q := (p - center).abs() - half_extents + Vector2(radius, radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius


func _draw_cartoon_check(img: Image, color: Color, ss: int) -> void:
	## Thick rounded check in supersample space (smooth after downsample).
	var size := img.get_width()
	var s := float(ss)
	var path: Array[Vector2] = [
		Vector2(4.2 * s, 8.4 * s),
		Vector2(7.0 * s, 11.6 * s),
		Vector2(12.4 * s, 4.6 * s),
	]
	var thickness := 2.15 * s
	for y in size:
		for x in size:
			var existing := img.get_pixel(x, y)
			if existing.a < 0.4:
				continue
			# Prefer painting on cream fill, not pure gold rim.
			var is_fill := existing.r > 0.88 and existing.g > 0.8
			if not is_fill:
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var dist := _distance_to_polyline(p, path)
			var coverage := 1.0 - smoothstep(thickness * 0.5 - 0.6, thickness * 0.5 + 0.6, dist)
			if coverage <= 0.01:
				continue
			var out := color
			out.a = coverage * existing.a
			img.set_pixel(x, y, existing.lerp(out, coverage))


func _distance_to_polyline(p: Vector2, path: Array[Vector2]) -> float:
	var best := INF
	for i in range(path.size() - 1):
		best = minf(best, _distance_to_segment(p, path[i], path[i + 1]))
	return best


func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _style_all_checkboxes() -> void:
	for cb in [_music_check, _sound_check, _mouse_only_check]:
		_style_settings_checkbox(cb)


func _style_settings_checkbox(cb: CheckBox) -> void:
	if cb == null:
		return
	cb.custom_minimum_size = Vector2(CHECKBOX_DISPLAY_SIZE + 4, CHECKBOX_DISPLAY_SIZE + 4)
	cb.add_theme_icon_override("unchecked", _checkbox_unchecked_icon)
	cb.add_theme_icon_override("unchecked_disabled", _checkbox_unchecked_icon)
	cb.add_theme_icon_override("checked", _checkbox_checked_icon)
	cb.add_theme_icon_override("checked_disabled", _checkbox_checked_icon)
	cb.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75, 1.0))
	cb.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82, 1.0))
	cb.add_theme_color_override("font_pressed_color", Color(0.95, 0.9, 0.75, 1.0))


func _wire_mouse_only_tooltip() -> void:
	if _mouse_only_tooltip != null:
		_mouse_only_tooltip.text = MOUSE_ONLY_TOOLTIP_TEXT
		_mouse_only_tooltip.visible = false
		_mouse_only_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hover over label OR checkbox should show the tip (row covers both).
	for node in [_mouse_only_row, _mouse_only_label, _mouse_only_check]:
		if node == null:
			continue
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		if not node.mouse_entered.is_connected(_on_mouse_only_hover_entered):
			node.mouse_entered.connect(_on_mouse_only_hover_entered)
		if not node.mouse_exited.is_connected(_on_mouse_only_hover_exited):
			node.mouse_exited.connect(_on_mouse_only_hover_exited)


func _on_settings_changed() -> void:
	if visible:
		_sync_from_settings()


func _sync_from_settings() -> void:
	_syncing_ui = true
	if _music_check != null:
		_music_check.button_pressed = Settings.music_on
	if _sound_check != null:
		_sound_check.button_pressed = Settings.sound_on
	if _volume_slider != null:
		_volume_slider.value = Settings.volume
	if _mouse_only_check != null:
		_mouse_only_check.button_pressed = Settings.mouse_only_controls
	_syncing_ui = false


func _on_music_toggled(pressed: bool) -> void:
	if _syncing_ui:
		return
	Settings.music_on = pressed


func _on_sound_toggled(pressed: bool) -> void:
	if _syncing_ui:
		return
	Settings.sound_on = pressed


func _on_volume_changed(value: float) -> void:
	if _syncing_ui:
		return
	Settings.volume = value


func _on_mouse_only_toggled(pressed: bool) -> void:
	if _syncing_ui:
		return
	Settings.mouse_only_controls = pressed


func _on_back_pressed() -> void:
	Settings.close()


func _on_exit_pressed() -> void:
	Settings.exit_game()


func play_back_press_feedback() -> void:
	on_keyboard_feedback(&"activated")


func on_keyboard_feedback(phase: StringName) -> void:
	if _back_button != null and _back_button.has_method("on_keyboard_feedback"):
		_back_button.on_keyboard_feedback(phase)


func _on_mouse_only_hover_entered() -> void:
	_show_mouse_only_tooltip()


func _on_mouse_only_hover_exited() -> void:
	# Defer so moving label → checkbox doesn't flicker the tip off.
	call_deferred("_refresh_mouse_only_tooltip_hover")


func _refresh_mouse_only_tooltip_hover() -> void:
	if _is_mouse_over_mouse_only_controls():
		_show_mouse_only_tooltip()
	else:
		_hide_mouse_only_tooltip()


func _is_mouse_over_mouse_only_controls() -> bool:
	var mouse := get_viewport().get_mouse_position()
	if _mouse_only_row != null and _mouse_only_row.get_global_rect().has_point(mouse):
		return true
	if _mouse_only_label != null and _mouse_only_label.get_global_rect().has_point(mouse):
		return true
	if _mouse_only_check != null and _mouse_only_check.get_global_rect().has_point(mouse):
		return true
	return false


func _show_mouse_only_tooltip() -> void:
	if _mouse_only_tooltip == null:
		return
	_tooltip_hovering = true
	_mouse_only_tooltip.visible = true
	_position_tooltip_at_mouse()
	set_process(true)


func _hide_mouse_only_tooltip() -> void:
	_tooltip_hovering = false
	set_process(false)
	if _mouse_only_tooltip != null:
		_mouse_only_tooltip.visible = false


func _position_tooltip_at_mouse() -> void:
	if _mouse_only_tooltip == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var tip_size := _mouse_only_tooltip.get_minimum_size()
	if _mouse_only_tooltip.size.x > 1.0:
		tip_size = _mouse_only_tooltip.size
	var pos := mouse + TOOLTIP_CURSOR_OFFSET
	var viewport_size := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 4.0, maxf(4.0, viewport_size.x - tip_size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, viewport_size.y - tip_size.y - 4.0))
	_mouse_only_tooltip.global_position = pos
