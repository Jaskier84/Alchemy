class_name BrewPersistentEffects
extends RefCounted

class EffectEntry:
	var ingredient_id: String = ""
	var overlay_text: String = ""
	var sort_order: int = 0
	## Semi-transparent ice-cube badge (Poison Apple played under Ice Cube).
	var ice_overlay: bool = false
	## Optional art stem under assets/cards/ingredients/ (for non-ingredient flip arts).
	var art_filename: String = ""


static func collect(session: BrewSession) -> Array[EffectEntry]:
	var entries: Array[EffectEntry] = []
	if session == null or session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return entries

	var context := session.context
	var cauldron: Array = context.cauldron_contents

	_add_counter_entry(
		entries,
		IngredientEffects.ICE_CUBE_ID,
		session.get_ice_cube_shields_remaining(),
		10
	)
	_add_counter_entry(
		entries,
		IngredientEffects.GROWTH_POTION_ID,
		session.get_growth_potion_doubles_remaining(),
		11
	)
	_add_counter_entry(
		entries,
		IngredientEffects.LIGHTNING_ID,
		session.get_chain_draws_remaining(),
		12
	)

	for pending in session.get_poison_apple_pending():
		var hands_left := int(pending.get("hands_remaining", 0))
		if hands_left <= 0:
			continue
		_add_entry(
			entries,
			IngredientEffects.POISON_APPLE_ID,
			str(hands_left),
			13,
			bool(pending.get("ice_protected", false))
		)

	if session.get_booberry_count_this_hand() > 0:
		_add_entry(
			entries,
			IngredientEffects.BOOBERRY_ID,
			str(session.get_booberry_count_this_hand()),
			14
		)

	_add_counter_entry(
		entries,
		IngredientEffects.STIRRING_SPOON_ID,
		session.get_stirring_spoon_hands_remaining(),
		15
	)
	_add_counter_entry(
		entries,
		IngredientEffects.JUGGLING_CLUB_ID,
		session.get_juggling_club_hands_remaining(),
		16
	)
	# Lucky Coin: stacked extra swaps for the next hand (flip-side art + count).
	var lucky_swaps := session.get_lucky_coin_swap_hands_remaining()
	if lucky_swaps > 0:
		var lucky_entry := EffectEntry.new()
		lucky_entry.ingredient_id = IngredientEffects.LUCKY_COIN_ID
		lucky_entry.art_filename = IngredientEffects.LUCKY_COIN_FLIP_ART
		lucky_entry.overlay_text = str(lucky_swaps)
		lucky_entry.sort_order = 18
		entries.append(lucky_entry)

	if session.get_next_hand_draw_count() == IngredientEffects.SHRUNKEN_HEAD_HAND_SIZE:
		_add_entry(entries, IngredientEffects.SHRUNKEN_HEAD_ID, "", 17)

	if session.has_unicorn_cures_next_explosive():
		_add_entry(entries, IngredientEffects.UNICORN_HORN_ID, "", 20)
	if session.has_parrot_doubles_next():
		_add_entry(entries, IngredientEffects.PARROT_ID, "", 21)
	if session.has_voodoo_doll_arms_copy() and _has_ingredient_in_cauldron(
		cauldron,
		IngredientEffects.VOODOO_DOLL_ID
	):
		_add_entry(entries, IngredientEffects.VOODOO_DOLL_ID, "", 23)

	if TrinketEffects.has_pumpkin_trinket(context.owned_trinket_ids):
		_add_counter_entry(
			entries,
			IngredientEffects.PUMPKIN_ID,
			TrinketEffects.pumpkin_trinket_buff_streak(cauldron),
			28
		)

	_add_counter_entry(
		entries,
		IngredientEffects.RAT_ID,
		IngredientEffects.count_trailing_rat_streak(cauldron),
		29
	)

	_add_cauldron_count_entry(
		entries,
		cauldron,
		IngredientEffects.FROG_LEG_ID,
		false,
		30
	)
	_add_cauldron_count_entry(
		entries,
		cauldron,
		IngredientEffects.NEWT_TAIL_ID,
		true,
		32
	)
	# Gloom Weed only doubles gold if it is the last ingredient when you stop.
	# Show the buff only while that condition is still true.
	if session.gloom_weed_doubles_gold():
		_add_entry(entries, IngredientEffects.GLOOM_WEED_ID, "x2", 33)
	_add_cauldron_count_entry(
		entries,
		cauldron,
		IngredientEffects.CINNAMON_ID,
		true,
		35
	)
	if _has_ingredient_in_cauldron(cauldron, IngredientEffects.GARLIC_ID):
		# Only the first garlic raises the explosion limit; extra copies do nothing.
		_add_entry(entries, IngredientEffects.GARLIC_ID, "", 36)
	_add_cauldron_count_entry(
		entries,
		cauldron,
		IngredientEffects.HOLY_GRAIL_ID,
		false,
		37
	)

	entries.sort_custom(
		func(a: EffectEntry, b: EffectEntry) -> bool:
			return a.sort_order < b.sort_order
	)
	return entries


static func _add_counter_entry(
	entries: Array[EffectEntry],
	ingredient_id: String,
	count: int,
	sort_order: int
) -> void:
	if count <= 0:
		return
	_add_entry(entries, ingredient_id, str(count), sort_order)


static func _add_cauldron_count_entry(
	entries: Array[EffectEntry],
	cauldron: Array,
	ingredient_id: String,
	show_count_when_single: bool,
	sort_order: int
) -> void:
	var count := _count_ingredient_id(cauldron, ingredient_id)
	if count <= 0:
		return
	var overlay := ""
	if show_count_when_single or count > 1:
		overlay = str(count)
	_add_entry(entries, ingredient_id, overlay, sort_order)


static func _add_entry(
	entries: Array[EffectEntry],
	ingredient_id: String,
	overlay_text: String,
	sort_order: int,
	ice_overlay: bool = false
) -> void:
	var entry := EffectEntry.new()
	entry.ingredient_id = ingredient_id
	entry.overlay_text = overlay_text
	entry.sort_order = sort_order
	entry.ice_overlay = ice_overlay
	entries.append(entry)


static func _has_ingredient_in_cauldron(cauldron: Array, ingredient_id: String) -> bool:
	return _count_ingredient_id(cauldron, ingredient_id) > 0


static func _count_ingredient_id(cauldron: Array, ingredient_id: String) -> int:
	var count := 0
	for ingredient in cauldron:
		if ingredient != null and ingredient.id == ingredient_id:
			count += 1
	return count