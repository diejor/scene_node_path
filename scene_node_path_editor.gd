@tool
extends EditorProperty

static var global_class_cache: Dictionary = {}
static var global_icon_cache: Dictionary = {}

var forced_allowed_class: String = "Node"
var is_builtin_class: bool = true
var custom_allowed_script: Script = null
var custom_icon: Texture2D = null

var _cached_scene_path: String = ""
var _cached_node_path: String = ""
var _cached_mod_time: int = 0
var _cached_is_broken: bool = true
var _cached_dynamic_class: String = "Node"

var main_btn: Button
var menu_btn: MenuButton
var file_dialog: EditorFileDialog
var node_dialog: ConfirmationDialog
var node_tree: Tree
var current_scene_lbl: LineEdit
var search_box: LineEdit
var show_all_btn: CheckButton
var allowed_icon: TextureRect
var allowed_class_lbl: Label
var temp_scene_instance: Node

func _init() -> void:
	_build_main_ui()
	_build_dialog_ui()

func _enter_tree() -> void:
	_resolve_class_type()
	_apply_theme_elements()

func _build_main_ui() -> void:
	var container = HBoxContainer.new()
	add_child(container)

	main_btn = Button.new()
	main_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_btn.clip_text = true
	main_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_btn.pressed.connect(_on_main_button_pressed)
	container.add_child(main_btn)

	menu_btn = MenuButton.new()
	menu_btn.flat = true
	
	var popup: PopupMenu = menu_btn.get_popup()
	popup.add_item("Change Scene", 0)
	popup.add_item("Copy as Absolute Path", 1)
	popup.add_item("Copy as UID", 2)
	popup.add_separator()
	popup.add_item("Clear", 4)
	popup.id_pressed.connect(_on_menu_id_pressed)
	
	container.add_child(menu_btn)

func _build_dialog_ui() -> void:
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.tscn", "PackedScene")
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)

	node_dialog = ConfirmationDialog.new()
	node_dialog.title = "Select Scene Node Path"
	node_dialog.size = Vector2(450, 600)
	node_dialog.confirmed.connect(_on_node_selected)
	node_dialog.canceled.connect(_clean_up_scene)
	node_dialog.about_to_popup.connect(func(): search_box.call_deferred("grab_focus"))
	
	var dialog_vbox = VBoxContainer.new()
	node_dialog.add_child(dialog_vbox)

	var scene_header = HBoxContainer.new()
	var change_scene_btn = Button.new()
	change_scene_btn.text = "Change Scene"
	change_scene_btn.pressed.connect(_show_file_dialog_from_node_dialog)
	scene_header.add_child(change_scene_btn)
	
	current_scene_lbl = LineEdit.new()
	current_scene_lbl.editable = false
	current_scene_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_header.add_child(current_scene_lbl)
	dialog_vbox.add_child(scene_header)

	var allowed_hbox = HBoxContainer.new()
	var allowed_lbl = Label.new()
	allowed_lbl.text = "Allowed:"
	
	allowed_icon = TextureRect.new()
	allowed_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	
	allowed_class_lbl = Label.new()
	allowed_class_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	allowed_hbox.add_child(allowed_lbl)
	allowed_hbox.add_child(allowed_icon)
	allowed_hbox.add_child(allowed_class_lbl)
	dialog_vbox.add_child(allowed_hbox)

	var search_hbox = HBoxContainer.new()
	search_box = LineEdit.new()
	search_box.placeholder_text = "Filter Nodes..."
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.clear_button_enabled = true
	search_box.text_changed.connect(_rebuild_tree)
	search_hbox.add_child(search_box)
	
	show_all_btn = CheckButton.new()
	show_all_btn.text = "Show All"
	show_all_btn.button_pressed = true
	show_all_btn.toggled.connect(_on_show_all_toggled)
	search_hbox.add_child(show_all_btn)
	dialog_vbox.add_child(search_hbox)

	node_tree = Tree.new()
	node_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node_tree.item_activated.connect(_on_node_selected)
	dialog_vbox.add_child(node_tree)
	
	add_child(node_dialog)

func _resolve_class_type() -> void:
	if forced_allowed_class == "Node" or ClassDB.class_exists(forced_allowed_class):
		is_builtin_class = true
		return

	is_builtin_class = false
	
	if global_class_cache.has(forced_allowed_class):
		custom_allowed_script = global_class_cache[forced_allowed_class]
		custom_icon = global_icon_cache.get(forced_allowed_class)
		return

	for class_data in ProjectSettings.get_global_class_list():
		if class_data["class"] == forced_allowed_class:
			custom_allowed_script = load(class_data["path"])
			global_class_cache[forced_allowed_class] = custom_allowed_script
			
			var icon_path: String = class_data.get("icon", "")
			if not icon_path.is_empty():
				custom_icon = load(icon_path)
				global_icon_cache[forced_allowed_class] = custom_icon
			break

