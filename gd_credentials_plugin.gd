# Copyright (c) 2024 whogben
# SPDX-License-Identifier: MIT
# See LICENSE for details.
@tool
extends EditorPlugin



var _manage = preload("res://addons/gd_credentials/manage_credentials.tscn")



func _enter_tree():
	add_custom_type(
		"Credentials", 
		"Node", 
		load("res://addons/gd_credentials/credentials.gd"),
		load("res://addons/gd_credentials/_gd_credentials_icon.png"))
	add_tool_menu_item("Manage Credentials", _on_manage_credentials_selected)
	add_autoload_singleton("Creds","res://addons/gd_credentials/credentials.gd")

func _exit_tree():
	remove_custom_type('Credentials')
	remove_tool_menu_item("Manage Credentials")
	remove_autoload_singleton("Creds")

func _on_manage_credentials_selected():
	var manager = load("res://addons/gd_credentials/manage_credentials.tscn")
	manager = manager.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	manager.credentials = Creds
	var w = Window.new()
	w.add_child(manager)
	w.close_requested.connect(get_tree().root.remove_child.bind(w))
	w.close_requested.connect(manager.credentials.save_creds)
	w.close_requested.connect(w.queue_free)
	w.popup_exclusive_centered_clamped(get_tree().root,Vector2(500,500))
