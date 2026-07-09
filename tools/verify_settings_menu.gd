extends SceneTree
## Headless smoke test for Settings autoload + overlay + gear scene load.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var settings := root.get_node_or_null("Settings")
	if settings == null:
		failures.append("Settings autoload missing at /root/Settings")
	else:
		if not settings.has_method("open"):
			failures.append("Settings.open missing")
		if not settings.has_method("close"):
			failures.append("Settings.close missing")
		if not settings.has_method("toggle"):
			failures.append("Settings.toggle missing")

		if AudioServer.get_bus_index("Music") < 0:
			failures.append("Music bus missing")
		if AudioServer.get_bus_index("SFX") < 0:
			failures.append("SFX bus missing")

		settings.set("volume", 0.5)
		if not is_equal_approx(float(settings.get("volume")), 0.5):
			failures.append("volume set failed")
		settings.set("music_on", false)
		if bool(settings.get("music_on")):
			failures.append("music_on set failed")
		var music_idx := AudioServer.get_bus_index("Music")
		if music_idx >= 0 and not AudioServer.is_bus_mute(music_idx):
			failures.append("Music bus should be muted when music_on=false")
		settings.set("music_on", true)
		settings.set("sound_on", false)
		var sfx_idx := AudioServer.get_bus_index("SFX")
		if sfx_idx >= 0 and not AudioServer.is_bus_mute(sfx_idx):
			failures.append("SFX bus should be muted when sound_on=false")
		settings.set("sound_on", true)
		settings.set("volume", 1.0)

		if bool(settings.call("is_open")):
			failures.append("settings should start closed")
		settings.call("open")
		if not bool(settings.call("is_open")):
			failures.append("settings should be open after open()")
		settings.call("close")
		if bool(settings.call("is_open")):
			failures.append("settings should be closed after close()")
		settings.call("toggle")
		if not bool(settings.call("is_open")):
			failures.append("settings should be open after toggle()")
		settings.call("toggle")
		if bool(settings.call("is_open")):
			failures.append("settings should be closed after second toggle()")

	var gear_scene := load("res://scenes/ui/settings_gear_button.tscn") as PackedScene
	if gear_scene == null:
		failures.append("settings_gear_button.tscn failed to load")
	else:
		var gear := gear_scene.instantiate() as TextureButton
		if gear == null:
			failures.append("gear instantiate failed")
		else:
			root.add_child(gear)
			if gear.texture_normal == null:
				failures.append("gear missing texture_normal")
			gear.queue_free()

	var main_menu := load("res://scenes/main_menu.tscn") as PackedScene
	if main_menu == null:
		failures.append("main_menu.tscn failed to load")
	else:
		var menu := main_menu.instantiate()
		if menu == null:
			failures.append("main_menu instantiate failed")
		else:
			root.add_child(menu)
			var settings_btn := menu.get_node_or_null("SettingsButton") as Control
			if settings_btn == null:
				failures.append("MainMenu SettingsButton missing")
			var exit_btn := menu.get_node_or_null("ExitButton") as Control
			if exit_btn != null and settings_btn != null:
				if settings_btn.offset_top >= exit_btn.offset_top:
					failures.append(
						"SettingsButton should be above ExitButton (offset_top %s vs %s)"
						% [settings_btn.offset_top, exit_btn.offset_top]
					)
			menu.queue_free()

	var run_prep := load("res://scenes/run_prep.tscn") as PackedScene
	if run_prep == null:
		failures.append("run_prep.tscn failed to load")
	else:
		var prep := run_prep.instantiate()
		root.add_child(prep)
		if prep.get_node_or_null("SettingsGearButton") == null:
			failures.append("RunPrep SettingsGearButton missing")
		prep.queue_free()

	# game.tscn: check resource includes gear without fully entering run
	var game_text := FileAccess.get_file_as_string("res://scenes/game.tscn")
	if game_text.find("SettingsGearButton") < 0:
		failures.append("game.tscn missing SettingsGearButton")

	if failures.is_empty():
		print("verify_settings_menu: OK")
		quit(0)
	else:
		for f in failures:
			push_error("verify_settings_menu: " + f)
			print("FAIL: ", f)
		quit(1)
