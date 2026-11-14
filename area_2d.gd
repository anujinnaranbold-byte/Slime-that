extends Area2D

@export var connected_portal: Area2D

var can_teleport = true

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and can_teleport:
		can_teleport = false

		body.global_position = connected_portal.global_position

		connected_portal.can_teleport = false

		await get_tree().create_timer(0.3).timeout

		can_teleport = true
		connected_portal.can_teleport = true
