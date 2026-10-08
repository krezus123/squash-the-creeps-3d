extends CharacterBody3D

signal hit

# How fast the player moves in meters per second.
@export var speed = 14
# The downward acceleration while in the air, in meters per second squared.
@export var fall_acceleration = 75
# Vertical impulse applied to the character upon jumping in meters per second.
@export var jump_impulse = 20
# Vertical impulse applied to the character upon bouncing over a mob
# in meters per second.
@export var bounce_impulse = 16
# Maximum jumps allowed before touching ground (2 for Double Jump).
@export var max_jumps = 2

# Limites pour maintenir le joueur dans le champ de vision de la caméra
@export var min_x: float = -12.5
@export var max_x: float = 12.5
@export var min_z: float = -13.0
@export var max_z: float = 13.0

var target_velocity = Vector3.ZERO
var jump_count = 0


func _physics_process(delta):
	# We create a local variable to store the input direction
	var direction = Vector3.ZERO

	# We check for each move input and update the direction accordingly
	if Input.is_action_pressed("move_right"):
		direction.x = direction.x + 1
	if Input.is_action_pressed("move_left"):
		direction.x = direction.x - 1
	if Input.is_action_pressed("move_back"):
		direction.z = direction.z + 1
	if Input.is_action_pressed("move_forward"):
		direction.z = direction.z - 1

	# Prevent diagonal movement being very fast
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		# Setting the basis property will affect the rotation of the node.
		$Pivot.basis = Basis.looking_at(direction)
		$AnimationPlayer.speed_scale = 4
	else:
		$AnimationPlayer.speed_scale = 1

	if has_node("DustTrail"):
		$DustTrail.emitting = is_on_floor() and direction != Vector3.ZERO

	# Ground Velocity
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# Vertical Velocity
	if not is_on_floor(): # If in the air, fall towards the floor
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
	else:
		jump_count = 0

	# Jumping and Double Jumping
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			target_velocity.y = jump_impulse
			jump_count = 1
		elif jump_count < max_jumps:
			target_velocity.y = jump_impulse * 0.95
			jump_count += 1
			# Squash & stretch feedback on double jump
			var tween = create_tween()
			tween.tween_property($Pivot, "scale", Vector3(0.85, 1.25, 0.85), 0.08)
			tween.tween_property($Pivot, "scale", Vector3(1.0, 1.0, 1.0), 0.1)

			animate_hat_bounce()
			spawn_boing_text()

	# Iterate through all collisions that occurred this frame
	for index in range(get_slide_collision_count()):
		var collision = get_slide_collision(index)

		# If the collision is with ground
		if collision.get_collider() == null:
			continue

		# If the collider is with a mob
		if collision.get_collider().is_in_group("mob"):
			var mob = collision.get_collider()
			if mob.get("is_squashed") == true:
				continue
			# Check that we are hitting it from above
			if Vector3.UP.dot(collision.get_normal()) > 0.1:
				mob.squash()
				target_velocity.y = bounce_impulse
				jump_count = 0 # Can jump again after stomping a mob!
				break

	# Moving the Character
	velocity = target_velocity
	move_and_slide()

	# Empêcher le joueur de sortir du champ de vision de la caméra
	position.x = clampf(position.x, min_x, max_x)
	position.z = clampf(position.z, min_z, max_z)

	$Pivot.rotation.x = PI / 6 * velocity.y / jump_impulse

func die():
	hit.emit()
	queue_free()

func _on_mob_detector_body_entered(body):
	if body.is_in_group("mob") and body.get("is_squashed") == true:
		return
	die()

func animate_hat_bounce() -> void:
	var hat = get_node_or_null("Pivot/Character/ConeHat")
	if hat:
		var hat_tween = create_tween()
		hat_tween.tween_property(hat, "position:y", 0.95, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hat_tween.tween_property(hat, "position:y", 0.65, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func spawn_boing_text() -> void:
	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.text = "BOING !"
	label.font_size = 52
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.1, 0.1, 0.9)
	label.modulate = Color(1.0, 0.86, 0.15, 1.0) # Jaune vif cartoon
	label.position = global_position + Vector3(0, 1.6, 0)

	if get_parent():
		get_parent().add_child(label)
	else:
		add_child(label)

	var tween = create_tween()
	label.scale = Vector3(0.5, 0.5, 0.5)
	tween.tween_property(label, "scale", Vector3(1.25, 1.25, 1.25), 0.08)
	tween.tween_property(label, "scale", Vector3(1.0, 1.0, 1.0), 0.06)
	tween.parallel().tween_property(label, "position:y", label.position.y + 1.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tween.tween_callback(label.queue_free)
