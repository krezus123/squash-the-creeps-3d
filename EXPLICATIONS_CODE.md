# Guide Complet des Modifications & Explications du Code
## Projet Godot 4 — *Squash the Creeps 3D (Version Améliorée)*

Ce document détaille l'intégralité des fonctionnalités ajoutées au jeu, comment elles ont été conçues, pourquoi ces choix techniques ont été faits, ainsi qu'une comparaison approfondie entre l'animation par code (**Tweens**) et l'animation par l'éditeur Godot (**AnimationPlayer**).

---

## Sommaire
1. [Animations : Éditeur (AnimationPlayer) vs Code (Tweens)](#1-animations--éditeur-animationplayer-vs-code-tweens)
2. [Le Double Saut & le Game Juice (Squash & Stretch, Chapeau Cône, BOING !)](#2-le-double-saut--le-game-juice)
3. [Le Mode "Frenzy" (Étoile Invincible & Multiplicateur)](#3-le-mode-frenzy-étoile-invincible)
4. [Variantes d'Ennemis (Monstres Bleus vs Sprinters Rouges)](#4-variantes-dennemis-monstres-bleus-vs-sprinters-rouges)
5. [Améliorations Caméra : Cadrage Stable & Screen Shake](#5-améliorations-caméra--cadrage-stable--screen-shake)
6. [Systèmes de Particules (CPUParticles3D)](#6-systèmes-de-particules-cpuparticles3d)
7. [Scores Flottants 3D (Combat Text)](#7-scores-flottants-3d-combat-text)
8. [Menu des Options Audio en Jeu](#8-menu-des-options-audio-en-jeu)
9. [Direction Artistique & Confinement de l'Arène](#9-direction-artistique--confinement-de-larène)

---

## 1. Animations : Éditeur (AnimationPlayer) vs Code (Tweens)

> **Question clé pour votre soutenance / présentation :**
> *« Les animations sont faisables dans l'éditeur visuel de Godot... pourquoi certaines ont-elles été faites par code (Tweens) plutôt que dans l'éditeur à la main ? »*

Dans le développement de jeux vidéo professionnel et sous Godot, **ces deux approches se complètent et ne s'excluent pas**. Chacune a un rôle très précis :

| Critère | `AnimationPlayer` (Éditeur visuel) | `Tween` (Par code GDScript) |
| :--- | :--- | :--- |
| **Principe** | Courbes et clés d'animation créées à la souris dans la timeline. | Interpolations mathématiques créées à la volée par code. |
| **Idéal pour** | Animations cycliques, prédéfinies et complexes (ex: marche d'un personnage, battement d'ailes, respiration). | Animations **réactives**, dynamiques et liées à un événement imprévisible (impact, rebond, punch scale, fondu UI). |
| **Positionnement** | Souvent absolu par rapport au repère local du modèle 3D. | Dynamique et relatif : peut démarrer depuis **n'importe quelle valeur actuelle** sans coupure. |
| **Maintenance** | Modification via l'interface graphique (GUI). | Modification instantanée en ajustant 2 chiffres dans le script. |
| **Poids / Ressources**| Ressource de scène (`AnimationLibrary`, fichiers `.tres`). | Léger, instancié en mémoire uniquement le temps de l'effet puis détruit. |

### Pourquoi avoir utilisé du code (`Tween`) pour nos ajouts ?

1. **La réactivité au Gameplay (*Game Juice*) :**
   Lorsqu'un monstre est écrasé, son animation de mort ou le score `+1` qui s'envole ne démarre pas à une position fixe : elle démarre exactement là où le joueur a frappé (`death_position`). Avec un `Tween`, on écrit :
   ```gdscript
   var tween = create_tween()
   tween.tween_property(label, "position:y", label.position.y + 1.8, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
   ```
   C'est fluide, adaptatif, et ça ne nécessite pas de créer une scène animée distincte pour chaque chiffre.

2. **Le respect des animations en cours sans conflit :**
   Le joueur possède déjà une animation cyclique dans l'`AnimationPlayer` (`"float"` qui le fait flotter). Si nous avions animé le double saut ou le chapeau cône dans l'`AnimationPlayer`, cela aurait écrasé ou conflicté avec la boucle de flottement. Le `Tween` s'exécute en surcouche (sur la propriété `scale` du `$Pivot` ou `position:y` du cône), sans interrompre l'`AnimationPlayer`.

3. **Transitions mathématiques cartoon instantanées :**
   Les Tweens permettent d'appliquer en une ligne des courbes physiques telles que `TRANS_BACK` (effet d'anticipation ou dépassement cartoon) ou `TRANS_BOUNCE` (rebond physique amorti).

---

## 2. Le Double Saut & le Game Juice

### A. Mécanique du Double Saut (`player.gd`)

```gdscript
# Maximum jumps allowed before touching ground (2 for Double Jump).
@export var max_jumps = 2
var jump_count = 0

# Dans _physics_process :
if not is_on_floor():
    target_velocity.y = target_velocity.y - (fall_acceleration * delta)
else:
    jump_count = 0 # Réinitialise dès que le joueur touche le sol

if Input.is_action_just_pressed("jump"):
    if is_on_floor():
        target_velocity.y = jump_impulse
        jump_count = 1
    elif jump_count < max_jumps:
        target_velocity.y = jump_impulse * 0.95 # Légèrement plus doux
        jump_count += 1
```

**Explication du code :**
- `jump_count` garde en mémoire le nombre de sauts effectués depuis qu'on a quitté le sol.
- Au sol (`is_on_floor()`), il retombe à `0`.
- Le second saut applique 95 % de l'impulsion du premier, ce qui donne un contrôle aérien précis sans surpuissance.
- **Bonus gameplay :** Lorsqu'on écrase un monstre (`mob.squash()`), on remet `jump_count = 0`, permettant d'enchaîner indéfiniment des sauts de monstre en monstre !

### B. Le Squash & Stretch du Joueur

```gdscript
# Squash & stretch feedback on double jump
var tween = create_tween()
tween.tween_property($Pivot, "scale", Vector3(0.85, 1.25, 0.85), 0.08)
tween.tween_property($Pivot, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
```

**Explication du code :**
- En 0.08s, le modèle s'écrase en largeur (X et Z passent à 0.85) et s'étire en hauteur (Y passe à 1.25). C'est le principe fondamental d'animation cartoon de conservation du volume (*Squash & Stretch* de Disney).
- En 0.10s, il reprend sa forme initiale `(1, 1, 1)`.

### C. Le Chapeau Cône de Chantier & son Rebond

Le cône a été modélisé procéduralement dans `player.tscn` à partir de 3 primitives 3D :
- Une base carrée (`BoxMesh`) orange.
- Un corps conique (`CylinderMesh` avec `top_radius = 0.04` et `bottom_radius = 0.2`) orange.
- Une bande réfléchissante blanche (`CylinderMesh`).

Au moment du double saut :
```gdscript
func animate_hat_bounce() -> void:
    var hat = get_node_or_null("Pivot/Character/ConeHat")
    if hat:
        var hat_tween = create_tween()
        hat_tween.tween_property(hat, "position:y", 0.95, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        hat_tween.tween_property(hat, "position:y", 0.65, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
```
- Le cône monte à `0.95m` (décollant de la tête sous l'inertie).
- Puis il retombe à sa position de repos `0.65m` avec `TRANS_BOUNCE`, créant un rebond comique très expressif.

### D. Le Texte Flottant "BOING !"

```gdscript
func spawn_boing_text() -> void:
    var label = Label3D.new()
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED # Fait face à la caméra
    label.no_depth_test = true                         # Jamais masqué par la 3D
    label.text = "BOING !"
    label.font_size = 52
    label.outline_size = 12
    label.outline_modulate = Color(0.1, 0.1, 0.1, 0.9) # Contour net
    label.modulate = Color(1.0, 0.86, 0.15, 1.0)       # Jaune vif cartoon
    label.position = global_position + Vector3(0, 1.6, 0)
    add_child(label)

    var tween = create_tween()
    label.scale = Vector3(0.5, 0.5, 0.5)
    tween.tween_property(label, "scale", Vector3(1.25, 1.25, 1.25), 0.08)
    tween.tween_property(label, "scale", Vector3(1.0, 1.0, 1.0), 0.06)
    tween.parallel().tween_property(label, "position:y", label.position.y + 1.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.2)
    tween.tween_callback(label.queue_free)
```
- `label.billboard = BILLBOARD_ENABLED` garantit que le texte reste lisible sous n'importe quel angle de vue.
- `tween.parallel()` permet d'exécuter l'ascension verticale et le fondu de transparence (`modulate:a`) simultanément.
- `tween_callback(label.queue_free)` supprime le nœud dès que l'animation se termine pour éviter toute fuite de mémoire.

---

## 3. Le Mode "Frenzy" (Étoile Invincible)

Inspiré du mode Super Star de Mario, le mode Frenzy transforme le joueur en force irrésistible pendant 6 secondes.

### A. Déclenchement (`main.gd` & `player.gd`)
1. **Tous les 10 points :**
   ```gdscript
   if $UserInterface/ScoreLabel.score >= next_frenzy_threshold:
       next_frenzy_threshold += 10
       if is_instance_valid($Player):
           $Player.start_frenzy(6.0)
   ```
2. **Combo de 3 rebonds consécutifs sans toucher le sol :**
   Dans le script joueur, chaque écrasement réussi en l'air incrémente `air_stomp_streak`. À 3, le mode se déclenche immédiatement !

### B. Transformation Visuelle & Sonore (`player.gd`)
```gdscript
func start_frenzy(duration: float = 6.0) -> void:
    is_frenzy = true
    frenzy_timer = duration
    speed = frenzy_speed # 23 m/s au lieu de 14

    $FrenzyParticles.emitting = true

    # Remplacement du matériau du corps par de l'or brillant
    var mesh_inst = get_node_or_null("Pivot/Character/Sphere_001")
    if mesh_inst and golden_material:
        mesh_inst.set_surface_override_material(1, golden_material)

    MusicPlayer.pitch_scale = 1.25 # Musique accélérée
    spawn_frenzy_banner()
    frenzy_started.emit()
```

**Pourquoi l'index 1 pour `set_surface_override_material` ?**
Le maillage 3D du joueur (`player.glb`) comporte 3 sous-surfaces :
- Surface 0 : pupille
- Surface 1 : corps (*body*)
- Surface 2 : blanc des yeux
En modifiant uniquement la surface 1, le corps devient un or lumineux (`metallic = 0.8`, `emission = Color(1.0, 0.8, 0.1)`), tout en gardant les yeux expressifs du personnage !

### C. Invulnérabilité Totale (Bulldozer)
Habituellement, heurter un monstre de face entraîne la mort du joueur (`_on_mob_detector_body_entered`). En mode Frenzy :
```gdscript
func _on_mob_detector_body_entered(body):
    if body.is_in_group("mob"):
        if body.get("is_squashed") == true:
            return
        if is_frenzy:
            body.squash() # Écrase l'ennemi au contact !
            return
    die()
```
Même chose dans la boucle de collisions physiques de `_physics_process` : si `is_frenzy` est actif, tout contact physique détruit l'ennemi.

### D. Avertissement de Fin (Clignotement)
Dans les 1.5 dernières secondes, le joueur clignote pour être prévenu que son invincibilité va s'arrêter :
```gdscript
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
```

---

## 4. Variantes d'Ennemis (Monstres Bleus vs Sprinters Rouges)

Dans [`mob.gd`](file:///C:/Users/gdewisme/Downloads/3d_squash_the_creeps_starter/mob.gd), un tirage aléatoire différencie les monstres à l'apparition :

```gdscript
func initialize(start_position, player_position):
    var sphere_mesh = $Pivot/Character.get_node_or_null("Sphere")

    if randf() < 0.30: # 30 % de chance
        mob_type = MobType.SPRINTER
        score_value = 2
        min_speed = 20.0
        max_speed = 25.0
        $Pivot.scale = Vector3(0.85, 0.85, 0.85) # Silhouette plus petite
        
        var sprinter_mat = StandardMaterial3D.new()
        sprinter_mat.albedo_color = Color(0.96, 0.22, 0.12) # Rouge-orangé vif
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
```

### La Correction Cruciale des Vitesses & Animations
- **Plages sans chevauchement :** 9.0–12.0 m/s (Normal) vs 20.0–25.0 m/s (Sprinter). Un monstre bleu ne peut plus jamais aller plus vite qu'un rouge.
- **Vitesse de battement d'ailes normalisée :**
  ```gdscript
  $AnimationPlayer.speed_scale = random_speed / 10.0
  ```
  En divisant la vitesse par une constante (10.0) au lieu de `min_speed`, un monstre à 24 m/s bat des ailes à `2.4x`, alors qu'un monstre normal à 10 m/s bat à `1.0x`. Le ressenti visuel concorde parfaitement avec la vitesse de déplacement physique.

---

## 5. Améliorations Caméra : Cadrage Stable & Screen Shake

Dans [`main.gd`](file:///C:/Users/gdewisme/Downloads/3d_squash_the_creeps_starter/main.gd) :

### A. Fixation du Centre & Zoom Dynamique
Initialement, la caméra suivait le joueur sur le plan X/Z, ce qui créait une illusion désagréable : quand le joueur courait, le sol semblait bouger et les ennemis donnaient l'impression de glisser.
- **Solution appliquée :** `CameraPivot.position = Vector3.ZERO` (fixe au centre).
- **Zoom vertical doux :**
  ```gdscript
  var target_size = 19.0 + clampf($Player.position.y * 0.18, 0.0, 2.0)
  $CameraPivot/Camera3D.size = lerpf($CameraPivot/Camera3D.size, target_size, 4.0 * delta)
  ```
  Quand le joueur saute haut, la caméra orthogonale élargit légèrement son champ de vision (`size`) avec une interpolation douce (`lerpf`).

### B. Le Screen Shake Décroissant
```gdscript
func trigger_screen_shake(amount: float = 0.35) -> void:
    shake_strength = amount

func _process(delta: float) -> void:
    if shake_strength > 0.0:
        shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
        $CameraPivot/Camera3D.h_offset = randf_range(-shake_strength, shake_strength)
        $CameraPivot/Camera3D.v_offset = randf_range(-shake_strength, shake_strength)
    else:
        $CameraPivot/Camera3D.h_offset = 0.0
        $CameraPivot/Camera3D.v_offset = 0.0
```
- Lors d'un écrasement de monstre, un tremblement de `0.35` à `0.45` est appliqué.
- À la mort du joueur, une secousse violente de `0.7` retentit.
- `move_toward` amortit linéairement la force vers 0 à chaque trame, réinitialisant les décalages `h_offset` et `v_offset`.

---

## 6. Systèmes de Particules (CPUParticles3D)

Trois émetteurs de particules légers apportent de la vie au monde :

1. **La traînée de poussière (`DustTrail` dans `player.tscn`) :**
   - Émet des petites sphères blanches semi-transparentes sous les pieds.
   - Activée uniquement par code quand le joueur court au sol :
     ```gdscript
     $DustTrail.emitting = is_on_floor() and direction != Vector3.ZERO
     ```
2. **L'impact d'écrasement (`SquashParticles` dans `squash_particles.tscn`) :**
   - 18 étincelles dorées explosives projetées vers le haut (`one_shot = true`, `explosiveness = 1.0`).
   - S'auto-détruit après sa durée de vie grâce à son script dédié.
3. **L'aura Frenzy (`FrenzyParticles` dans `player.tscn`) :**
   - Émission continue de particules sphériques dorées scintillantes (`Color(1, 0.9, 0.15)`) tout autour du joueur quand le mode invincible est actif.

---

## 7. Scores Flottants 3D (Combat Text)

Instancié directement au point d'impact dans `main.gd` :
- `+1` en jaune doré pour un monstre standard.
- `+2 !` en rouge vif avec une taille de police plus grande pour un sprinter.
- `x2 ! +4` en or scintillant lorsque le multiplicateur Frenzy est actif.

Le composant est un `Label3D` avec fondu et élévation gérés par `Tween`.

---

## 8. Menu des Options Audio en Jeu

### Fonctionnalités
- Bouton accessible `🔊 Son` en haut à droite et raccourci touche **Échap** (`ui_cancel`).
- Ouverture d'un panneau avec fond sombre semi-transparent.
- Met le jeu en pause (`get_tree().paused = true`), tout en permettant à l'interface de continuer à fonctionner (`process_mode = PROCESS_MODE_ALWAYS`).
- Curseur de volume (`HSlider`) avec affichage en pourcentage direct (`100%`, `50%`, etc.).
- Gestion de l'icône dynamique : `🔊 Son` (>50%), `🔉 Son` (<50%), `🔇 Son` (0%).

### Conversion Logarithmique (Linéaire vers Décibels)
Le curseur va de 0 à 100 %, mais l'oreille humaine perçoit le volume de manière logarithmique :
```gdscript
func _on_volume_slider_value_changed(value: float) -> void:
    var linear_vol = value / 100.0
    if linear_vol <= 0.01:
        MusicPlayer.volume_db = -80.0 # Silence absolu
    else:
        MusicPlayer.volume_db = linear_to_db(linear_vol) # Conversion mathématique précise
```
Cette méthode évite le piège classique où baisser le volume de moitié rendrait le jeu inaudible.

---

## 9. Direction Artistique & Confinement de l'Arène

1. **Palette Cartoon / Pop (Fall Guys / Nintendo) :**
   - Sol intérieur vert court de gazon propre (`Color(0.24, 0.72, 0.38)`).
   - Ligne blanche d'arène sportive (`CourtBorder`).
   - Sol extérieur bleu ciel rafraîchissant (`Color(0.25, 0.7, 0.88)`).
   - Piliers d'angle jaunes chaleureux avec émission lumineuse.
2. **Confinement du Joueur (`clampf`) :**
   Pour éviter que le joueur ne sorte de la vue de la caméra fixe :
   ```gdscript
   position.x = clampf(position.x, min_x, max_x) # [-12.5, 12.5]
   position.z = clampf(position.z, min_z, max_z) # [-13.0, 13.0]
   ```
   Le joueur glisse naturellement le long des bordures sans risquer de se perdre hors champ.
