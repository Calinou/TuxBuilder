extends Node2D

onready var editmode = false
onready var editsaved = false # Using an edited version of a level
var can_edit = true
var current_level = ""
var player_position = Vector2()
var player_position_map = Vector2() # If the player entered the level from the map
var map_camera = Vector2() # The worldmap's camera position
var level_bound_left = 0
var level_bound_right = 0
var level_bound_bottom = 0
var level_bound_top = 0
var camera_smooth_time = 0
var camera_zoom = 1
var camera_zoom_speed = 20
onready var worldmap = "" # The worldmap you started in

func _ready():
	load_level("res://Scenes//Worldmaps//Main.tscn")
	load_player()
	load_editor()
	load_ui()
	level_bounds()

func _process(_delta):
	if camera_zoom_speed < 1: camera_zoom_speed = 1
	if camera_zoom < 0.25: camera_zoom = 0.25
	if camera_zoom > 1.5: camera_zoom = 1.5
	$Camera2D.zoom.x = $Camera2D.zoom.x + (camera_zoom - $Camera2D.zoom.x) / camera_zoom_speed
	$Camera2D.zoom.y = $Camera2D.zoom.x
	
	if get_viewport().size.x > get_viewport().size.y:
		$CanvasLayer/CircleTransition.rect_size.x = get_viewport().size.x
		$CanvasLayer/CircleTransition.rect_size.y = get_viewport().size.x
		$CanvasLayer/CircleTransition.rect_position.y = 0.5 * (get_viewport().size.y - get_viewport().size.x)
	else:
		$CanvasLayer/CircleTransition.rect_size.x = get_viewport().size.y
		$CanvasLayer/CircleTransition.rect_size.y = get_viewport().size.y
		$CanvasLayer/CircleTransition.rect_position.x = 0.5 * (get_viewport().size.x - get_viewport().size.y)
	
	if editmode == false:
		level_bounds()
		camera_to_level_bounds()
		if camera_smooth_time == 0 and !UIHelpers.get_level().worldmap:
			$Camera2D.drag_margin_v_enabled = true
	else:
		camera_bounds_remove()
		$Camera2D.drag_margin_h_enabled = false
		$Camera2D.drag_margin_v_enabled = false
	
	if camera_smooth_time > 0:
		$Camera2D.smoothing_enabled = true
		camera_smooth_time -= 1
		if camera_smooth_time < 10:
			$Camera2D.smoothing_speed += 3
		else: $Camera2D.smoothing_speed = 10
	else:
		$Camera2D.smoothing_enabled = false
		$Camera2D.smoothing_speed = 10
		camera_smooth_time = 0

func load_level_from_map(level):
	current_level = level
	editmode = false
	player_position_map = UIHelpers.get_player().position
	map_camera = UIHelpers.get_camera().position
	$CanvasLayer/AnimationPlayer.play("Circle Out")
	yield(get_node("CanvasLayer/AnimationPlayer"), "animation_finished")
	camera_zoom = 1
	camera_zoom_speed = 1
	clear_ui()
	clear_player()
	clear_level()
	load_level(level)
	load_ui()
	load_player()
	$CanvasLayer/AnimationPlayer.play("Circle In")

func return_to_map():
	if worldmap != "":
		editmode = false
		$CanvasLayer/AnimationPlayer.play("Circle Out")
		yield(get_node("CanvasLayer/AnimationPlayer"), "animation_finished")
		camera_zoom = 1
		camera_zoom_speed = 1
		clear_ui()
		clear_player()
		clear_level()
		load_level(worldmap)
		load_ui()
		load_player()
		UIHelpers.get_player().position = player_position_map
		UIHelpers.get_camera().position = map_camera
		$CanvasLayer/AnimationPlayer.play("Circle In")

func restart_level():
	editmode = false
	$CanvasLayer/AnimationPlayer.play("Circle Out")
	yield(get_node("CanvasLayer/AnimationPlayer"), "animation_finished")
	camera_zoom = 1
	camera_zoom_speed = 1
	clear_ui()
	clear_player()
	clear_level()
	if !editsaved or (worldmap != "" and current_level != worldmap):
		load_level(current_level)
	else: load_edited_level()
	load_ui()
	load_player()
	$CanvasLayer/AnimationPlayer.play("Circle In")

func open_level():
	UIHelpers.file_dialog("res://Scenes//Levels/") # Bring up file select
	
	yield(UIHelpers._get_scene().get_node("FileSelect"), "tree_exiting")
	var selectdir = UIHelpers._get_scene().get_node("FileSelect").selectdir
	if check_level_valid(selectdir) == true:
		camera_zoom = 1
		camera_zoom_speed = 1
		editsaved = false
		clear_level()
		clear_player()
		load_level(selectdir)
		load_player()
		yield(UIHelpers.get_level(), "ready")
		yield(UIHelpers.get_player(), "ready")
		UIHelpers.get_editor()._ready()

func save_level():
	var packed_scene = PackedScene.new()
	packed_scene.pack(get_tree().get_current_scene().get_node("Level"))
	ResourceSaver.save(current_level, packed_scene)

func save_level_as():
	UIHelpers.file_dialog("res://Scenes//Levels/") # Bring up file select
	
	yield(UIHelpers._get_scene().get_node("FileSelect"), "tree_exiting")
	var selectdir = UIHelpers._get_scene().get_node("FileSelect").selectdir
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(get_tree().get_current_scene().get_node("Level"))
	ResourceSaver.save(selectdir, packed_scene)

