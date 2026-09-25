@tool
extends EditorPlugin

## Animalese 插件编辑器入口脚本
## 负责在 Godot 编辑器中注册自定义节点与类型图标

func _enter_tree() -> void:
	# 自定义节点 AnimalesePlayer 将在实现后在此处通过 add_custom_type 注册
	pass

func _exit_tree() -> void:
	# 插件注销时清理自定义节点类型
	pass

