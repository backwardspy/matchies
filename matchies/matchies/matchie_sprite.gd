extends Node2D


var hovered := false


func _process(dt: float) -> void:
	var target_scale := 1.3 if hovered else 1.0
	var target_scale_vec := Vector2(target_scale, target_scale)
	
	scale = lerp(scale, target_scale_vec, dt * 10)


func _on_mouse_area_mouse_entered() -> void:
	hovered = true
	UIAudio.get_node("hover").play(0.05)


func _on_mouse_area_mouse_exited() -> void:
	hovered = false
