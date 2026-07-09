class_name TrinketData
extends RefCounted

var id: String
var display_name: String
var description: String
var art: String
var reward_offerable: bool = true
## Runtime-only: distinguishes multiple vengeful fairy trinket instances in the UI.
var instance_id: int = -1


func _init(
	p_id: String,
	p_display_name: String,
	p_description: String,
	p_art: String = "",
	p_reward_offerable: bool = true
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	art = p_art
	reward_offerable = p_reward_offerable


func get_art_filename() -> String:
	if art.strip_edges() != "":
		return art.strip_edges()
	return id


func duplicate_for_runtime(p_instance_id: int = -1) -> TrinketData:
	var copy := TrinketData.new(id, display_name, description, art, reward_offerable)
	copy.instance_id = p_instance_id
	return copy