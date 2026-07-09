extends SceneTree

## godot --headless --path "<project>" --script res://tools/verify_fairy_vengeful.gd

const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _TrinketEffects := preload("res://scripts/brewing/trinket_effects.gd")
const _DefaultContent := preload("res://scripts/data/default_content.gd")


func _init() -> void:
	var failures: Array[String] = []
	var content := _DefaultContent.create()

	_test_trinket_data(content, failures)
	_test_fairy_uses(content, failures)
	_test_vanish_next(content, failures)
	_test_escape_and_recapture(content, failures)
	_test_empty_cage_without_trinket_does_not_count(content, failures)
	_test_voodoo_copy_shares_trinket_and_partial_delete(content, failures)
	_test_recapture_does_not_delete_unrelated_cage(content, failures)
	_test_reward_pool(content, failures)
	_test_bag_save_roundtrip(content, failures)

	if failures.is_empty():
		print("verify_fairy_vengeful: PASS")
		quit(0)
	else:
		for failure in failures:
			print("FAIL: %s" % failure)
		print("verify_fairy_vengeful: FAIL (%d)" % failures.size())
		quit(1)


func _make_session(content, bag: BagModel, trinket_ids: Array[String] = []) -> BrewSession:
	var session := BrewSession.new()
	session.bind_ingredient_lookup(
		func(ingredient_id: String) -> IngredientData:
			return content.find_ingredient(ingredient_id)
	)
	var aura: AuraData = content.find_aura("none")
	if aura == null and not content.auras.is_empty():
		aura = content.auras.values()[0]
	session.start_brew(1, aura, bag, 0, 0, 0, 0, 0, trinket_ids)
	return session


func _dummy_chip(content) -> IngredientData:
	var template: IngredientData = content.find_ingredient("pumpkin")
	if template == null:
		template = content.find_ingredient("boom_berry_2")
	return template.duplicate_for_bag()


func _test_trinket_data(content, failures: Array[String]) -> void:
	var trinket: TrinketData = content.find_trinket(_TrinketEffects.VENGEFUL_FAIRY_ID)
	if trinket == null:
		failures.append("vengeful_fairy trinket missing")
		return
	if trinket.reward_offerable:
		failures.append("vengeful_fairy should not be reward_offerable")
	var art_path := "res://assets/cards/trinkets/%s.png" % trinket.get_art_filename()
	if not ResourceLoader.exists(art_path):
		failures.append("vengeful_fairy art missing at %s" % art_path)
	var cage_art := "res://assets/cards/ingredients/empty_cage.png"
	if not ResourceLoader.exists(cage_art):
		failures.append("empty_cage art missing at %s" % cage_art)


func _test_fairy_uses(content, failures: Array[String]) -> void:
	var fairy_template: IngredientData = content.find_ingredient(
		_IngredientEffects.FAIRY_IN_A_CAGE_ID
	)
	if fairy_template == null:
		failures.append("fairy template missing")
		return
	var chip := fairy_template.duplicate_for_bag()
	if chip.fairy_uses_remaining != _IngredientEffects.FAIRY_IN_A_CAGE_MAX_USES:
		failures.append("fairy chip should start with 5 uses")
	var description := _IngredientEffects.card_display_description(chip)
	if "5 uses left" not in description:
		failures.append("fairy card should show 5 uses left")


func _test_vanish_next(content, failures: Array[String]) -> void:
	var bag := BagModel.new()
	var fairy_template: IngredientData = content.find_ingredient(
		_IngredientEffects.FAIRY_IN_A_CAGE_ID
	)
	var berry_template: IngredientData = content.find_ingredient("boom_berry_2")
	if berry_template == null:
		berry_template = content.find_ingredient("pumpkin")
	var fairy := fairy_template.duplicate_for_bag()
	var berry := berry_template.duplicate_for_bag()
	bag.add_to_master_bag(fairy)
	bag.add_to_master_bag(berry)
	var session := _make_session(content, bag)

	session._apply_ingredient_play(fairy, false, false, -1)
	if not session.has_fairy_vanishes_next():
		failures.append("fairy should arm vanish-next after a non-final charge")
	if fairy.fairy_uses_remaining != _IngredientEffects.FAIRY_IN_A_CAGE_MAX_USES - 1:
		failures.append("fairy uses should decrement on play")

	var score_before := session.context.score
	session._apply_ingredient_play(berry, false, false, -1)
	if session.context.cauldron_contents.has(berry):
		failures.append("vanished berry must not remain in cauldron")
	if bag.has_master_chip(berry):
		failures.append("vanished berry must be deleted from master bag")
	if session.context.score != score_before:
		failures.append("vanished ingredient must not award score")
	if session.consume_vanish_poof() == null:
		failures.append("vanish poof should be pending after vanished play")
	if session.has_fairy_vanishes_next():
		failures.append("vanish-next should clear after consuming the next ingredient")


