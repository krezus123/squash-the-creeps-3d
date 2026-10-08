extends CharacterBody3D

signal hit
signal frenzy_started
signal frenzy_ended

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

# Variables Mode Frenzy (Invincibilité et vitesse)
var is_frenzy: bool = false
var frenzy_timer: float = 0.0
var base_speed: float = 14.0
var frenzy_speed: float = 23.0
var air_stomp_streak: int = 0
var golden_material: StandardMaterial3D = null
var frenzy_blink_timer: float = 0.0
var is_frenzy_blink_visible: bool = true

func _ready():
	base_speed = speed
	golden_material = StandardMaterial3D.new()
	golden_material.albedo_color = Color(1.0, 0.84, 0.0, 1.0)
	golden_material.metallic = 0.8
	golden_material.roughness = 0.2
	golden_material.emission_enabled = true
	golden_material.emission = Color(1.0, 0.8, 0.1, 1.0)
	golden_material.emission_energy_multiplier = 1.8


func _physics_process(delta):
	# Gestion du chronomètre et clignotement du Mode Frenzy
	if is_frenzy:
		frenzy_timer -= delta
		if frenzy_timer <= 1.5:
			frenzy_blink_timer += delta
			if frenzy_blink_timer >= 0.12:
				frenzy_blink_timer = 0.0
				is_frenzy_blink_visible = not is_frenzy_blink_visible
				var mesh_inst = get_node_or_null("Pivot/Character/Sphere_001")
				if mesh_inst:
					mesh_inst.set_surface_override_material(1, golden_material if is_frenzy_blink_visible else null)
		if frenzy_timer <= 0.0:
			stop_frenzy()

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
		air_stomp_streak = 0

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

			if is_frenzy:
				mob.squash()
				continue

			# Check that we are hitting it from above
			if Vector3.UP.dot(collision.get_normal()) > 0.1:
				mob.squash()
				target_velocity.y = bounce_impulse
				jump_count = 0 # Can jump again after stomping a mob!
				air_stomp_streak += 1
				if air_stomp_streak >= 3:
					start_frenzy(6.0)
					air_stomp_streak = 0
				break

	# Moving the Character
	velocity = target_velocity
	move_and_slide()

	# Empêcher le joueur de sortir du champ de vision de la caméra
	position.x = clampf(position.x, min_x, max_x)
	position.z = clampf(position.z, min_z, max_z)

	$Pivot.rotation.x = PI / 6 * velocity.y / jump_impulse

func die():
	stop_frenzy()
	hit.emit()
	queue_free()

func _on_mob_detector_body_entered(body):
	if body.is_in_group("mob"):
		if body.get("is_squashed") == true:
			return
		if is_frenzy:
			body.squash()
			return
	die()

func start_frenzy(duration: float = 6.0) -> void:
	is_frenzy = true
	frenzy_timer = duration
	frenzy_blink_timer = 0.0
	is_frenzy_blink_visible = true
	speed = frenzy_speed

	if has_node("FrenzyParticles"):
		$FrenzyParticles.emitting = true

	var mesh_inst = get_node_or_null("Pivot/Character/Sphere_001")
	if mesh_inst and golden_material:
		mesh_inst.set_surface_override_material(1, golden_material)

	MusicPlayer.pitch_scale = 1.25
	spawn_frenzy_banner()
	frenzy_started.emit()

func stop_frenzy() -> void:
	if not is_frenzy:
		return
	is_frenzy = false
	frenzy_timer = 0.0
	speed = base_speed

	if has_node("FrenzyParticles"):
		$FrenzyParticles.emitting = false

	var mesh_inst = get_node_or_null("Pivot/Character/Sphere_001")
	if mesh_inst:
		mesh_inst.set_surface_override_material(1, null)

	MusicPlayer.pitch_scale = 1.0
	frenzy_ended.emit()

func spawn_frenzy_banner() -> void:
	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.text = "⭐ FRENZY ! ⭐"
	label.font_size = 60
	label.outline_size = 14
	label.outline_modulate = Color(0.12, 0.06, 0.0, 0.95)
	label.modulate = Color(1.0, 0.88, 0.1, 1.0)
	label.position = global_position + Vector3(0, 2.2, 0)

	if get_parent():
		get_parent().add_child(label)
	else:
		add_child(label)

	var tween = create_tween()
	label.scale = Vector3(0.3, 0.3, 0.3)
	tween.tween_property(label, "scale", Vector3(1.35, 1.35, 1.35), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
	tween.parallel().tween_property(label, "position:y", label.position.y + 1.6, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.35)
	tween.tween_callback(label.queue_free)

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
