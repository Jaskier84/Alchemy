class_name CookbookEntry
extends Control
## One cookbook cell: full card-style entry if discovered, silhouette if locked.

const _ART_PATH_TEMPLATE := "res://assets/cards/ingredients/%s.png"
const _PARCHMENT_PATH := "res://assets/cards/parchment_plate.png"

@onready var _parchment: TextureRect = $Parchment
@onready var _art: TextureRect = $Art
@onready var _name_label: Label = $NameLabel
@onready var _cost_label: Label = $CostLabel

var _ingredient: IngredientData
var _discovered: bool = false


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
	var texture := _load_art(_ingredient)
	if _art != null:
		_art.texture = texture
		_art.visible = texture != null
		_art.modulate = Color.WHITE if _discovered else Color(0.05, 0.05, 0.08, 0.92)
	if _parchment != null:
		_parchment.visible = _discovered
	if _name_label != null:
		_name_label.visible = _discovered
		_name_label.text = _ingredient.display_name if _discovered else ""
	if _cost_label != null:
		_cost_label.visible = _discovered
		_cost_label.text = "%d gold" % _ingredient.shop_cost if _discovered else ""


func _load_art(ingredient: IngredientData) -> Texture2D:
	var art_path := _ART_PATH_TEMPLATE % ingredient.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D
