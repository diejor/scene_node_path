@tool
extends EditorPlugin

## Main entry point for the Scene Node Path plugin.
## Registers the custom inspector property and initializes project settings.

var inspector_plugin: EditorInspectorPlugin
const InspectorPlugin = preload("uid://di5tdm30ixtee")

const SETTING_NAME = "scene_node_path/custom_class_name"

func _enter_tree() -> void:
	_setup_project_setting()
	
	inspector_plugin = InspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree() -> void:
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)

## Registers the custom class name setting in the Project Settings if it doesn't exist.
func _setup_project_setting() -> void:
	if not ProjectSettings.has_setting(SETTING_NAME):
		ProjectSettings.set_setting(SETTING_NAME, "SceneNodePath")

	ProjectSettings.set_initial_value(SETTING_NAME, "SceneNodePath")
	
	var property_info: Dictionary = {
		"name": SETTING_NAME,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": ""
	}
	
	ProjectSettings.add_property_info(property_info)
