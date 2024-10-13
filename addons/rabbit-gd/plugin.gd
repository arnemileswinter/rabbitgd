@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("RMQClient", "RefCounted", load("res://addons/rabbit-gd/RMQClient.gd"), null)
	add_custom_type("RMQChannel", "RefCounted", load("res://addons/rabbit-gd/RMQChannel.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("RMQClient")
	remove_custom_type("RMQChannel")
