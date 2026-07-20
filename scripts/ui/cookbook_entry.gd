class_name CookbookEntry
extends Control
## Compact cookbook tile: art/silhouette only. Full scroll preview is owned by the overlay.

const _ART_PATH_TEMPLATE := "res://assets/cards/ingredients/%s.png"

const DEFAULT_ENTRY_SIZE := Vector2(88.0, 88.0)
const HOVER_SCALE := 1.14
const HOVER_SPEED := 12.0

## Shared across all entries — avoid reloading the same PNG dozens of times per open.
static var _art_texture_cache: Dictionary = {}  # path -> Texture2D

signal hover_started(entry: CookbookEntry)
signal hover_ended(entry: CookbookEntry)

var _ingredient: IngredientData
var _discovered: bool = false
var _art: TextureRect
var _base_scale := Vector2.ONE
var _entry_size := DEFAULT_ENTRY_SIZE


func _ready() -> void:
	_ensure_art_node()
	_apply_size(_entry_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_base_scale = scale
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if _ingredient != null:
		_refresh()


func bind(ingredient: IngredientData, discovered: bool) -> void:
	_ingredient = ingredient
	_discovered = discovered
	if is_node_ready():
		_refresh()
	else:
		call_deferred("_refresh")


func set_discovered(discovered: bool) -> void:
	if _discovered == discovered:
		return
	_discovered = discovered
	if is_node_ready():
		_apply_discovered_visual()


func apply_tile_size(tile_size: Vector2) -> void:
	if _entry_size.is_equal_approx(tile_size):
		return
	_entry_size = tile_size
	_apply_size(tile_size)


func get_ingredient() -> IngredientData:
	return _ingredient


func is_discovered() -> bool:
	return _discovered


func get_art_center_global() -> Vector2:
	if _art != null and is_instance_valid(_art):
		return _art.get_global_rect().get_center()
	return get_global_rect().get_center()


func _apply_size(tile_size: Vector2) -> void:
	custom_minimum_size = tile_size
	size = tile_size
	pivot_offset = tile_size * 0.5


func _ensure_art_node() -> void:
	if _art != null and is_instance_valid(_art):
		return
	_art = TextureRect.new()
	_art.name = "Art"
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_left = 4.0
	_art.offset_top = 4.0
	_art.offset_right = -4.0
	_art.offset_bottom = -4.0
	add_child(_art)


func _refresh() -> void:
	if _ingredient == null:
		return
	_ensure_art_node()
	_apply_size(_entry_size)
	_art.texture = _load_art_cached(_ingredient)
	_apply_discovered_visual()


func _apply_discovered_visual() -> void:
	if _art == null:
		return
	if _discovered:
		# Full-color art.
		_art.modulate = Color.WHITE
	else:
		# Flat black silhouette via modulate — keeps alpha, no per-pixel CPU work.
		_art.modulate = Color(0, 0, 0, 1)


func _load_art_cached(ingredient: IngredientData) -> Texture2D:
	var art_path := _ART_PATH_TEMPLATE % ingredient.get_art_filename()
	if _art_texture_cache.has(art_path):
		return _art_texture_cache[art_path] as Texture2D
	if not ResourceLoader.exists(art_path):
		_art_texture_cache[art_path] = null
		return null
	var tex := load(art_path) as Texture2D
	_art_texture_cache[art_path] = tex
	return tex


func _on_mouse_entered() -> void:
	_tween_scale(_base_scale * HOVER_SCALE)
	hover_started.emit(self)


func _on_mouse_exited() -> void:
	_tween_scale(_base_scale)
	hover_ended.emit(self)


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / HOVER_SPEED)
