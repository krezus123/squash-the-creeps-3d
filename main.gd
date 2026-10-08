extends Node3D

@export var mob_scene: PackedScene

const SquashParticlesScene = preload("res://squash_particles.tscn")

var shake_strength: float = 0.0
var shake_decay: float = 14.0

func _ready():
	$UserInterface/Retry.hide()
	$CameraPivot.position = Vector3.ZERO
	$UserInterface/SettingsPanel.hide()
	
	# Initialiser le slider de son selon le volume actuel de MusicPlayer
	var current_linear = db_to_linear(MusicPlayer.volume_db)
	var vol_percent = int(round(current_linear * 100.0))
	$UserInterface/SettingsPanel/Panel/VBoxContainer/VolumeRow/VolumeSlider.value = vol_percent
	$UserInterface/SettingsPanel/Panel/VBoxContainer/VolumeRow/VolumeValue.text = "%d%%" % vol_percent
	update_sound_button_icon(vol_percent)

func _process(delta: float) -> void:
	# Caméra centrée sur l'arène avec zoom dynamique subtil lors des sauts
	if is_instance_valid($Player):
		var target_size = 19.0 + clampf($Player.position.y * 0.18, 0.0, 2.0)
		$CameraPivot/Camera3D.size = lerpf($CameraPivot/Camera3D.size, target_size, 4.0 * delta)

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

func spawn_floating_score(points: int, pos: Vector3) -> void:
	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 54 if points > 1 else 42
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.1, 0.1, 0.9)
	
	if points > 1:
		label.text = "+%d !" % points
		label.modulate = Color(1.0, 0.28, 0.18, 1.0) # Rouge vif pour les sprinters
	else:
		label.text = "+%d" % points
		label.modulate = Color(1.0, 0.88, 0.2, 1.0) # Jaune doré pour les mobs normaux
		
	label.position = pos + Vector3(0, 1.2, 0)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.8, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.65).set_delay(0.2)
	tween.tween_callback(label.queue_free)

func _on_mob_squashed(points: int, death_position: Vector3) -> void:
	$UserInterface/ScoreLabel._on_mob_squashed(points)
	trigger_screen_shake(0.4 if points > 1 else 0.3)
	spawn_squash_particles(death_position)
	spawn_floating_score(points, death_position)

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

# --- GESTION DU MENU DU VOLUME SONORE ---
func toggle_settings() -> void:
	var panel = $UserInterface/SettingsPanel
	panel.visible = not panel.visible
	get_tree().paused = panel.visible

func _on_settings_button_pressed() -> void:
	toggle_settings()

func _on_close_button_pressed() -> void:
	toggle_settings()

func _on_volume_slider_value_changed(value: float) -> void:
	var vol_percent = int(value)
	$UserInterface/SettingsPanel/Panel/VBoxContainer/VolumeRow/VolumeValue.text = "%d%%" % vol_percent
	
	var linear_vol = value / 100.0
	if linear_vol <= 0.01:
		MusicPlayer.volume_db = -80.0
	else:
		MusicPlayer.volume_db = linear_to_db(linear_vol)
	update_sound_button_icon(vol_percent)

func update_sound_button_icon(percent: int) -> void:
	if percent <= 0:
		$UserInterface/SettingsButton.text = "🔇 Son"
	elif percent < 50:
		$UserInterface/SettingsButton.text = "🔉 Son"
	else:
		$UserInterface/SettingsButton.text = "🔊 Son"

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept") and $UserInterface/Retry.visible:
		get_tree().reload_current_scene()
	elif event.is_action_pressed("ui_cancel"):
		toggle_settings()
