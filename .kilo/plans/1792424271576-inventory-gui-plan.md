# Plan: Inventory GUI (toggle with `I`)

## Goal
Add an inventory overlay toggled by a new `inventory` input action (key `I`), wired to the existing `InventoryComponent` so a grid of slots refreshes on `inventory_updated`. No existing GUI exists yet.

## Context (key facts, from codebase scan)
- `InventoryComponent` (`scripts/components/inventory_component.gd`): `max_slots=16`, `_slots: Array[Dictionary]` of `{ "item": ItemData, "quantity": int }`. Signals: `inventory_updated`, `item_picked_up(item, amount)`, `item_dropped(item, amount)`. Read accessors: `get_item(i)`, `get_quantity(i)`, `get_slot_count()`.
- `PlayerController` (`scripts/player/player_controller.gd`): `@onready var inventory: InventoryComponent = $InventoryComponent`; mouse look is in `_unhandled_input`, gated on `Input.MOUSE_MODE_CAPTURED`. `_ready()` adds self to group `"player"` and captures the mouse.
- `ItemData` (`scripts/resources/item_data.gd`): `id, name, icon:Texture2D, world_mesh, max_stack_size, is_consumable`. Note: `wild_berries.tres` has `icon = null`.
- InputMap has 7 actions (`move_*`, `jump`, `sprint`, `drop_item`); no inventory/interact action.
- HUD pattern (`scripts/ui/hud.gd`) uses `CanvasLayer` root + `"player"` group lookup; no slot rendering exists.

