extends Node3D

@export var mob_scene: PackedScene

const SquashParticlesScene = preload("res://squash_particles.tscn")

var shake_strength: float = 0.0
var shake_decay: float = 14.0

func _ready():
	$UserInterface/Retry.hide()

func _process(delta: float) -> void:
	# Suivi fluide du joueur par la caméra (sur le plan X/Z)
	if is_instance_valid($Player):
		var target_pos = Vector3($Player.position.x, 0.0, $Player.position.z)
		$CameraPivot.position = $CameraPivot.position.lerp(target_pos, 5.0 * delta)

	# Tremblement de caméra (Screen Shake)
	if shake_strength > 0.0:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
		$CameraPivot/Camera3D.h_offset = randf_range(-shake_strength, shake_strength)
		$CameraPivot/Camera3D.v_offset = randf_range(-shake_strength, shake_strength)
	else:
		$CameraPivot/Camera3D.h_offset = 0.0
		$CameraPivot/Camera3D.v_offset = 0.0

func trigger_screen_shake(amount: float = 0.35) -> void:
	shake_strength = amount

func spawn_squash_particles(pos: Vector3) -> void:
	var particles = SquashParticlesScene.instantiate()
	particles.position = pos + Vector3(0, 0.5, 0)
	add_child(particles)

func _on_mob_squashed(points: int, death_position: Vector3) -> void:
	$UserInterface/ScoreLabel._on_mob_squashed(points)
	trigger_screen_shake(0.35)
	spawn_squash_particles(death_position)

func _on_mob_timer_timeout():
	var mob = mob_scene.instantiate()

	var mob_spawn_location = get_node("SpawnPath/SpawnLocation")
	mob_spawn_location.progress_ratio = randf()

	var player_position = $Player.position
	mob.initialize(mob_spawn_location.position, player_position)

	add_child(mob)
	
	mob.squashed.connect(_on_mob_squashed)

func _on_player_hit() -> void:
	$MobTimer.stop()
	trigger_screen_shake(0.7)
	$UserInterface/Retry.show()
	
func _unhandled_input(event):
	if event.is_action_pressed("ui_accept") and $UserInterface/Retry.visible:
		get_tree().reload_current_scene()
