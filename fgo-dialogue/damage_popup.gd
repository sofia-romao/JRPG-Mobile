# DamagePopup.gd
extends Label

func display(value: int, global_pos: Vector2, color: Color = Color.WHITE) -> void:
	text = str(value)
	modulate = color
	global_position = global_pos
	pivot_offset = size / 2.0
	
	var tween = create_tween().set_parallel(true)
	
	var target_pos = global_position + Vector2(0, -40)
	tween.tween_property(self, "global_position", target_pos, 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	var transparent_color = Color(color.r, color.g, color.b, 0.0)
	tween.tween_property(self, "modulate", transparent_color, 0.5).set_delay(0.1)
		
	tween.chain().tween_callback(queue_free)
