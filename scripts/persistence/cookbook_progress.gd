class_name CookbookProgress
extends RefCounted
## Meta progression: ingredients ever present in the player's bag (across runs).

const FILE_NAME := "cookbook_progress.json"
const FILE_PATH := "user://" + FILE_NAME

static var _loaded: bool = false
static var _discovered: Dictionary = {}  # id -> true


static func is_discovered(ingredient_id: String) -> bool:
	_ensure_loaded()
	var normalized := str(ingredient_id)
	if normalized.is_empty():
		return false
	return _discovered.has(normalized)


static func discover_ingredient(ingredient_id: String) -> void:
	_ensure_loaded()
	var normalized := str(ingredient_id)
	if normalized.is_empty() or _discovered.has(normalized):
		return
	_discovered[normalized] = true
	_save()


static func discover_ingredient_data(ingredient: IngredientData) -> void:
	if ingredient == null:
		return
	discover_ingredient(ingredient.id)


static func discover_from_bag(bag: BagModel) -> void:
	if bag == null:
		return
	_ensure_loaded()
	var changed := false
	for chip in bag.get_all_master_chips():
		if chip == null:
			continue
		var normalized := str(chip.id)
		if normalized.is_empty() or _discovered.has(normalized):
			continue
		_discovered[normalized] = true
		changed = true
	if changed:
		_save()


static func discover_many(ids: Array) -> void:
	_ensure_loaded()
	var changed := false
	for raw in ids:
		var normalized := str(raw)
		if normalized.is_empty() or _discovered.has(normalized):
			continue
		_discovered[normalized] = true
		changed = true
	if changed:
		_save()


static func all_discovered_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	for key in _discovered.keys():
		ids.append(str(key))
	ids.sort()
	return ids


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_discovered.clear()
	if not FileAccess.file_exists(FILE_PATH):
		return
	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var list = parsed.get("discoveredIngredientIds", [])
	if typeof(list) != TYPE_ARRAY:
		return
	for raw in list:
		var normalized := str(raw)
		if not normalized.is_empty():
			_discovered[normalized] = true


static func _save() -> void:
	var ids: Array = []
	for key in _discovered.keys():
		ids.append(str(key))
	ids.sort()
	var payload := {"discoveredIngredientIds": ids}
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("CookbookProgress: could not write %s" % FILE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
