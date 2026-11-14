extends Node2D

var manager

func _draw() -> void:
	if not is_instance_valid(manager) or not is_instance_valid(manager.player):
		return
	for bullet in manager.bullets:
		var p: Vector2 = bullet.position
		draw_circle(p, 8.0, Color("66d954"))
		draw_circle(p + Vector2(-2, -2), 3.0, Color("d7ffad"))
	if manager.shot_flash > 0.0:
		draw_line(manager.shot_start, manager.shot_end, Color(0.4, 0.85, 0.27, 0.6), 3.0, true)
	if not manager.in_dungeon:
		_draw_tag(manager.get("VILLAGE_ENTRANCE") + Vector2(0, 78), "PRESS E TO ENTER", Color("ffe58b"))
		_draw_shop()
		_draw_tag(manager.get("SHOP_POSITION") + Vector2(0, 54), "GUNSMITH  •  E", Color("a7f0ff"))
	else:
		_draw_tag(manager.get("DUNGEON_EXIT") + Vector2(0, 82), "PRESS E TO EXIT", Color("ffe58b"))

func _draw_tag(at: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var rect := Rect2(at - Vector2(width * 0.5 + 12.0, 14.0), Vector2(width + 24.0, 30.0))
	draw_rect(rect, Color(0.02, 0.035, 0.045, 0.9), true)
	draw_rect(rect, color, false, 2.0)
	draw_string(font, at - Vector2(width * 0.5, -6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)

func _draw_shop() -> void:
	var p: Vector2 = manager.get("SHOP_POSITION")
	draw_rect(Rect2(p + Vector2(-36, 8), Vector2(72, 9)), Color(0, 0, 0, 0.35), true)
	draw_rect(Rect2(p + Vector2(-34, -17), Vector2(68, 25)), Color("754523"), true)
	draw_rect(Rect2(p + Vector2(-39, -25), Vector2(78, 9)), Color("d19b57"), true)
	draw_rect(Rect2(p + Vector2(-36, -42), Vector2(72, 17)), Color("38809a"), true)
	draw_circle(p + Vector2(0, -58), 9, Color("edc09b"))
	draw_rect(Rect2(p + Vector2(-10, -50), Vector2(20, 19)), Color("d8b84e"), true)
	draw_rect(Rect2(p + Vector2(-13, -68), Vector2(26, 6)), Color("523426"), true)
