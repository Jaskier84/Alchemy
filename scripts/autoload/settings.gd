extends Node
## Global settings (audio + settings UI). Accessible as the Settings autoload.

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "audio"
const HOLD_CANCEL_SEC := 2.0

signal settings_changed
signal opened
signal closed

var music_on: bool = true:
	set(value):
		if music_on == value:
			return
		music_on = value
		_on_setting_mutated()

var sound_on: bool = true:
	set(value):
		if sound_on == value:
			return
		sound_on = value
		_on_setting_mutated()

var volume: float = 1.0:
	set(value):
		var clamped := clampf(value, 0.0, 1.0)
		if is_equal_approx(volume, clamped):
			return
		volume = clamped
		_on_setting_mutated()

## When true, Enter/Space primary actions are disabled (Escape/settings still work).
var mouse_only_controls: bool = false:
	set(value):
		if mouse_only_controls == value:
			return
		mouse_only_controls = value
		_on_setting_mutated()

var _overlay: CanvasLayer
var _loading: bool = false

var _accept_holding: bool = false
var _accept_cancelled: bool = false
var _accept_action: StringName = &""
var _accept_hold_timer: SceneTreeTimer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_load()
	_apply_audio()
	_overlay = preload("res://scenes/ui/settings_overlay.tscn").instantiate()
	add_child(_overlay)
	if _overlay.has_method("hide_settings"):
		_overlay.call("hide_settings")


func _on_setting_mutated() -> void:
	_apply_audio()
	if not _loading:
		_save()
	settings_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel_accept_hold()
		toggle()
		get_viewport().set_input_as_handled()
		return

	if mouse_only_controls:
		return

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if _begin_accept_hold():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_released("ui_accept"):
		if _accept_holding:
			_end_accept_hold()
			get_viewport().set_input_as_handled()


func _begin_accept_hold() -> bool:
	if _accept_holding:
		return true
	var action: StringName = &""
	if is_open():
		action = &"settings_back"
	elif GameManager != null and GameManager.has_method("peek_primary_keyboard_action"):
		action = GameManager.peek_primary_keyboard_action()
	if action == &"":
		return false

	_accept_holding = true
	_accept_cancelled = false
	_accept_action = action
	_emit_feedback(action, &"started")

	_accept_hold_timer = get_tree().create_timer(HOLD_CANCEL_SEC)
	_accept_hold_timer.timeout.connect(_on_accept_hold_timeout, CONNECT_ONE_SHOT)
	return true


func _on_accept_hold_timeout() -> void:
	if not _accept_holding or _accept_cancelled:
		return
	_accept_cancelled = true
	_emit_feedback(_accept_action, &"cancelled")


func _end_accept_hold() -> void:
	if not _accept_holding:
		return
	var action := _accept_action
	var cancelled := _accept_cancelled
	_accept_holding = false
	_accept_action = &""
	_accept_hold_timer = null

	if cancelled:
		return

	if action == &"settings_back":
		_emit_feedback(action, &"activated")
		close()
		return

	if GameManager != null and GameManager.has_method("commit_primary_keyboard_action"):
		GameManager.commit_primary_keyboard_action(action)


func _cancel_accept_hold() -> void:
	if not _accept_holding:
		return
	var action := _accept_action
	_accept_holding = false
	_accept_cancelled = true
	_accept_action = &""
	_accept_hold_timer = null
	_emit_feedback(action, &"cancelled")


func _emit_feedback(action: StringName, phase: StringName) -> void:
	if action == &"settings_back":
		if _overlay != null and _overlay.has_method("on_keyboard_feedback"):
			_overlay.call("on_keyboard_feedback", phase)
		return
	if GameManager != null:
		GameManager.primary_keyboard_feedback.emit(action, phase)


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func open() -> void:
	if _overlay == null:
		return
	if _overlay.has_method("show_settings"):
		_overlay.call("show_settings")
	else:
		_overlay.visible = true
	opened.emit()


func close() -> void:
	if _overlay == null:
		return
	if _overlay.has_method("hide_settings"):
		_overlay.call("hide_settings")
	else:
		_overlay.visible = false
	closed.emit()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Save active run when appropriate, then quit the application.
func exit_game() -> void:
	if GameManager != null and GameManager.has_method("save_before_exit"):
		GameManager.save_before_exit()
	get_tree().quit()


func music_bus() -> String:
	return BUS_MUSIC


func sfx_bus() -> String:
	return BUS_SFX


func configure_music_player(player: AudioStreamPlayer) -> void:
	if player != null:
		player.bus = BUS_MUSIC


func configure_sfx_player(player: AudioStreamPlayer) -> void:
	if player != null:
		player.bus = BUS_SFX


func configure_music_video(player: VideoStreamPlayer) -> void:
	if player != null:
		player.bus = BUS_MUSIC


func _ensure_audio_buses() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)


func _ensure_bus(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		return
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		if volume <= 0.0001:
			AudioServer.set_bus_mute(master_idx, true)
			AudioServer.set_bus_volume_db(master_idx, linear_to_db(0.0001))
		else:
			AudioServer.set_bus_mute(master_idx, false)
			AudioServer.set_bus_volume_db(master_idx, linear_to_db(volume))

	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if music_idx >= 0:
		AudioServer.set_bus_mute(music_idx, not music_on)

	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx >= 0:
		AudioServer.set_bus_mute(sfx_idx, not sound_on)


func _load() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		return
	_loading = true
	music_on = bool(config.get_value(CONFIG_SECTION, "music_on", true))
	sound_on = bool(config.get_value(CONFIG_SECTION, "sound_on", true))
	volume = float(config.get_value(CONFIG_SECTION, "volume", 1.0))
	mouse_only_controls = bool(config.get_value(CONFIG_SECTION, "mouse_only_controls", false))
	_loading = false


func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)  # preserve other sections if any
	config.set_value(CONFIG_SECTION, "music_on", music_on)
	config.set_value(CONFIG_SECTION, "sound_on", sound_on)
	config.set_value(CONFIG_SECTION, "volume", volume)
	config.set_value(CONFIG_SECTION, "mouse_only_controls", mouse_only_controls)
	config.save(CONFIG_PATH)
