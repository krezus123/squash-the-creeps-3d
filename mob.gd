extends CharacterBody3D

@export var min_speed = 10.0
@export var max_speed = 18.0

signal squashed(points: int, death_position: Vector3)

enum MobType { NORMAL, SPRINTER }
var mob_type: MobType = MobType.NORMAL
var score_value: int = 1
var is_squashed: bool = false

func _physics_process(_delta):
	move_and_slide()

func initialize(start_position, player_position):
	var sphere_mesh = $Pivot/Character.get_node_or_null("Sphere")

	if randf() < 0.30:
		mob_type = MobType.SPRINTER
		score_value = 2
		min_speed = 20.0
		max_speed = 25.0
		$Pivot.scale = Vector3(0.85, 0.85, 0.85)
		
		var sprinter_mat = StandardMaterial3D.new()
		sprinter_mat.albedo_color = Color(0.96, 0.22, 0.12)
		sprinter_mat.roughness = 0.35
		if sphere_mesh:
			sphere_mesh.set_surface_override_material(1, sprinter_mat)
	else:
		mob_type = MobType.NORMAL
		score_value = 1
		min_speed = 9.0
		max_speed = 12.0
		$Pivot.scale = Vector3(1.0, 1.0, 1.0)
		if sphere_mesh:
			sphere_mesh.set_surface_override_material(1, null)

	look_at_from_position(start_position, player_position, Vector3.UP)
	rotate_y(randf_range(-PI / 4, PI / 4))

	var random_speed = randf_range(min_speed, max_speed)
	velocity = Vector3.FORWARD * random_speed
	velocity = velocity.rotated(Vector3.UP, rotation.y)

	$AnimationPlayer.speed_scale = random_speed / 10.0

func _on_visible_on_screen_notifier_3d_screen_exited():
	queue_free()

func squash():
	if is_squashed:
		return
	is_squashed = true
	var death_pos = global_position if is_inside_tree() else position
	squashed.emit(score_value, death_pos)
	queue_free()
