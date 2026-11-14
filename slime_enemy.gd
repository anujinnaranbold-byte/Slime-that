extends Node2D

var is_boss := false
var manager: Node
var max_health := 100.0
var health := 100.0
var move_speed := 58.0
var touch_damage := 10.0
var attack_timer := 0.0
var flash_timer := 0.0

func _ready() -> void:
	if is_boss:
		max_health = 520.0
		health = max_health
		move_speed = 43.0
		touch_damage = 18.0
	else:
		max_health = 100.0
		health = max_health

func pursue(player: CharacterBody2D, delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	var offset := player.global_position - global_position
	var distance := offset.length()
	var contact_range := 45.0 if is_boss else 29.0
	if distance > contact_range:
		global_position += offset.normalized() * move_speed * delta
	elif attack_timer <= 0.0:
		player.call("take_damage", touch_damage)
		attack_timer = 1.0
	queue_redraw()

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	flash_timer = 0.12
	if health <= 0.0:
		if is_instance_valid(manager):
			manager.call("enemy_died", self)
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var radius := 29.0 if is_boss else 16.0
	var body_color := Color("8f3f84") if is_boss else Color("70bd3b")
	if flash_timer > 0.0:
		body_color = Color("fff1b8")
	draw_circle(Vector2(0, radius * 0.55), radius + 2.0, Color(0.02, 0.03, 0.04, 0.38))
	draw_circle(Vector2.ZERO, radius + 2.0, Color("203329"))
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.15), maxf(2.0, radius * 0.11), Color("17221a"))
	draw_circle(Vector2(radius * 0.3, -radius * 0.15), maxf(2.0, radius * 0.11), Color("17221a"))
	var bar_width := 92.0 if is_boss else 44.0
	var bar_y := -radius - (29.0 if is_boss else 16.0)
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, 8.0), Color("17151b"))
	draw_rect(Rect2(-bar_width / 2.0 + 1.0, bar_y + 1.0, (bar_width - 2.0) * health / max_health, 6.0), Color("ed4152"))
	if is_boss:
		draw_string(ThemeDB.fallback_font, Vector2(-38, bar_y - 4), "SLIME WARDEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