func _play_fairy_to_escape(session: BrewSession, bag: BagModel, fairy_chip: IngredientData, content) -> void:
	for _i in _IngredientEffects.FAIRY_IN_A_CAGE_MAX_USES - 1:
		session._apply_ingredient_play(fairy_chip, false, false, -1)
		if session.has_fairy_vanishes_next():
			var dummy: IngredientData = _dummy_chip(content)
			bag.add_to_master_bag(dummy)
			session._apply_ingredient_play(dummy, false, false, -1)
			session.consume_vanish_poof()
	session._apply_ingredient_play(fairy_chip, false, false, -1)


func _test_escape_and_recapture(content, failures: Array[String]) -> void:
	var bag := BagModel.new()
	var fairy_template: IngredientData = content.find_ingredient(
		_IngredientEffects.FAIRY_IN_A_CAGE_ID
	)
	var fairy_chip := fairy_template.duplicate_for_bag()
	bag.add_to_master_bag(fairy_chip)
	var session := _make_session(content, bag)

	_play_fairy_to_escape(session, bag, fairy_chip, content)
	if fairy_chip.fairy_uses_remaining != 0:
		failures.append("fairy uses should be 0 after 5 plays")
	if session.has_fairy_vanishes_next():
		failures.append("last fairy charge must not arm vanish-next")
	if not session.consume_fairy_escaped_poof():
		failures.append("fairy escape poof should be pending after 5th play")
	if session.context.cauldron_contents.has(fairy_chip):
		failures.append("fairy should be removed from cauldron on escape")
	if bag.has_master_chip(fairy_chip):
		failures.append("fairy chip should be removed from master bag on escape")
	var empty_chip: IngredientData = null
	for chip in session.context.cauldron_contents:
		if chip != null and chip.id == _IngredientEffects.EMPTY_CAGE_ID:
			empty_chip = chip
	if empty_chip == null:
		failures.append("empty cage should replace fairy in the cauldron on escape")
		return
	if _IngredientEffects.EMPTY_CAGE_ID not in bag.master_ids():
		failures.append("empty cage should be in master bag after escape")

	# Grant + link trinket instance to this cage.
	var instance_id := session.complete_fairy_escape_sequence(null)
	if instance_id < 0:
		failures.append("escape sequence should assign a trinket instance id")
	if empty_chip.vengeful_fairy_instance_id != instance_id:
		failures.append("empty cage should be assigned to the escaped trinket instance")
	session.sync_owned_trinkets([_TrinketEffects.VENGEFUL_FAIRY_ID])
	if session.get_vengeful_fairy_countdown(null, instance_id) != _IngredientEffects.EMPTY_CAGE_MAX_USES:
		failures.append(
			"vengeful fairy counter should start at 3 (got %d)"
			% session.get_vengeful_fairy_countdown(null, instance_id)
		)
	if empty_chip.empty_cage_uses_remaining != _IngredientEffects.EMPTY_CAGE_MAX_USES:
		failures.append("escape must not consume an empty-cage recapture charge")

	for i in _IngredientEffects.EMPTY_CAGE_MAX_USES - 1:
		session._apply_ingredient_play(empty_chip, false, false, -1)
		if session.consume_empty_cage_recapture_pending():
			failures.append("recapture should not fire before 3rd empty cage play")
		var expected_uses := _IngredientEffects.EMPTY_CAGE_MAX_USES - (i + 1)
		if empty_chip.empty_cage_uses_remaining != expected_uses:
			failures.append(
				"empty cage uses after play %d should be %d (got %d)"
				% [i + 1, expected_uses, empty_chip.empty_cage_uses_remaining]
			)

	session._apply_ingredient_play(empty_chip, false, false, -1)
	if not session.consume_empty_cage_recapture_pending():
		failures.append("empty cage recapture should be pending after 3rd play")
	var recaptured := session.complete_empty_cage_recapture(null)
	if recaptured == null:
		failures.append("recaptured fairy chip should not be null")
		return
	if recaptured.fairy_uses_remaining != _IngredientEffects.FAIRY_IN_A_CAGE_MAX_USES:
		failures.append("recaptured fairy should have 5 uses")
	if not session.context.cauldron_contents.has(recaptured):
		failures.append("recaptured fairy should be in the cauldron")
	if _IngredientEffects.EMPTY_CAGE_ID in bag.master_ids():
		failures.append("empty cage should be removed from bag on recapture")
	if not bag.has_master_chip(recaptured):
		failures.append("recaptured fairy should be in the master bag")
	for chip in session.context.cauldron_contents:
		if chip != null and chip.id == _IngredientEffects.EMPTY_CAGE_ID:
			failures.append("empty cage should be gone from cauldron after recapture")
			break


