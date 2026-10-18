class_name PlayerController
extends CharacterBody3D

signal health_changed(new_value: float)
signal hunger_changed(new_value: float)
signal warmth_changed(new_value: float)
signal stats_changed(warmth: float, hunger: float, health: float)

@export_group("Movement Settings")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 4.5
@export var acceleration: float = 10.0
@export var mouse_sensitivity: float = 0.003

@export_group("Camera Settings")
@export var camera_pivot: Node3D
@export var spring_arm: SpringArm3D
@export var min_pitch: float = -80.0
@export var max_pitch: float = 60.0

@export_group("Vitals")
@export_range(0.0, 100.0, 0.1) var health: float = 100.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 100.0)
		if not is_equal_approx(health, clamped):
			health = clamped
			health_changed.emit(health)

@export_range(0.0, 100.0, 0.1) var hunger: float = 100.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 100.0)
		if not is_equal_approx(hunger, clamped):
			hunger = clamped
			hunger_changed.emit(hunger)

@export_range(0.0, 100.0, 0.1) var warmth: float = 100.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 100.0)
		if not is_equal_approx(warmth, clamped):
			warmth = clamped
			warmth_changed.emit(warmth)

@export_group("Vitals Decay Rates (/sec)")
@export var hunger_decay_rate: float = 0.5
@export var warmth_decay_rate: float = 0.8
@export var starvation_damage_rate: float = 2.0
@export var freezing_damage_rate: float = 3.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stats_changed.emit(warmth, hunger, health)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mouse_motion.relative.x * mouse_sensitivity)

		var pitch_node: Node3D = spring_arm if spring_arm != null else camera_pivot
		if pitch_node != null:
			pitch_node.rotate_x(-mouse_motion.relative.y * mouse_sensitivity)
			var min_pitch_rad: float = deg_to_rad(min_pitch)
			var max_pitch_rad: float = deg_to_rad(max_pitch)
			pitch_node.rotation.x = clampf(pitch_node.rotation.x, min_pitch_rad, max_pitch_rad)


func _process(delta: float) -> void:
	_update_survival_stats(delta)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)


func _update_survival_stats(delta: float) -> void:
	var prev_warmth: float = warmth
	var prev_hunger: float = hunger
	var prev_health: float = health

	hunger -= hunger_decay_rate * delta
	warmth -= warmth_decay_rate * delta

	var damage: float = 0.0
	if hunger <= 0.0:
		damage += starvation_damage_rate * delta
	if warmth <= 0.0:
		damage += freezing_damage_rate * delta

	if damage > 0.0:
		health -= damage

	if not is_equal_approx(prev_warmth, warmth) or not is_equal_approx(prev_hunger, hunger) or not is_equal_approx(prev_health, health):
		stats_changed.emit(warmth, hunger, health)


func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var target_speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity_h: Vector3 = move_dir * target_speed

	var current_velocity_h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	current_velocity_h = current_velocity_h.lerp(target_velocity_h, acceleration * delta)

	velocity.x = current_velocity_h.x
	velocity.z = current_velocity_h.z

	move_and_slide()
