extends CharacterBody2D

const WALK_SPEED := 165.0
const SPRINT_SPEED := 250.0
const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_camera: Camera2D = $Camera2D
@onready var gun: Node2D = $Gun

var game_manager: Node
var health := MAX_HEALTH
var max_health := MAX_HEALTH
var stamina := MAX_STAMINA
var max_stamina := MAX_STAMINA
var animation_direction := "down"
var invulnerability_timer := 0.0

func _ready() -> void:
	collision_layer = 2
	# The map disables collision on painted ground and enables it on solid scenery.
	collision_mask = 1
	player_camera.enabled = true
	player_camera.zoom = Vector2(2.25, 2.25)
	player_camera.position_smoothing_enabled = true
	player_camera.position_smoothing_speed = 6.0
	player_camera.make_current()
	_add_gun_visual()

func _add_gun_visual() -> void:
	gun.z_index = 2
	var body := Polygon2D.new()
	body.name = "GunBodyVisual"
	body.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(13, -5), Vector2(18, -2), Vector2(18, 2), Vector2(13, 5), Vector2(-5, 5)])
	body.color = Color("4c3840")
	gun.add_child(body)
	var barrel := Polygon2D.new()
	barrel.name = "GunBarrelVisual"
	barrel.polygon = PackedVector2Array([Vector2(8, -2), Vector2(24, -2), Vector2(24, 2), Vector2(8, 2)])
	barrel.color = Color("d0bd7c")
	gun.add_child(barrel)

func _physics_process(delta: float) -> void:
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	if is_instance_valid(game_manager) and game_manager.shop_open:
		velocity = Vector2.ZERO
		return

	var direction := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	).normalized()
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and stamina > 1.0 and direction.length_squared() > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - 34.0 * delta)
	else:
		stamina = minf(max_stamina, stamina + 23.0 * delta)

	velocity = direction * (SPRINT_SPEED if sprinting else WALK_SPEED)
	move_and_slide()

	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			animation_direction = "right" if direction.x > 0 else "left"
		else:
			animation_direction = "down" if direction.y > 0 else "up"
		animated_sprite_2d.play("move_" + animation_direction)
	else:
		animated_sprite_2d.play("idle_" + animation_direction)

	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() > 1.0:
		gun.rotation = aim.angle()

func take_damage(amount: float) -> void:
	if invulnerability_timer > 0.0:
		return
	invulnerability_timer = 0.55
	health = maxf(0.0, health - amount)
	if health <= 0.0 and is_instance_valid(game_manager):
		game_manager.call("player_recovered")
