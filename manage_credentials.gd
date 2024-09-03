# Copyright (c) 2024 whogben
# SPDX-License-Identifier: MIT
# See LICENSE for details.
@tool
extends Control
## Provides a control for managing credentials on a Credentials node.



## Credentials to edit
@export var credentials:Credentials

## Tree of credentials
@export var t:Tree

@export var l:Label

var dtree:DictTree



func _init():
	pass

func _ready():
	if not credentials: return
	var abspath = ProjectSettings.globalize_path(credentials.creds_path)
	
	if credentials.creds_path != abspath:
		l.text = ("Editing credentials at %s (%s)" % [credentials.creds_path,
			abspath])
	else:
		l.text = "Editing credentials at %s" % credentials.creds_path
	
	dtree = DictTree.new(t, credentials.all_creds)
	dtree.name = "Credentials"
	dtree.button_icon = preload("res://addons/gd_credentials/_gd_credentials_icon.png")



## Helper class for displaying an editable dictionary in a Tree
## The dictionary can only have strings as keys
## The dictionary can only have strings or other dictionaries as values
class DictTree extends RefCounted:
	
	
	
	## Name displayed on the root node (if any)
	var name:String = "":
		set(value):
			name = value
			call_deferred("refresh")
	
	## Column in which key is displayed
	var col_key = 0:
		set(value):
			col_key = value
			call_deferred("refresh")
	
	## Column in which value is displayed
	var col_value = 1:
		set(value):
			col_value = value
			call_deferred("refresh")
	
	## Icon for a button that shows a popup with add/delete options
	var button_icon:Texture:
		set(value):
			button_icon = value
			call_deferred("refresh")
	
	## Tree in which dict will be represented
	var tree:Tree:
		set(value):
			if tree == value: return
			var oldtree = tree
			tree = value
			if oldtree:
				oldtree.item_edited.disconnect(_on_t_item_edited)
				oldtree.button_clicked.disconnect(_on_t_button_clicked)
			if tree:
				tree.item_edited.connect(_on_t_item_edited)
				tree.button_clicked.connect(_on_t_button_clicked)
			call_deferred("refresh")
	
	## Dictionary to represent in the tree
	var dict:Dictionary:
		set(value):
			dict = value
			call_deferred("refresh")
	
	
	## Updates the tree with the current dictionary state
	func refresh():
		tree.columns = max(tree.columns, col_key+1, col_value+1)
		tree.clear()
		var root = tree.create_item()
		root.set_text(col_key, name)
		root.add_button(col_value, button_icon)
		
		var to_create:Array = [[root, dict, []]]
		while len(to_create) > 0:
			var _parent = to_create[0][0]
			var _dict = to_create[0][1]
			var _keypath = to_create.pop_front()[2]
			for key in _dict:
				var keypath = _keypath.duplicate()
				keypath.append(key)
				var _item = tree.create_item(_parent)
				_item.set_meta('key', key)
				_item.set_meta('keypath', keypath)
				_item.set_text(col_key, key)
				if typeof(_dict[key]) != TYPE_DICTIONARY:
					_item.set_text(col_value, str(_dict[key]))
					_item.set_editable(col_value, _is_editable(keypath)[1])
				else:
					to_create.append([_item, _dict[key], keypath])
				_item.add_button(
					col_value,
					preload(
						"res://addons/gd_credentials/_gd_credentials_icon.png"))
				_item.set_editable(col_key, _is_editable(keypath)[0])
			
		
	
	func get_keypath_for_item(item:TreeItem) -> Array:
		return item.get_meta('keypath', [])
	
	## Override in subclasses to return [key_editable, value_editable]
	func _is_editable(keypath:Array) -> Array[bool]:
		return [true, true]
	
	## Override in subclasses to return [[key_types], [value_types]]
	func _get_valid_types(keypath:Array) -> Array[Array]:
		return [[TYPE_STRING],[TYPE_STRING, TYPE_DICTIONARY]]
	
	
	
	enum _P {
		Add_Key,
		Delete_Item
	}
	
	
	
	func _init(_tree:Tree = null, _dict:Dictionary = {}):
		tree = _tree
		dict = _dict
		call_deferred("refresh")
	
	func _on_t_item_edited():
		var item = tree.get_edited()
		var key = item.get_meta('key')
		var keypath = get_keypath_for_item(item)
		var text = tree.get_edited().get_text(tree.get_edited_column())
		var d = _get_keypath_parent_dict(keypath)
		match tree.get_edited_column():
			col_value:
				d[key] = text
			col_key:
				if text in d:
					return
				d[text] = d[key]
				d.erase(key)
				item.set_meta('key',text)
	
	func _on_t_button_clicked(
		item: TreeItem,
		column: int,
		id: int,
		mouse_button_index: int
	):
		if column != col_value or mouse_button_index != 1:
			return
		var keypath = get_keypath_for_item(item)
		
		var p = PopupMenu.new()
		
		if _is_keypath_dict(keypath):
			var k = PopupMenu.new()
			k.add_separator('Key Type')
			for ktype in _get_valid_types(keypath)[0]:
				var v = PopupMenu.new()
				v.add_separator('Value Type')
				v.id_pressed.connect(
					_on_additem_index_pressed.bind(keypath, ktype))
				for vtype in _get_valid_types(keypath)[1]:
					v.add_item(type_string(vtype))
				k.add_submenu_node_item(type_string(ktype), v)
			p.add_submenu_node_item(
				"Add Item" if item == tree.get_root() else "Add Subitem",
				 k,
				_P.Add_Key)
		
		p.id_pressed.connect(_on_p_id_pressed.bind(item))
		p.set_meta('keypath', keypath)
		if item != tree.get_root():
			p.add_item('Delete Item', _P.Delete_Item)
		
		var ppos = tree.global_position + tree.get_item_area_rect(
			item, column, 0).position + tree.get_item_area_rect(
			item, column, 0).size * .5
		p.popup_exclusive_on_parent(tree, Rect2(ppos, Vector2(0,0)))
	
	func _on_p_id_pressed(id:int, item:TreeItem):
		var keypath = get_keypath_for_item(item)
		if id == _P.Delete_Item:
			_get_keypath_parent_dict(keypath).erase(keypath[-1])
		refresh()
	
	func _on_additem_index_pressed(index:int, keypath:Array, ktype):
		var vtype = _get_valid_types(keypath)[1][index-1]
		var d = _get_keypath_value(keypath)
		var i = 0
		var key = type_convert(i, ktype)
		while key in d:
			i += 1
			key = type_convert(i, ktype)
		d[key] = type_convert(null, vtype)
		refresh()
	
	func _get_keypath_parent_dict(keypath:Array) -> Dictionary:
		var d = dict
		for i in range(len(keypath)-1):
			d = d[keypath[i]]
		return d
	
	func _get_keypath_value(keypath:Array):
		if len(keypath) == 0:
			return dict
		return _get_keypath_parent_dict(keypath)[keypath[-1]]
	
	func _is_keypath_dict(keypath:Array) -> bool:
		return typeof(_get_keypath_value(keypath)) == TYPE_DICTIONARY
