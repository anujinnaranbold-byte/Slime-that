extends Sprite2D

const PLAYER_SCENE: PackedScene = preload("res://character_body_2d.tscn")
const ENEMY_SCRIPT: Script = preload("res://slime_enemy.gd")
const OVERLAY_SCRIPT: Script = preload("res://world_overlay.gd")
const VILLAGE_ENTRANCE := Vector2(673, 379)
const DUNGEON_EXIT := Vector2(7311, -769)
const DUNGEON_SPAWN := Vector2(7391, -769)
const SHOP_POSITION := Vector2(-180, 100)

var world: Node
var player_scene_root: Node2D
var player: CharacterBody2D
var enemies: Array[Node2D] = []
var bullets: Array[Dictionary] = []
var in_dungeon := false
var shop_open := false
var points := 0
var gun_damage := 25.0
var fire_delay := 0.32
var fire_timer := 0.0
var shot_flash := 0.0
var shot_start := Vector2.ZERO
var shot_end := Vector2.ZERO
var overlay: Node2D
var hud: CanvasLayer
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var points_label: Label
var hint_label: Label
var shop_panel: PanelContainer
var shop_points: Label
var shop_info: Label
var initialized := false

func _ready() -> void:
	call_deferred("_initialize_game")

func _initialize_game() -> void:
	world = get_parent()
	_setup_map_collisions()
	player_scene_root = PLAYER_SCENE.instantiate() as Node2D
	player = player_scene_root.get_node("CharacterBody2D") as CharacterBody2D
	player.set("game_manager", self)
	player_scene_root.position = Vector2.ZERO
	world.add_child(player_scene_root)

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.enabled = true
		camera.zoom = Vector2(2.25, 2.25)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 6.0
		camera.make_current()

	overlay = Node2D.new()
	overlay.set_script(OVERLAY_SCRIPT)
	overlay.set("manager", self)
	overlay.z_index = 1000
	overlay.z_as_relative = false
	world.add_child(overlay)

	_build_hud()
	_spawn_village_enemies()
	_update_hud()
	initialized = true

func _setup_map_collisions() -> void:
	var walkable_layers := ["ground", "paths", "dungeons floor", "another floor"]
	for layer_name in walkable_layers:
		var floor_layer := world.get_node_or_null(layer_name) as TileMapLayer
		if floor_layer and floor_layer.tile_set.get_physics_layers_count() > 0:
			floor_layer.tile_set.set_physics_layer_collision_layer(0, 0)
			floor_layer.tile_set.set_physics_layer_collision_mask(0, 0)

	var obstacle_layers := ["house1", "house2", "house3", "house4", "wooden fences", "bushes", "trees", "ruins", "walls", "lantern", "decor for dungeons"]
	for layer_name in obstacle_layers:
		var obstacle_layer := world.get_node_or_null(layer_name) as TileMapLayer
		if obstacle_layer == null or obstacle_layer.tile_set == null:
			continue
		var tile_set := obstacle_layer.tile_set
		if tile_set.get_physics_layers_count() == 0:
			tile_set.add_physics_layer()
		tile_set.set_physics_layer_collision_layer(0, 1)
		tile_set.set_physics_layer_collision_mask(0, 0)
		for cell in obstacle_layer.get_used_cells():
			var atlas_coords := obstacle_layer.get_cell_atlas_coords(cell)
			if layer_name == "trees" and atlas_coords.y not in [4, 8, 11]:
				continue
			var source := tile_set.get_source(obstacle_layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if source == null:
				continue
			var tile_data := source.get_tile_data(atlas_coords, obstacle_layer.get_cell_alternative_tile(cell))
			if tile_data == null or tile_data.get_collision_polygons_count(0) > 0:
				continue
			tile_data.set_collision_polygons_count(0, 1)
			if layer_name == "trees":
				tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-4, -5), Vector2(4, -5), Vector2(4, 6), Vector2(-4, 6)]))
			elif layer_name in ["bushes", "lantern", "decor for dungeons"]:
				tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(6, 7), Vector2(-6, 7)]))
			else:
				tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))

