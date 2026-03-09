extends EditorInspectorPlugin

# ~~ Special cases ~~
# @export_custom(0, "SceneNodePath:CharacterBody2D")
# var remote_character: SceneNodePath
#
# @export_custom(PROPERTY_HINT_ARRAY_TYPE, "24/17:SceneNodePath:Sprite2D")
# var remote_sprites: Array[SceneNodePath]

const SceneNodePathEditor = preload("uid://bbb777txx33hk")


func _can_handle(object: Object) -> bool:
	return true

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if type != TYPE_OBJECT:
		return false
	
	if not "SceneNodePath" in hint_string:
		return false
	
	var allowed_class: String = "Node"
	
	if ":" in hint_string:
		var parts = hint_string.split(":")
		var potential_type = parts[-1].strip_edges()
		if potential_type != "SceneNodePath":
			allowed_class = potential_type
	
	var editor = SceneNodePathEditor.new()
	editor.forced_allowed_class = allowed_class
	add_property_editor(name, editor)
	return true
