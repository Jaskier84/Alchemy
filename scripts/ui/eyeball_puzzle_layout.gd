class_name EyeballPuzzleLayout
extends RefCounted

const CARD_BASE_SIZE := Vector2(300.0, 420.0)
const CARD_SCALE := 0.52
## Bat-wing / picker choices: smaller so title + hint stay readable.
const PICKER_CARD_SCALE := 0.40

static var _active_scale: float = CARD_SCALE


static func set_use_picker_scale(use_picker: bool) -> void:
	_active_scale = PICKER_CARD_SCALE if use_picker else CARD_SCALE


static func card_scale() -> float:
	return _active_scale


static func card_display_size() -> Vector2:
	return (CARD_BASE_SIZE * _active_scale).floor()


static func configure_card(card: IngredientCard) -> void:
	card.scale = Vector2.ONE * _active_scale
	card.pivot_offset = Vector2.ZERO
	card.position = Vector2.ZERO
	card.custom_minimum_size = CARD_BASE_SIZE
	card.size = CARD_BASE_SIZE
	if card.has_method("_reset_visual_scale"):
		card._reset_visual_scale()
