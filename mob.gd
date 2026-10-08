extends CharacterBody3D

# Minimum speed of the mob in meters per second.
@export var min_speed = 10.0
# Maximum speed of the mob in meters per second.
@export var max_speed = 18.0

# Emitted when the player jumped on the mob (carries score value and death position)
signal squashed(points: int, death_position: Vector3)

enum MobType { NORMAL, SPRINTER }
var mob_type: MobType = MobType.NORMAL
var score_value: int = 1
var is_squashed: bool = false

func _physics_process(_delta):
	move_and_slide()

# This function will be called from the Main scene.
func initialize(start_position, player_position):
	# ~35% chance to spawn a fast "Sprinter" mob
	if randf() < 0.35:
		mob_type = MobType.SPRINTER
		score_value = 2
		min_speed = 16.0
		max_speed = 24.0
		# Visual scale only, keeping collision box standard to ensure consistent hit detection
		$Pivot.scale = Vector3(0.85, 0.85, 0.85)
		
		# Give sprinter mob a distinctive red-orange body color
		var sprinter_mat = StandardMaterial3D.new()
		sprinter_mat.albedo_color = Color(0.96, 0.22, 0.12)
		sprinter_mat.roughness = 0.35
		var sphere_mesh = $Pivot/Character.get_node_or_null("Sphere")
		if sphere_mesh:
			sphere_mesh.set_surface_override_material(1, sprinter_mat)
	else:
		mob_type = MobType.NORMAL
		score_value = 1
		$Pivot.scale = Vector3(1.0, 1.0, 1.0)

	# We position the mob by placing it at start_position
	# and rotate it towards player_position, so it looks at the player.
	look_at_from_position(start_position, player_position, Vector3.UP)
	# Rotate this mob randomly within range of -45 and +45 degrees,
	# so that it doesn't move directly towards the player.
	rotate_y(randf_range(-PI / 4, PI / 4))

	# We calculate a random speed (float)
	var random_speed = randf_range(min_speed, max_speed)
	# We calculate a forward velocity that represents the speed.
	velocity = Vector3.FORWARD * random_speed
	# We then rotate the velocity vector based on the mob's Y rotation
	# in order to move in the direction the mob is looking.
	velocity = velocity.rotated(Vector3.UP, rotation.y)

	$AnimationPlayer.speed_scale = random_speed / min_speed

func _on_visible_on_screen_notifier_3d_screen_exited():
	queue_free()

func squash():
	if is_squashed:
		return
	is_squashed = true
	var death_pos = global_position if is_inside_tree() else position
	squashed.emit(score_value, death_pos)
	queue_free()