func _process(delta: float) -> void:
	if not initialized:
		return
	shot_flash = maxf(0.0, shot_flash - delta)
	fire_timer = maxf(0.0, fire_timer - delta)
	if not shop_open and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_timer <= 0.0:
		_fire()
	_update_bullets(delta)
	_update_hud()
	overlay.queue_redraw()

func _physics_process(delta: float) -> void:
	if not initialized:
		return
	if shop_open:
		player.velocity = Vector2.ZERO
		return
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.call("pursue", player, delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			_handle_interaction()
		elif event.keycode == KEY_ESCAPE and shop_open:
			_close_shop()

func _spawn_village_enemies() -> void:
	_spawn_enemy(Vector2(270, -180), false)
	_spawn_enemy(Vector2(420, 60), false)
	_spawn_enemy(Vector2(350, 500), false)

func _spawn_dungeon_enemies() -> void:
	_spawn_enemy(DUNGEON_EXIT + Vector2(160, 45), false)
	_spawn_enemy(DUNGEON_EXIT + Vector2(-130, 140), false)
	_spawn_enemy(DUNGEON_EXIT + Vector2(35, 260), false)
	_spawn_enemy(DUNGEON_EXIT + Vector2(300, 200), true)

func _spawn_enemy(at: Vector2, boss: bool) -> void:
	var enemy := ENEMY_SCRIPT.new() as Node2D
	enemy.position = at
	enemy.set("is_boss", boss)
	enemy.set("manager", self)
	enemy.z_index = 110
	enemy.z_as_relative = false
	world.add_child(enemy)
	enemies.append(enemy)

func enemy_died(enemy: Node2D) -> void:
	enemies.erase(enemy)
	points += 50 if enemy.get("is_boss") else 15
	_set_hint("Boss defeated! +50 points. Press E at the exit to return." if enemy.get("is_boss") else "+15 points — slime defeated.")

func _fire() -> void:
	var aim := get_global_mouse_position() - player.global_position
	if aim.length_squared() < 1.0:
		return
	var direction := aim.normalized()
	fire_timer = fire_delay
	bullets.append({
		"position": player.global_position + direction * 26.0,
		"velocity": direction * 620.0,
		"life": 1.4
	})

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[i]
		bullet.position += bullet.velocity * delta
		bullet.life -= delta
		var hit := false
		for enemy in enemies:
			if is_instance_valid(enemy) and bullet.position.distance_to(enemy.global_position) < (34.0 if enemy.get("is_boss") else 22.0):
				enemy.call("take_damage", gun_damage)
				hit = true
				break
		if hit or bullet.life <= 0.0:
			bullets.remove_at(i)
		else:
			bullets[i] = bullet

func _handle_interaction() -> void:
	if shop_open:
		_close_shop()
	elif in_dungeon and player.global_position.distance_to(DUNGEON_EXIT) < 150.0:
		_leave_dungeon()
	elif not in_dungeon and player.global_position.distance_to(VILLAGE_ENTRANCE) < 150.0:
		_enter_dungeon()
	elif not in_dungeon and player.global_position.distance_to(SHOP_POSITION) < 145.0:
		_open_shop()
	else:
		_set_hint("Move near the marked ruin or gunsmith, then press E.")

func _enter_dungeon() -> void:
	in_dungeon = true
	player.global_position = DUNGEON_SPAWN
	_clear_enemies()
	_spawn_dungeon_enemies()
	_set_hint("Dungeon entered. Defeat the slimes and the Slime Warden.")

func _leave_dungeon() -> void:
	in_dungeon = false
	player.global_position = VILLAGE_ENTRANCE + Vector2(-80, 25)
	_clear_enemies()
	_spawn_village_enemies()
	_set_hint("Back in the village. Your points and upgrades are saved.")

func _clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	bullets.clear()

func _open_shop() -> void:
	shop_open = true
	shop_panel.visible = true
	shop_info.text = "Choose an upgrade. Slimes are worth 15 points; the Warden is worth 50."
	_update_shop()

func _close_shop() -> void:
	shop_open = false
	shop_panel.visible = false

func _buy_damage() -> void:
	if points < 30:
		shop_info.text = "You need 30 points for this upgrade."
		return
	points -= 30
	gun_damage += 10.0
	shop_info.text = "Slime shot damage is now %.0f." % gun_damage
	_update_shop()

func _buy_speed() -> void:
	if points < 30:
		shop_info.text = "You need 30 points for this upgrade."
		return
	points -= 30
	fire_delay = maxf(0.12, fire_delay - 0.06)
	shop_info.text = "Your slime gun fires faster now."
	_update_shop()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 20
	world.add_child(hud)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.custom_minimum_size = Vector2(290, 166)
	hud.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "SLIME THAT!"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	var hp_caption := Label.new()
	hp_caption.text = "HEALTH"
	column.add_child(hp_caption)
	health_bar = _make_bar(Color(0.86, 0.2, 0.23))
	column.add_child(health_bar)
	var stamina_caption := Label.new()
	stamina_caption.text = "STAMINA"
	column.add_child(stamina_caption)
	stamina_bar = _make_bar(Color(0.2, 0.67, 0.9))
	column.add_child(stamina_bar)
	points_label = Label.new()
	column.add_child(points_label)

	hint_label = Label.new()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_left = 20
	hint_label.offset_top = -66
	hint_label.offset_right = -20
	hint_label.offset_bottom = -16
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hint_label)

	shop_panel = PanelContainer.new()
	shop_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shop_panel.position = Vector2(-200, -145)
	shop_panel.custom_minimum_size = Vector2(400, 290)
	shop_panel.visible = false
	hud.add_child(shop_panel)
	var shop_column := VBoxContainer.new()
	shop_panel.add_child(shop_column)
	var shop_title := Label.new()
	shop_title.text = "VILLAGE GUNSMITH"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.add_theme_font_size_override("font_size", 22)
	shop_column.add_child(shop_title)
	shop_points = Label.new()
	shop_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_column.add_child(shop_points)
	shop_info = Label.new()
	shop_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_column.add_child(shop_info)
	var damage_button := Button.new()
	damage_button.text = "Slime damage +10  •  30 points"
	damage_button.pressed.connect(_buy_damage)
	shop_column.add_child(damage_button)
	var speed_button := Button.new()
	speed_button.text = "Faster firing  •  30 points"
	speed_button.pressed.connect(_buy_speed)
	shop_column.add_child(speed_button)
	var close_button := Button.new()
	close_button.text = "Close (E / Esc)"
	close_button.pressed.connect(_close_shop)
	shop_column.add_child(close_button)

func _make_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(235, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _bar_style(color))
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.08, 0.09, 0.12)))
	return bar

func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _update_shop() -> void:
	shop_points.text = "Points: %d" % points

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	health_bar.max_value = float(player.get("max_health"))
	health_bar.value = float(player.get("health"))
	stamina_bar.max_value = float(player.get("max_stamina"))
	stamina_bar.value = float(player.get("stamina"))
	points_label.text = "Points: %d  •  Slime damage: %.0f" % [points, gun_damage]
	if in_dungeon:
		hint_label.text = "DUNGEON  •  Hold left-click to fire slime  •  Shift to sprint  •  E at the exit returns"
	else:
		hint_label.text = "WASD / arrows move  •  Shift sprint  •  Hold left-click to fire slime  •  E near ruin/shop"
	var title := hud.get_child(0).get_child(0).get_child(0) as Label
	title.text = "SLIME THAT!  •  %s" % ("DUNGEON" if in_dungeon else "VILLAGE")
	_update_shop()

func _set_hint(text: String) -> void:
	hint_label.text = text

func player_recovered() -> void:
	in_dungeon = false
	player.set("health", player.get("max_health"))
	player.global_position = Vector2.ZERO
	_clear_enemies()
	_spawn_village_enemies()