func _apply_theme_elements() -> void:
	menu_btn.icon = get_theme_icon("GuiTabMenuHl", "EditorIcons")
	search_box.right_icon = get_theme_icon("Search", "EditorIcons")
	
	var popup: PopupMenu = menu_btn.get_popup()
	popup.set_item_icon(0, get_theme_icon("Load", "EditorIcons"))
	popup.set_item_icon(1, get_theme_icon("ActionCopy", "EditorIcons"))
	popup.set_item_icon(2, get_theme_icon("ActionCopy", "EditorIcons"))
	popup.set_item_icon(4, get_theme_icon("Clear", "EditorIcons"))
	
	var dark_stylebox: StyleBox = get_theme_stylebox("normal", "LineEdit")
	main_btn.add_theme_stylebox_override("normal", dark_stylebox)
	main_btn.add_theme_stylebox_override("hover", dark_stylebox)
	main_btn.add_theme_stylebox_override("focus", dark_stylebox)
	main_btn.add_theme_stylebox_override("pressed", dark_stylebox)

	allowed_class_lbl.text = "Any" if forced_allowed_class == "Node" else forced_allowed_class
	allowed_icon.texture = _get_class_icon(forced_allowed_class)

func _get_class_icon(class_name_str: String) -> Texture2D:
	if has_theme_icon(class_name_str, "EditorIcons"):
		return get_theme_icon(class_name_str, "EditorIcons")
	if custom_icon:
		return custom_icon
	return get_theme_icon("Node", "EditorIcons")

func _get_actual_scene_path(res: SceneNodePath) -> String:
	if res.scene_path.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(res.scene_path)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return res.scene_path

func _update_property() -> void:
	var res: SceneNodePath = get_edited_object()[get_edited_property()]
	main_btn.remove_theme_color_override("font_color")
	
	if not res or res.scene_path.is_empty():
		_apply_ui_state(false, false, "Assign Scene...", "Node")
		return

	var real_path: String = _get_actual_scene_path(res)
	
	if res.node_path.is_empty():
		_apply_ui_state(true, false, real_path.get_file() + " (Missing Node!)", "Node")
		return

	var current_mod_time: int = FileAccess.get_modified_time(real_path)
	
	if _is_cache_valid(res, current_mod_time):
		_apply_ui_state(_cached_is_broken, true, res.node_path, _cached_dynamic_class)
		return

	_update_cache_and_validate(real_path, res, current_mod_time)

func _is_cache_valid(res: SceneNodePath, current_mod_time: int) -> bool:
	return res.scene_path == _cached_scene_path and res.node_path == _cached_node_path and current_mod_time == _cached_mod_time

func _update_cache_and_validate(real_path: String, res: SceneNodePath, current_mod_time: int) -> void:
	var is_broken: bool = true
	var dynamic_class: String = forced_allowed_class

	if ResourceLoader.exists(real_path):
		var packed: PackedScene = load(real_path)
		if packed:
			var temp_instance: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			if temp_instance:
				var target_node: Node = temp_instance.get_node_or_null(res.node_path)
				if target_node:
					is_broken = false
					dynamic_class = target_node.get_class()
				temp_instance.free()

	_cached_scene_path = res.scene_path
	_cached_node_path = res.node_path
	_cached_mod_time = current_mod_time
	_cached_is_broken = is_broken
	_cached_dynamic_class = dynamic_class

	_apply_ui_state(is_broken, true, res.node_path, dynamic_class)

func _apply_ui_state(is_broken: bool, is_assigned: bool, display_text: String, dynamic_class: String) -> void:
	main_btn.text = display_text if not is_broken else display_text.get_file() + " (Broken Path!)"
	
	if not is_assigned:
		main_btn.icon = get_theme_icon("NodeWarning", "EditorIcons") if is_broken else null
		if is_broken:
			main_btn.add_theme_color_override("font_color", get_theme_color("warning_color", "Editor"))
		return

	if is_broken:
		main_btn.icon = get_theme_icon("NodeWarning", "EditorIcons")
		main_btn.add_theme_color_override("font_color", get_theme_color("warning_color", "Editor"))
	else:
		main_btn.icon = _get_class_icon(dynamic_class)

func _get_or_create_resource() -> SceneNodePath:
	var res: SceneNodePath = get_edited_object()[get_edited_property()]
	return res if res else SceneNodePath.new()

func _show_file_dialog_from_node_dialog() -> void:
	node_dialog.hide()
	file_dialog.popup_file_dialog()

