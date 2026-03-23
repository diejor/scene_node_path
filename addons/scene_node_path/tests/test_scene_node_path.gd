class_name SceneNodePathTest
extends GdUnitTestSuite

const PLAYER_SCENE := "uid://cskn5w06l6wjy"
const LEVEL_SCENE := "uid://cx70mn2ywq126"


var active_impls: Array[Script] = []

func before() -> void:
	active_impls.append(SceneNodePath) 
	
	if ClassDB.class_exists("CSharpScript"):
		var cs_script: Script = load("uid://bj2k7avaeljdf")
		if cs_script and cs_script.can_instantiate():
			active_impls.append(cs_script)
		else:
			push_warning("C# script found but not compiled. Build the solution to test C# parity.")
			
	print_rich("[color=green][SceneNodePathTest][/color] Active Implementations: ", get_impls_names())

func get_impls_names() -> Array:
	return active_impls.map(func(script: Script) -> StringName:
		return script.get_global_name())

func _get_lang(obj: Object) -> String:
	return "C#" if obj.get_script().resource_path.ends_with(".cs") else "GDScript"

func _create_paths(scene: String, node: String) -> Array[Object]:
	var instances: Array[Object] = []
	for script in active_impls:
		var inst: Object = auto_free(script.new())
		DuckTypeHelper.set_duck(inst, "scene_path", scene)
		DuckTypeHelper.set_duck(inst, "node_path", node)
		instances.append(inst)
	return instances

func _create_parsed_paths(formatted_string: String) -> Array[Object]:
	var instances: Array[Object] = []
	for script in active_impls:
		var inst: Object = auto_free(script.new())
		DuckTypeHelper.call_duck(inst, "parse", [formatted_string])
		instances.append(inst)
	return instances

# --- TESTS ---

@warning_ignore("unused_parameter")
func test_init_parsing(formatted_string: String, expected_scene: String, expected_node: String, test_parameters := [
	["res://fake.tscn::Player", "res://fake.tscn", "Player"],
	["uid://fake_uid::Level/Boss", "uid://fake_uid", "Level/Boss"],
]) -> void:
	for path in _create_parsed_paths(formatted_string):
		var lang := _get_lang(path)
		var s: String = DuckTypeHelper.get_duck(path, "scene_path")
		var n: String = DuckTypeHelper.get_duck(path, "node_path")
		
		assert_that(s).override_failure_message("%s failed scene parse." % lang).is_equal(expected_scene)
		assert_that(n).override_failure_message("%s failed node parse." % lang).is_equal(expected_node)

func test_string_formatters() -> void:
	for path in _create_paths(PLAYER_SCENE, "Hitbox"):
		var lang := _get_lang(path)
		var as_uid: String = DuckTypeHelper.call_duck(path, "as_uid")
		var as_path: String = DuckTypeHelper.call_duck(path, "as_path")
		
		assert_that(as_uid).override_failure_message("%s: as_uid() failed." % lang).is_equal("uid://cskn5w06l6wjy::Hitbox")
		# as_path resolves the UID to the real path, so it should end with the file name
		assert_that(as_path).override_failure_message("%s: as_path() failed." % lang).contains("mock_player.tscn::Hitbox")

func test_name_extractors_and_offsets() -> void:
	# Note: DeepSecret uses the '%' unique name syntax in the string
	for path in _create_paths(LEVEL_SCENE, "Player/Hitbox/%DeepSecret"):
		var lang := _get_lang(path)
		
		# Scene Name
		var scene_name: String = DuckTypeHelper.call_duck(path, "get_scene_name")
		assert_that(scene_name).override_failure_message("%s: scene name failed." % lang).is_equal("mock_level")
		
		# Node Name with offsets (0 = target, 1 = parent, 2 = grandparent)
		var n0: String = DuckTypeHelper.call_duck(path, "get_node_name", [0])
		var n1: String = DuckTypeHelper.call_duck(path, "get_node_name", [1])
		var n2: String = DuckTypeHelper.call_duck(path, "get_node_name", [2])
		var n3: String = DuckTypeHelper.call_duck(path, "get_node_name", [3]) # Out of bounds
		
		# It should automatically strip the '%' from DeepSecret
		assert_that(n0).override_failure_message("%s: offset 0 failed." % lang).is_equal("DeepSecret")
		assert_that(n1).override_failure_message("%s: offset 1 failed." % lang).is_equal("Hitbox")
		assert_that(n2).override_failure_message("%s: offset 2 failed." % lang).is_equal("Player")
		assert_that(n3).override_failure_message("%s: out of bounds offset failed." % lang).is_empty()

