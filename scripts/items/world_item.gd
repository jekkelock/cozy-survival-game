class_name WorldItem
extends Area3D

@export var item_data: ItemData
@export var quantity: int = 1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null


func _ready() -> void:
	if item_data != null and mesh_instance != null:
		mesh_instance.mesh = item_data.world_mesh

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if mesh_instance != null and item_data != null:
		mesh_instance.rotate_y(PI * 0.25 * delta)


func _on_body_entered(body: Node3D) -> void:
	if item_data == null:
		return

	var inventory: Node = body.get_node_or_null("InventoryComponent") as Node
	if inventory == null:
		inventory = body.find_child("InventoryComponent", true, false) as Node

	if inventory != null and inventory.has_method("add_item"):
		if inventory.call("add_item", item_data, quantity):
			queue_free()
