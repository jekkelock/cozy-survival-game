class_name WarmthSourceComponent
extends Area3D

signal state_changed(is_active: bool)
signal fuel_changed(fuel_level: float)

@export var warmth_restore_rate: float = 15.0
@export var health_restore_rate: float = 0.0
@export var is_active: bool = true:
	set(value):
		if is_active != value:
			is_active = value
			state_changed.emit(is_active)
			_update_light_visibility()

@export var fuel_level: float = 100.0:
	set(value):
		fuel_level = clampf(value, 0.0, 100.0)
		fuel_changed.emit(fuel_level)

@export var consumes_fuel: bool = false
@export var fuel_consumption_rate: float = 5.0

@onready var omni_light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null

var _players_in_area: Array[PlayerController] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_light_visibility()


func _process(delta: float) -> void:
	if not is_active:
		return

	if consumes_fuel and fuel_level <= 0.0:
		is_active = false
		return

	if consumes_fuel:
		fuel_level = clampf(fuel_level - fuel_consumption_rate * delta, 0.0, 100.0)
		if fuel_level <= 0.0:
			is_active = false
			return

	var warmth_delta: float = warmth_restore_rate * delta
	var health_delta: float = health_restore_rate * delta

	for player: PlayerController in _players_in_area:
		if player.is_inside_tree() and player.has_method("heal_and_warm"):
			player.heal_and_warm(warmth_delta, health_delta)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player: PlayerController = body as PlayerController
		if not _players_in_area.has(player):
			_players_in_area.append(player)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		var player: PlayerController = body as PlayerController
		_players_in_area.erase(player)


func _update_light_visibility() -> void:
	if omni_light != null:
		omni_light.visible = is_active