func _test_empty_cage_without_trinket_does_not_count(content, failures: Array[String]) -> void:
	var bag := BagModel.new()
	var empty_template: IngredientData = content.find_ingredient(
		_IngredientEffects.EMPTY_CAGE_ID
	)
	if empty_template == null:
		failures.append("empty cage template missing")
		return
	var empty_chip := empty_template.duplicate_for_bag()
	# No trinket link.
	empty_chip.vengeful_fairy_instance_id = -1
	bag.add_to_master_bag(empty_chip)
	var session := _make_session(content, bag, [])
	session._apply_ingredient_play(empty_chip, false, false, -1)
	if empty_chip.empty_cage_uses_remaining != _IngredientEffects.EMPTY_CAGE_MAX_USES:
		failures.append("empty cage without trinket must not spend recapture charges")
	if session.consume_empty_cage_recapture_pending():
		failures.append("empty cage without trinket must not recapture")


func _test_voodoo_copy_shares_trinket_and_partial_delete(content, failures: Array[String]) -> void:
	var bag := BagModel.new()
	var empty_template: IngredientData = content.find_ingredient(
		_IngredientEffects.EMPTY_CAGE_ID
	)
	var original := empty_template.duplicate_for_bag()
	original.vengeful_fairy_instance_id = 42
	original.empty_cage_uses_remaining = 2
	var copy := original.duplicate_preserving_bag_state()
	if copy == original:
		failures.append("voodoo cage copy must be a distinct chip instance")
	if copy.vengeful_fairy_instance_id != 42:
		failures.append("voodoo cage copy must share the same trinket instance id")
	if copy.empty_cage_uses_remaining != 2:
		failures.append("voodoo cage copy must share remaining uses")

	bag.add_to_master_bag(original)
	bag.add_to_master_bag(copy)
	var session := _make_session(content, bag, [_TrinketEffects.VENGEFUL_FAIRY_ID])
	# Simulate cauldron containing both linked cages.
	session.context.cauldron_contents.append(original)
	session.context.cauldron_contents.append(copy)

	# Playing the copy spends the shared counter (2 -> 1 -> 0) and recaptures on 0.
	session._apply_ingredient_play(copy, false, false, -1)
	if original.empty_cage_uses_remaining != 1 or copy.empty_cage_uses_remaining != 1:
		failures.append("linked cages must share the decremented counter")
	session._apply_ingredient_play(copy, false, false, -1)
	if not session.consume_empty_cage_recapture_pending():
		failures.append("linked cage play to 0 should pending recapture")
	var recaptured := session.complete_empty_cage_recapture(null)
	if recaptured == null:
		failures.append("recapture from voodoo copy should produce a fairy")
		return
	if bag.has_master_chip(copy):
		failures.append("triggering cage copy must be deleted on recapture")
	if not bag.has_master_chip(original):
		failures.append("non-trigger sibling cage must remain in the bag")
	if original.empty_cage_uses_remaining != 0:
		failures.append("sibling cage must be set to 0 uses after recapture")
	if original.vengeful_fairy_instance_id >= 0:
		failures.append("sibling cage must be unlinked (inert) after recapture")
	# Inert sibling should not recapture again.
	session.sync_owned_trinkets([])
	session._apply_ingredient_play(original, false, false, -1)
	if session.consume_empty_cage_recapture_pending():
		failures.append("inert 0-use cage must not trigger recapture")