## Decisions
1. **Binding = `I`** (physical_keycode 73). Tab is a viable alternative — flagged in notes, not used.
2. **Scene root = `CanvasLayer`** (not a bare `PanelContainer`) so it reliably overlays the 3D world and HUD. Set `CanvasLayer.layer = 1` (HUD is default layer 0) so the inventory renders above the vitals HUD.
3. `inventory_ui` is typed `CanvasLayer` (the request's illustrative `Control` type is overridden because the scene root is `CanvasLayer` — this is the correct type and keeps `_input` overlay behavior sound).
4. **Toggle lives in `_input`** as requested. When opening: show + `refresh()` + `Input.mouse_mode = MOUSE_MODE_VISIBLE`; when closing: hide + `Input.MOUSE_MODE_CAPTURED`. This naturally suppresses the existing mouse-look guard (which only runs while captured).
5. **Signal handler `_on_inventory_updated` lives on the panel** (`inventory_panel.gd`) and calls `refresh()`. It is connected from `player_controller._ready` via `inventory.inventory_updated.connect(inventory_ui._on_inventory_updated)` — matches the request's connect snippet.
6. **Slot = small sub-scene `InventorySlot.tscn`** (root `Button`) with a `TextureRect` (icon) + `Label` (count). Null icons are handled (icon hidden, count still shown).

## Tasks

### 1. `project.godot` — add the `inventory` action
Append to the `[input]` section (same Object literal style as the existing bindings; `physical_keycode 73` = `I`):
```ini
inventory={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":73,"key_label":0,"unicode":105,"location":0,"echo":false,"script":null)
]
}
```
> Editor preference: `Project → Project Settings → Input Map → Add "inventory" → add `Key I`. The INI above is the manual equivalent.

### 2. New file: `scenes/ui/InventorySlot.tscn` + `scripts/ui/inventory_slot.gd`
Scene:
```
InventorySlot (Button)                          # class_name InventorySlot
├── TextureRect  name="ItemIcon" (expand=true, stretch_mode=Scale, visible=false)
└── Label        name="CountLabel" (anchor bottom-right, visible=false)
```
- Set the `Button`'s `custom_minimum_size = (64, 64)` so the grid tiles uniformly.
- Give the `Button` a flat `StyleBoxFlat` (border, transparent fill) so empty slots still render a frame.

Script (`scripts/ui/inventory_slot.gd`):
```gdscript
class_name InventorySlot
extends Button

@onready var icon: TextureRect = $ItemIcon
@onready var count_label: Label = $CountLabel

var slot_index: int = -1

func update_display(item: ItemData, quantity: int) -> void:
	if item == null or quantity <= 0:
		icon.texture = null
		icon.visible = false
		count_label.visible = false
		return
	icon.texture = item.icon as Texture2D
	icon.visible = item.icon != null
	count_label.text = str(quantity)
	count_label.visible = quantity > 1
```

### 3. New file: `scenes/ui/InventoryPanel.tscn` + `scripts/ui/inventory_panel.gd`
Scene:
```
InventoryPanel (CanvasLayer, layer=1)            # class_name InventoryPanel
└── PanelContainer (Layout preset = Center; min 600×220)
    └── GridContainer (columns=4; h_separation=8; v_separation=8)
```
> `PanelContainer` provides a dark background and content-sized box; `GridContainer` holds the 16 slot buttons. `layer=1` forces it above the HUD.

Script (`scripts/ui/inventory_panel.gd`):
```gdscript
class_name InventoryPanel
extends CanvasLayer

signal slot_clicked(slot_index: int)

const SLOT_SCENE: PackedScene = preload("res://scenes/ui/InventorySlot.tscn")

@export var inventory: InventoryComponent

@onready var grid: GridContainer = $PanelContainer/GridContainer

var _slots: Array[InventorySlot] = []

func _ready() -> void:
	if inventory != null:
		_build_slots()
		refresh()

func _build_slots() -> void:
	for child: Node in grid.get_children():
		child.queue_free()
	_slots.clear()
	if inventory == null:
		return
	var count: int = inventory.get_slot_count()
	for i: int in count:
		var slot: InventorySlot = SLOT_SCENE.instantiate() as InventorySlot
		slot.slot_index = i
		slot.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(slot)
		_slots.append(slot)

func refresh() -> void:
	if inventory == null:
		return
	for i: int in _slots.size():
		var item: ItemData = inventory.get_item(i)
		var qty: int = inventory.get_quantity(i)
		_slots[i].update_display(item, qty)

func _on_inventory_updated() -> void:
	refresh()

func _on_slot_pressed(index: int) -> void:
	slot_clicked.emit(index)
```

### 4. Edit `scripts/player/player_controller.gd`
Add the `inventory_ui` onready variable near the other `@onready` field:
```gdscript
@onready var inventory_ui: CanvasLayer = preload("res://scenes/ui/InventoryPanel.tscn").instantiate()
```
Extend `_ready()` to mount + wire the UI:
```gdscript
func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stats_changed.emit(warmth, hunger, health)

	inventory_ui.inventory = inventory
	add_child(inventory_ui)
	inventory.inventory_updated.connect(inventory_ui._on_inventory_updated)
	inventory_ui.hide()
```
Add the requested `_input` toggle (coexists with the existing `_unhandled_input` mouse look):
```gdscript
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		var toggled_on: bool = not inventory_ui.visible
		inventory_ui.visible = toggled_on
		if toggled_on:
			inventory_ui.refresh()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
```

## Risks / Verification items
- **`_slots` initialization** (verify before running): `InventoryComponent._slots.resize(max_slots)` is declared as `Array[Dictionary]`. In Godot 4.7 typed arrays this fills with empty `{}` (so `.is_empty()` is safe). Confirm the engine build fills with `{}` rather than `null` — if `null`, the UI's `get_item`/`get_quantity` (which call `.is_empty()`) will throw. If null, the fix on the component is: `_slots.resize(max_slots); for i in max_slots: _slots[i] = {}`. ← verify; do not change the component unless this fails.
- **`wild_berries.tres.icon` is null** → slot hides the icon but still renders the count. For polish, assign a placeholder `Texture2D` to that asset (optional, out of scope).
- **Draw order** → inventory `CanvasLayer.layer = 1` must sit above the HUD (default layer 0). Verify visually.
- **`_input` vs `_unhandled_input`** → no conflict; mouse-look is suppressed because it is gated on `MOUSE_MODE_CAPTURED`.
- **Input passthrough while open** → while the inventory is open, movement/jump/`drop_item` (Q) still fire. Acceptable for MVP. Optional enhancement (not in this plan): ignore gameplay actions when `inventory_ui.visible`.

## Validation
1. Run `scenes/world/Main.tscn`.
2. Press `I` → panel appears (4×4 grid of 16 empty frames), mouse released, camera stops.
3. Pick up a `WorldItem` (drop one with `Q` from slot 0, then walk over the spawned item) → slot icon/count updates on `inventory_updated`.
4. Press `Q` to drop slot 0 → quantity decreases / slot clears on refresh.
5. Press `I` again → panel hides, mouse re-captured.

## Out of scope
- Item use-on-click (slot `pressed` only emits `slot_clicked(index)` for future wiring).
- Drag/drop between slots, split stacks, equipment.
- Controller/gamepad bindings for `inventory`.
