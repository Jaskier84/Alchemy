class_name CookbookEntry
extends Control
## Cookbook cell: full ingredient card if discovered, flat black silhouette if locked.

const _CARD_SCENE := preload("res://scenes/ui/ingredient_card.tscn")
const _ART_PATH_TEMPLATE := "res://assets/cards/ingredients/%s.png"

## About half the previous cookbook cell / roughly half of hand-card display.
const CARD_SCALE := 0.17
const CARD_BASE_SIZE := Vector2(300.0, 420.0)
const ENTRY_SIZE := CARD_BASE_SIZE * CARD_SCALE
const HOVER_SCALE := 1.12
const HOVER_SPEED := 12.0

var _ingredient: IngredientData
var _discovered: bool = false
var _card: IngredientCard
var _silhouette: TextureRect
var _base_scale := Vector2.ONE
var _hovering := false


func _ready() -> void:
	custom_minimum_size = ENTRY_SIZE
	size = ENTRY_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = ENTRY_SIZE * 0.5
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


func _refresh() -> void:
	if _ingredient == null:
		return
	custom_minimum_size = ENTRY_SIZE
	size = ENTRY_SIZE
	pivot_offset = ENTRY_SIZE * 0.5
	_clear_visuals()
	if _discovered:
		_show_discovered_card()
	else:
		_show_locked_silhouette()


func _clear_visuals() -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	if _silhouette != null and is_instance_valid(_silhouette):
		_silhouette.queue_free()
	_silhouette = null


func _show_discovered_card() -> void:
	_card = _CARD_SCENE.instantiate() as IngredientCard
	if _card == null:
		return
	add_child(_card)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.focus_mode = Control.FOCUS_NONE
	_card.disabled = true
	_card.set_external_icon_strip(true)
	_card.bind_preview(_ingredient)
	# Same full parchment scroll layout as hand/preview cards, scaled down.
	_card.scale = Vector2.ONE * CARD_SCALE
	_card.position = Vector2.ZERO
	_card.pivot_offset = Vector2.ZERO


func _show_locked_silhouette() -> void:
	var texture := _load_flat_black_silhouette(_ingredient)
	_silhouette = TextureRect.new()
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_silhouette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_silhouette.texture = texture
	_silhouette.modulate = Color(0, 0, 0, 1)
	_silhouette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_silhouette.offset_left = 8.0
	_silhouette.offset_top = 8.0
	_silhouette.offset_right = -8.0
	_silhouette.offset_bottom = -8.0
	add_child(_silhouette)


func _load_flat_black_silhouette(ingredient: IngredientData) -> Texture2D:
	var art_path := _ART_PATH_TEMPLATE % ingredient.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	var source := load(art_path) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	if image.is_compressed():
		image = image.duplicate()
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	# Flatten to solid black wherever there is opacity — barely recognizable shape.
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.08:
				image.set_pixel(x, y, Color(0, 0, 0, 1))
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _on_mouse_entered() -> void:
	_hovering = true
	_tween_scale(_base_scale * HOVER_SCALE)


func _on_mouse_exited() -> void:
	_hovering = false
	_tween_scale(_base_scale)


func _tween_scale(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 1.0 / HOVER_SPEED)
