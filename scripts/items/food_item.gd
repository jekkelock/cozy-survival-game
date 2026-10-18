class_name FoodItem
extends Area3D

@export var hunger_restore_amount: float = 25.0
@export var item_name: String = "Wild Berries"
@export var rotation_speed: float = 2.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("consume_food"):
		body.call("consume_food", hunger_restore_amount)
		queue_free()