func save_edited_level():
	var packed_scene = PackedScene.new()
	var directory = Directory.new()
	packed_scene.pack(get_tree().get_current_scene().get_node("Level"))

	if not directory.dir_exists("user://Scenes/Levels/EditedLevel"):
		directory.make_dir_recursive("user://Scenes/Levels/EditedLevel")

	ResourceSaver.save("user://Scenes/Levels/EditedLevel/EditedLevel.tscn", packed_scene)
	editsaved = true

func load_edited_level():
	load_level("user://Scenes/Levels/EditedLevel/EditedLevel.tscn")

func load_level(level):
	current_level = level
	var directory = Directory.new()
	if directory.file_exists(level):
		var levelinstance = load(level).instance()
		if levelinstance.worldmap:
			worldmap = level
		levelinstance.set_name("Level")
		add_child(levelinstance)
		level_to_grid()

func level_to_grid():
	for child in get_tree().current_scene.get_node("Level").get_children():
		if not child.is_in_group("tilemap"):
			child.position.x = floor(child.position.x / 32) * 32
			child.position.y = floor(child.position.y / 32) * 32
			child.position.x += 16
			child.position.y += 16

func clear_level():
	var scene = get_node("Level")
	remove_child(scene)
	scene.call_deferred("free")

func load_editor():
	_load_node("res://Scenes/UI/LevelEditor.tscn", "Editor")

func clear_editor():
	var scene = get_node("Editor")
	remove_child(scene)

func load_ui():
	_load_node("res://Scenes/UI/LevelUI.tscn", "LevelUI")

func _load_node(scene_path, node_name):
	var scene = load(scene_path).instance()
	scene.set_name(node_name)
	add_child(scene)

func _clear_node(node_name):
	var node = get_node(node_name)
	for i in node.get_children():
		i.queue_free()
	remove_child(node)
	node.call_deferred("free")

func clear_ui():
	_clear_node("LevelUI")

func load_player():
	if UIHelpers.get_level().worldmap:
		_load_node("res://Scenes/Player/Worldmap.tscn", "Player")
	else:
		_load_node("res://Scenes/Player/Player.tscn", "Player")

func clear_player():
	_clear_node("Player")

func level_bounds():
	level_bound_left = 0
	level_bound_right = 0
	level_bound_top = 0
	level_bound_bottom = 0

	for child in get_tree().get_nodes_in_group("tilemap"):
		var child_name = child.get_name()
		var level = get_tree().current_scene.get_node(str("Level/", child_name))
		var rect = level.get_used_rect()
		var cell_size = level.get_cell_size()
		
		var bound_left = rect.position.x * ((cell_size.x * level.scale.x) / level.scroll_speed.x)
		var bound_right = rect.end.x * ((cell_size.x * level.scale.x) / level.scroll_speed.x)
		var bound_top = rect.position.y * ((cell_size.y * level.scale.y) / level.scroll_speed.y)
		var bound_bottom = rect.end.y * ((cell_size.y * level.scale.y) / level.scroll_speed.y)
		
		if bound_left < level_bound_left:
			level_bound_left = bound_left
		
		if bound_right > level_bound_right:
			level_bound_right = bound_right
		
		if bound_top < level_bound_top:
			level_bound_top = bound_top
		
		if  bound_bottom > level_bound_bottom:
			level_bound_bottom = bound_bottom

func camera_bounds_remove():
	$Camera2D.limit_left = -10000000
	$Camera2D.limit_right = 10000000
	$Camera2D.limit_top = -10000000
	$Camera2D.limit_bottom = 10000000

func camera_to_level_bounds():
	$Camera2D.limit_left = level_bound_left
	$Camera2D.limit_right = level_bound_right
	if $Camera2D.limit_right < get_viewport().size.x: # If the tilemap is thinner than the window, align the camera to the left
		$Camera2D.limit_right = get_viewport().size.x
	$Camera2D.limit_top = level_bound_top - get_viewport().size.y * 0.5
	$Camera2D.limit_bottom = level_bound_bottom

func play_music(music):
	$Music.stop()
	$Music.play()

func editmode_toggle():
	if $CanvasLayer/AnimationPlayer.is_playing() == false and can_edit == true:
		if editmode == false:
			editmode = true
			# Store if the previous level was a worldmap
			var prevworldmap = UIHelpers.get_level().worldmap
			player_position = UIHelpers.get_player().position
			clear_ui()
			clear_player()
			clear_level()
			if editsaved == false:
				if worldmap == "":
					load_level(current_level)
				else: load_level(worldmap)
			else: load_edited_level()
			load_player()
			
			# Only move the player if the current level is the same type as the previous
			if UIHelpers.get_level().worldmap == prevworldmap:
				UIHelpers.get_player().position = player_position
			else:
				UIHelpers.get_player().position = player_position_map
				UIHelpers.get_camera().position = map_camera
			
		elif get_node("Editor").dragging_object == false:
			editmode = false
			camera_smooth_time = 20
			save_edited_level()
			clear_level()
			if editsaved == false:
				load_level(current_level)
			else: load_edited_level()
			load_ui()

# Make sure a level is valid by checking its filetype and if it has a level name (utterly foolproof)
func check_level_valid(dir):
	if ".tscn" in dir:
		if load(dir).instance().get("level_name") != null:
			return true
		else: return false
	else: return false