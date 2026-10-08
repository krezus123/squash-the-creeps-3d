extends Label

var score = 0

func _on_mob_squashed(points: int = 1):
	score += points
	text = "Score : %s" % score
	
	pivot_offset = size / 2.0
	var tween = create_tween()
	var punch_scale = Vector2(1.35, 1.35) if points > 1 else Vector2(1.2, 1.2)
	tween.tween_property(self, "scale", punch_scale, 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
