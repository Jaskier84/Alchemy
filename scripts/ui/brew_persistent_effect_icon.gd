class_name BrewPersistentEffectIcon
extends Control

const _INGREDIENT_ART_PATH_TEMPLATE := "res://assets/cards/ingredients/%s.png"
const _TRINKET_ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"
const _ICE_OVERLAY_ALPHA := 0.55
const _ICE_OVERLAY_SCALE := 0.72

@onready var _icon: TextureRect = $Icon
@onready var _ice_overlay: TextureRect = $IceOverlay
@onready var _overlay: Label = $Overlay


func bind(
	ingredient: IngredientData,
	overlay_text: String,
	icon_size: Vector2,
	trinket_id: String = "",
	show_ice_overlay: bool = false,
	art_filename: String = ""
) -> void:
	custom_minimum_size = icon_size
	size = icon_size
	var icon := _icon if _icon != null else get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.custom_minimum_size = icon_size
		icon.size = icon_size
		if trinket_id != "":
			icon.texture = _load_trinket_art(trinket_id)
		elif art_filename != "":
			icon.texture = _load_ingredient_art_by_id(art_filename)
		else:
			icon.texture = _load_ingredient_art(ingredient)
	var ice := _ice_overlay if _ice_overlay != null else get_node_or_null("IceOverlay") as TextureRect
	if ice != null:
		if show_ice_overlay:
			var ice_size := icon_size * _ICE_OVERLAY_SCALE
			ice.visible = true
			ice.texture = _load_ingredient_art_by_id(IngredientEffects.ICE_CUBE_ID)
			ice.modulate = Color(1, 1, 1, _ICE_OVERLAY_ALPHA)
			# Bottom-right badge so the countdown label stays readable.
			ice.anchor_left = 1.0
			ice.anchor_top = 1.0
			ice.anchor_right = 1.0
			ice.anchor_bottom = 1.0
			ice.offset_left = -ice_size.x
			ice.offset_top = -ice_size.y
			ice.offset_right = 0.0
			ice.offset_bottom = 0.0
		else:
			ice.visible = false
			ice.texture = null
	var overlay := _overlay if _overlay != null else get_node_or_null("Overlay") as Label
	if overlay != null:
		overlay.text = overlay_text
		overlay.visible = overlay_text != ""
		var font_size := clampi(int(icon_size.y * 0.52), 14, 28)
		overlay.add_theme_font_size_override("font_size", font_size)


func _load_ingredient_art(ingredient: IngredientData) -> Texture2D:
	if ingredient == null:
		return null
	return _load_ingredient_art_by_id(ingredient.get_art_filename())


func _load_ingredient_art_by_id(art_or_id: String) -> Texture2D:
	if art_or_id.is_empty():
		return null
	var art_path := _INGREDIENT_ART_PATH_TEMPLATE % art_or_id
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D


func _load_trinket_art(trinket_id: String) -> Texture2D:
	if trinket_id.is_empty():
		return null
	var art_path := _TRINKET_ART_PATH_TEMPLATE % trinket_id
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D
