# Godot 4.7 GDScript Coding Standards

## Core Syntax Rules
1. **Strict Type Annotations:** Always use explicit typing (`var speed: float = 5.0`, `func _ready() -> void:`).
2. **Godot 4 Syntax Only:** 
   - Use `await` instead of `yield()`.
   - Use `move_and_slide()` without parameters (velocity is set as a node property).
   - Use `@export` annotations instead of `export`.
   - Use `@onready` for node references.
3. **Architecture Rules:**
   - Favor node composition and custom `Resource` scripts over tight coupling.
   - Use signals for decoupled component communication (`signal health_changed(new_value)`).
   - Keep physics calculations strictly inside `_physics_process(delta)`.

## Project Directory Structure
- `res://scenes/` for `.tscn` scene files.
- `res://scripts/` for `.gd` code files.
- `res://assets/` for textures, models, and audio.
