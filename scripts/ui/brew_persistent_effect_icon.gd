class_name BrewPersistentEffectIcon
extends Control
## Small buff/debuff icon. Hover shows the matching ingredient/trinket card text.

const _INGREDIENT_ART_PATH_TEMPLATE := "res://assets/cards/ingredients/%s.png"
const _TRINKET_ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"
const _ICE_OVERLAY_ALPHA := 0.55
const _ICE_OVERLAY_SCALE := 0.72
const CURSOR_TOOLTIP_GROUP := &"cursor_tooltip"

@onready var _icon: TextureRect = $Icon
@onready var _ice_overlay: TextureRect = $IceOverlay
@onready var _overlay: Label = $Overlay

var _tip_text: String = ""
var _tooltip_host: CursorTooltip


func _ready() -> void:
	# Receive hover so tooltips work even when parents ignore mouse.
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func set_tooltip_host(host: CursorTooltip) -> void:
	_tooltip_host = host


func bind(
	ingredient: IngredientData,
	overlay_text: String,
	icon_size: Vector2,
	trinket_id: String = "",
	show_ice_overlay: bool = false,
	art_filename: String = ""
) -> void:
	custom_minimum_size = icon_size
	# Icon uses full-rect anchors; size root deferred so anchors don't fight size writes.
	call_deferred("set_size", icon_size)
	var icon := _icon if _icon != null else get_node_or_null("Icon") as TextureRect
	if icon != null:
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

	_tip_text = _resolve_tip_text(ingredient, trinket_id)
	mouse_filter = (
		Control.MOUSE_FILTER_STOP if not _tip_text.is_empty() else Control.MOUSE_FILTER_IGNORE
	)


func _resolve_tip_text(ingredient: IngredientData, trinket_id: String) -> String:
	if not trinket_id.is_empty():
		var trinket := _find_trinket(trinket_id)
		if trinket != null:
			return trinket.description.strip_edges()
		return ""
	var source := ingredient
	if source == null:
		return ""
	# Same body text shown on the ingredient scroll.
	return IngredientEffects.card_display_description(source).strip_edges()


func _find_trinket(trinket_id: String) -> TrinketData:
	if trinket_id.is_empty():
		return null
	if GameManager != null and GameManager.run != null:
		var from_run: TrinketData = GameManager.run.find_trinket(trinket_id)
		if from_run != null:
			return from_run
	if GameManager != null:
		for item in GameManager.get_all_trinkets():
			if item is TrinketData and (item as TrinketData).id == trinket_id:
				return item as TrinketData
	return null


func _on_mouse_entered() -> void:
	if _tip_text.is_empty() or not visible:
		return
	var host := _resolve_tooltip_host()
	if host != null:
		host.show_tip(_tip_text)


func _on_mouse_exited() -> void:
	var host := _resolve_tooltip_host()
	if host != null:
		host.hide_tip()


func _on_visibility_changed() -> void:
	if not visible:
		_on_mouse_exited()


func _resolve_tooltip_host() -> CursorTooltip:
	if _tooltip_host != null and is_instance_valid(_tooltip_host):
		return _tooltip_host
	if not is_inside_tree():
		return null
	var nodes := get_tree().get_nodes_in_group(CURSOR_TOOLTIP_GROUP)
	for node in nodes:
		if node is CursorTooltip:
			_tooltip_host = node as CursorTooltip
			return _tooltip_host
	return null


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
