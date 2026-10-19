class_name InventoryComponent
extends Node

signal inventory_updated
signal item_picked_up(item: ItemData, amount: int)
signal item_dropped(item: ItemData, amount: int)

@export var max_slots: int = 16

var _slots: Array[Dictionary] = []


func _init() -> void:
	_slots.resize(max_slots)


func _enter_tree() -> void:
	if _slots.size() != max_slots:
		_slots.resize(max_slots)


func add_item(item: ItemData, amount: int = 1) -> bool:
	if item == null or amount <= 0:
		return false

	var remaining: int = amount

	for i: int in _slots.size():
		if _slots[i].is_empty():
			continue

		var slot_item: ItemData = _slots[i]["item"] as ItemData
		if slot_item != null and slot_item.id == item.id and not item.is_consumable:
			var slot_qty: int = _slots[i]["quantity"] as int
			var space_left: int = item.max_stack_size - slot_qty
			var to_add: int = mini(remaining, space_left)
			_slots[i]["quantity"] = slot_qty + to_add
			remaining -= to_add
			if remaining <= 0:
				inventory_updated.emit()
				item_picked_up.emit(item, amount)
				return true

	if remaining > 0:
		for i: int in _slots.size():
			if _slots[i].is_empty():
				var qty_to_place: int = mini(remaining, item.max_stack_size)
				_slots[i] = { "item": item, "quantity": qty_to_place }
				remaining -= qty_to_place
				if remaining <= 0:
					break

	if remaining <= 0:
		inventory_updated.emit()
		item_picked_up.emit(item, amount)
		return true

	return false


func remove_item(slot_index: int, amount: int = 1) -> bool:
	if slot_index < 0 or slot_index >= _slots.size():
		return false

	var slot: Dictionary = _slots[slot_index]
	if slot.is_empty() or slot["quantity"] as int <= 0:
		return false

	var slot_qty: int = slot["quantity"] as int
	var to_remove: int = mini(amount, slot_qty)
	slot["quantity"] = slot_qty - to_remove

	if slot["quantity"] as int <= 0:
		_slots[slot_index] = {}

	inventory_updated.emit()
	return true


func drop_item(slot_index: int, drop_position: Vector3, amount: int = 1) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return

	var slot: Dictionary = _slots[slot_index]
	if slot.is_empty():
		return

	var item: ItemData = slot["item"] as ItemData
	var slot_qty: int = slot["quantity"] as int
	var to_drop: int = mini(amount, slot_qty)

	if to_drop <= 0:
		return

	slot["quantity"] = slot_qty - to_drop

	if slot["quantity"] as int <= 0:
		_slots[slot_index] = {}

	inventory_updated.emit()
	item_dropped.emit(item, to_drop)

	var world_item_scene: PackedScene = preload("res://scenes/items/WorldItem.tscn")
	var world_item: Node3D = world_item_scene.instantiate() as Node3D
	world_item.set("item_data", item)
	world_item.set("quantity", to_drop)
	world_item.global_transform = Transform3D(Basis(), drop_position)
	get_tree().current_scene.add_child(world_item)


func get_item(slot_index: int) -> ItemData:
	if slot_index < 0 or slot_index >= _slots.size():
		return null
	if _slots[slot_index].is_empty():
		return null
	return _slots[slot_index]["item"] as ItemData


func get_quantity(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= _slots.size():
		return 0
	if _slots[slot_index].is_empty():
		return 0
	return _slots[slot_index]["quantity"] as int


func get_slot_count() -> int:
	return _slots.size()


func get_occupied_slot_count() -> int:
	var count: int = 0
	for slot: Dictionary in _slots:
		if not slot.is_empty():
			count += 1
	return count