func _test_recapture_does_not_delete_unrelated_cage(content, failures: Array[String]) -> void:
	var bag := BagModel.new()
	var empty_template: IngredientData = content.find_ingredient(
		_IngredientEffects.EMPTY_CAGE_ID
	)
	var cage_a := empty_template.duplicate_for_bag()
	cage_a.vengeful_fairy_instance_id = 1
	cage_a.empty_cage_uses_remaining = 1
	var cage_b := empty_template.duplicate_for_bag()
	cage_b.vengeful_fairy_instance_id = 2
	cage_b.empty_cage_uses_remaining = 3
	bag.add_to_master_bag(cage_a)
	bag.add_to_master_bag(cage_b)
	var session := _make_session(
		content,
		bag,
		[_TrinketEffects.VENGEFUL_FAIRY_ID, _TrinketEffects.VENGEFUL_FAIRY_ID]
	)
	session.context.cauldron_contents.append(cage_a)
	session.context.cauldron_contents.append(cage_b)

	session._apply_ingredient_play(cage_a, false, false, -1)
	if not session.consume_empty_cage_recapture_pending():
		failures.append("cage A at 1 use should recapture on play")
	session.complete_empty_cage_recapture(null)
	if bag.has_master_chip(cage_a):
		failures.append("recapture should delete only cage A")
	if not bag.has_master_chip(cage_b):
		failures.append("unrelated cage B must remain after cage A recapture")
	if cage_b.empty_cage_uses_remaining != 3:
		failures.append("unrelated cage B uses must be unchanged")
	if cage_b.vengeful_fairy_instance_id != 2:
		failures.append("unrelated cage B must keep its trinket link")


func _test_reward_pool(content, failures: Array[String]) -> void:
	var trinket: TrinketData = content.find_trinket(_TrinketEffects.VENGEFUL_FAIRY_ID)
	if trinket != null and trinket.reward_offerable:
		failures.append("vengeful fairy should not appear in reward pool")


func _test_bag_save_roundtrip(content, failures: Array[String]) -> void:
	var fairy_template: IngredientData = content.find_ingredient(
		_IngredientEffects.FAIRY_IN_A_CAGE_ID
	)
	var chip := fairy_template.duplicate_for_bag()
	chip.fairy_uses_remaining = 2
	var bag := BagModel.new()
	bag.add_to_master_bag(chip)
	var save_data := bag.get_master_chip_save_data()
	if save_data.is_empty() or int(save_data[0].get("fairyUses", -1)) != 2:
		failures.append("fairy uses should persist in bag save data")
	var restored: IngredientData = content.create_bag_chip_from_save(save_data[0])
	if restored.fairy_uses_remaining != 2:
		failures.append("fairy uses should restore from save data")

	var empty_template: IngredientData = content.find_ingredient(
		_IngredientEffects.EMPTY_CAGE_ID
	)
	var empty_chip := empty_template.duplicate_for_bag()
	empty_chip.empty_cage_uses_remaining = 1
	empty_chip.vengeful_fairy_instance_id = 7
	var bag2 := BagModel.new()
	bag2.add_to_master_bag(empty_chip)
	var empty_save := bag2.get_master_chip_save_data()
	if empty_save.is_empty() or int(empty_save[0].get("emptyCageUses", -1)) != 1:
		failures.append("empty cage uses should persist in bag save data")
	if int(empty_save[0].get("vengefulFairyInstanceId", -1)) != 7:
		failures.append("empty cage trinket instance id should persist in bag save data")
	var restored_empty: IngredientData = content.create_bag_chip_from_save(empty_save[0])
	if restored_empty.empty_cage_uses_remaining != 1:
		failures.append("empty cage uses should restore from save data")
	if restored_empty.vengeful_fairy_instance_id != 7:
		failures.append("empty cage trinket instance id should restore from save data")
