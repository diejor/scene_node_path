@tool
extends EditorPlugin

var inspector_plugin: EditorInspectorPlugin
const InspectorPlugin = preload("uid://di5tdm30ixtee")

func _enter_tree() -> void:
	inspector_plugin = InspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree() -> void:
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)
