extends Node2D

@export var village_scene: PackedScene
@export var dungeon_scene: PackedScene

func _ready() -> void:
	$VillageExit.body_entered.connect(_on_village_exit_entered)
	$DungeonEntrance.body_entered.connect(_on_dungeon_entrance_entered)

func _on_village_exit_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		go_to_scene(village_scene)

func _on_dungeon_entrance_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		go_to_scene(dungeon_scene)

func go_to_scene(scene: PackedScene) -> void:
	if scene == null:
		print("Choose the destination scene in the Forest Inspector.")
		return

	get_tree().change_scene_to_packed(scene)
