@tool
extends EditorPlugin

## Animalese EditorPlugin entry script.
## Registers custom node types and editor integrations.

const PLUGIN_ICON = preload("res://addons/animalese/icon.svg")
const PLAYER_SCRIPT = preload("res://addons/animalese/scripts/nodes/animalese_player.gd")


func _enter_tree() -> void:
	add_custom_type("AnimalesePlayer", "Node", PLAYER_SCRIPT, PLUGIN_ICON)


func _exit_tree() -> void:
	remove_custom_type("AnimalesePlayer")
