extends Resource

## Fallback implementation if no `SceneNodePath` implementation is provided.
## Only used to avoid compile errors. Please implement copy this file and
## use `class_name SceneNodePath`.

@export_file var scene_path: String
@export var node_path: String