@warning_ignore("unused_parameter")
func test_validation_checks(scene: String, node: String, expect_surface: bool, expect_deep: bool, test_parameters := [
	[LEVEL_SCENE, "Player/Hitbox", true, true],
	[LEVEL_SCENE, ".", true, true],
	[LEVEL_SCENE, "FakeNode", true, false],
	["res://missing.tscn", "Hitbox", false, false],
	[LEVEL_SCENE, "", false, false]
]) -> void:
	for path in _create_paths(scene, node):
		var lang := _get_lang(path)
		assert_that(DuckTypeHelper.call_duck(path, "is_valid")).override_failure_message("%s surface validation failed." % lang).is_equal(expect_surface)
		
		var inspector: Object = DuckTypeHelper.call_duck(path, "peek")
		assert_that(DuckTypeHelper.call_duck(inspector, "is_valid")).override_failure_message("%s deep validation failed." % lang).is_equal(expect_deep)

func test_state_inspector_basic_properties() -> void:
	for path in _create_paths(PLAYER_SCENE, "Hitbox"):
		var lang := _get_lang(path)
		var inspector: Object = DuckTypeHelper.call_duck(path, "peek")
		
		assert_that(DuckTypeHelper.call_duck(inspector, "is_valid")).override_failure_message("%s: inspector invalid." % lang).is_true()
		assert_that(DuckTypeHelper.call_duck(inspector, "get_node_type")).override_failure_message("%s: wrong node type." % lang).is_equal(&"Area2D")
		assert_that(DuckTypeHelper.call_duck(inspector, "get_property", ["monitoring", true])).override_failure_message("%s: wrong property read." % lang).is_equal(false)

func test_extract_isolates_nested_node_and_frees_parents() -> void:
	for path in _create_paths(LEVEL_SCENE, "Player/Hitbox"):
		var lang := _get_lang(path)
		var target: Node = auto_free(DuckTypeHelper.call_duck(path, "extract"))
		
		assert_that(target).override_failure_message("%s: extract returned null." % lang).is_not_null()
		assert_that(target.get_parent()).override_failure_message("%s: parent was not freed." % lang).is_null()
		assert_that(target.owner).override_failure_message("%s: owner was not cleared." % lang).is_null()

@warning_ignore("unused_parameter")
func test_extract_or_null_safe_failures(scene: String, node: String, test_parameters := [
	[LEVEL_SCENE, "FakeNode"],
	["res://missing.tscn", "Hitbox"],
	[LEVEL_SCENE, ""]
]) -> void:
	for path in _create_paths(scene, node):
		var lang := _get_lang(path)
		var result = DuckTypeHelper.call_duck(path, "extract_or_null")
		assert_that(result).override_failure_message("%s: safe failure returned an object instead of null." % lang).is_null()

func test_state_inspector_deep_recursion_resolution() -> void:
	for path in _create_paths(LEVEL_SCENE, "Player/Hitbox/DeepSecret"):
		var lang := _get_lang(path)
		var inspector: Object = DuckTypeHelper.call_duck(path, "peek")
		
		assert_that(DuckTypeHelper.call_duck(inspector, "is_valid")) \
			.override_failure_message("%s: Failed to recursively resolve DeepSecret inside the instanced player." % lang) \
			.is_true()
			
		assert_that(DuckTypeHelper.call_duck(inspector, "get_node_type")) \
			.override_failure_message("%s: Deep recursion type mismatch." % lang) \
			.is_equal(&"Node")

func test_state_inspector_groups_and_instances() -> void:
	for path in _create_paths(PLAYER_SCENE, "."): # Testing the root node
		var lang := _get_lang(path)
		var inspector: Object = DuckTypeHelper.call_duck(path, "peek")
		
		var groups: PackedStringArray = DuckTypeHelper.call_duck(inspector, "get_groups")
		assert_that(groups).override_failure_message("%s: Groups array empty or invalid." % lang).contains("entities")
		
		var props: Dictionary = DuckTypeHelper.call_duck(inspector, "get_properties")
		assert_that(props).override_failure_message("%s: Failed to return full properties dict." % lang).contains_key_value("visible", false)

func test_instantiate_and_manual_attachment() -> void:
	for path in _create_paths(LEVEL_SCENE, "Player/Hitbox"):
		var lang := _get_lang(path)
		
		# Test Instantiate
		var result: Object = DuckTypeHelper.call_duck(path, "instantiate_or_null")
		assert_that(result).override_failure_message("%s: instantiate_or_null failed on valid target." % lang).is_not_null()
		
		var root: Node = auto_free(DuckTypeHelper.get_duck(result, "root"))
		var target: Node = DuckTypeHelper.get_duck(result, "node")
		
		assert_that(root).override_failure_message("%s: result.root is null." % lang).is_not_null()
		assert_that(target).override_failure_message("%s: result.node is null." % lang).is_not_null()
		
		# Manual attachment
		var parent := auto_free(Node.new())
		parent.add_child(root)
		
		assert_that(root.get_parent()).is_equal(parent)
		assert_that(target.name).is_equal("Hitbox")
		assert_that(root.name).is_equal("Level")