func _on_main_button_pressed() -> void:
	var res: SceneNodePath = _get_or_create_resource()
	var real_path: String = _get_actual_scene_path(res)
	
	if real_path.is_empty() or not ResourceLoader.exists(real_path):
		file_dialog.popup_file_dialog()
	else:
		current_scene_lbl.text = real_path.get_file()
		_populate_tree(real_path)
		node_dialog.popup_centered()

func _on_menu_id_pressed(id: int) -> void:
	match id:
		0: file_dialog.popup_file_dialog()
		1: _copy_to_clipboard(false)
		2: _copy_to_clipboard(true)
		4: emit_changed(get_edited_property(), null)

func _copy_to_clipboard(use_uid: bool) -> void:
	var res: SceneNodePath = get_edited_object()[get_edited_property()]
	if not res:
		return
		
	var path_to_copy: String = res.scene_path
	
	if not use_uid:
		path_to_copy = _get_actual_scene_path(res)
	elif not path_to_copy.begins_with("uid://"):
		var uid: int = ResourceLoader.get_resource_uid(path_to_copy)
		if uid != ResourceUID.INVALID_ID:
			path_to_copy = ResourceUID.id_to_text(uid)
			
	DisplayServer.clipboard_set("%s::%s" % [path_to_copy, res.node_path])

func _on_file_selected(path: String) -> void:
	var res: SceneNodePath = _get_or_create_resource()
	var uid: int = ResourceLoader.get_resource_uid(path)
	
	res.scene_path = ResourceUID.id_to_text(uid) if uid != ResourceUID.INVALID_ID else path
	res.node_path = ""
	
	emit_changed(get_edited_property(), res)
	
	current_scene_lbl.text = path.get_file()
	_populate_tree(path)
	node_dialog.call_deferred("popup_centered")

func _on_node_selected() -> void:
	var selected: TreeItem = node_tree.get_selected()
	if not selected:
		return
		
	var res: SceneNodePath = _get_or_create_resource()
	var meta = selected.get_metadata(0) 
	
	if typeof(meta) == TYPE_DICTIONARY:
		res.node_path = meta.get("path", "")
		
	emit_changed(get_edited_property(), res)
	node_dialog.hide()
	_clean_up_scene()

func _clean_up_scene() -> void:
	if temp_scene_instance:
		temp_scene_instance.queue_free()
		temp_scene_instance = null
	search_box.text = ""

func _on_show_all_toggled(_toggled: bool) -> void:
	_rebuild_tree(search_box.text)

func _populate_tree(scene_path: String) -> void:
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene:
		if temp_scene_instance:
			temp_scene_instance.queue_free()
		temp_scene_instance = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		_rebuild_tree("")

func _rebuild_tree(filter: String = "") -> void:
	node_tree.clear()
	if not temp_scene_instance:
		return
		
	var root: TreeItem = node_tree.create_item()
	node_tree.hide_root = true
	_add_node_to_tree(temp_scene_instance, root, filter, show_all_btn.button_pressed)

func _is_node_allowed(node: Node) -> bool:
	if forced_allowed_class.is_empty() or forced_allowed_class == "Node":
		return true
		
	if is_builtin_class:
		return node.is_class(forced_allowed_class)
		
	if custom_allowed_script and node.get_script():
		var current_script: Script = node.get_script()
		while current_script:
			if current_script == custom_allowed_script:
				return true
			current_script = current_script.get_base_script()
			
	return false

func _add_node_to_tree(node: Node, parent_item: TreeItem, filter: String, show_all: bool) -> TreeItem:
	var item: TreeItem = node_tree.create_item(parent_item)
	item.set_text(0, node.name)
	
	var final_path: String = "%" + node.name if node.unique_name_in_owner else str(temp_scene_instance.get_path_to(node))

	item.set_metadata(0, {"path": final_path})
	item.set_icon(0, _get_class_icon(node.get_class()))
		
	var is_allowed: bool = _is_node_allowed(node)
		
	if not is_allowed:
		item.set_selectable(0, false)
		item.set_custom_color(0, Color(0.5, 0.5, 0.5, 0.5))
	
	var matches_filter: bool = filter.is_empty() or node.name.to_lower().contains(filter.to_lower())
	var is_valid_match: bool = matches_filter and (is_allowed or show_all)
	var has_valid_child: bool = false
	
	for child in node.get_children():
		var child_item: TreeItem = _add_node_to_tree(child, item, filter, show_all)
		if child_item != null:
			has_valid_child = true
			
	if not is_valid_match and not has_valid_child:
		item.free()
		return null
		
	if (not filter.is_empty() or not show_all) and has_valid_child:
		item.collapsed = false
		
	return item
