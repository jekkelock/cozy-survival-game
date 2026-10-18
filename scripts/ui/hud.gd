class_name HUD
extends CanvasLayer

@onready var warmth_bar: ProgressBar = $MarginContainer/VBoxContainer/WarmthRow/WarmthBar
@onready var hunger_bar: ProgressBar = $MarginContainer/VBoxContainer/HungerRow/HungerBar
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthRow/HealthBar


func _ready() -> void:
	print("HUD initialized")
	update_stats(100.0, 100.0, 100.0)

	var player: PlayerController = get_tree().get_first_node_in_group("player") as PlayerController
	if player == null:
		player = _find_player_in_tree(get_tree().root)

	if player != null:
		player.stats_changed.connect(_on_player_stats_changed)
		update_stats(player.warmth, player.hunger, player.health)


func update_stats(p_warmth: float, p_hunger: float, p_health: float) -> void:
	if warmth_bar != null:
		warmth_bar.value = p_warmth
	if hunger_bar != null:
		hunger_bar.value = p_hunger
	if health_bar != null:
		health_bar.value = p_health


func _on_player_stats_changed(p_warmth: float, p_hunger: float, p_health: float) -> void:
	update_stats(p_warmth, p_hunger, p_health)


func _find_player_in_tree(node: Node) -> PlayerController:
	if node is PlayerController:
		return node as PlayerController

	for child: Node in node.get_children():
		var found: PlayerController = _find_player_in_tree(child)
		if found != null:
			return found

	return null
