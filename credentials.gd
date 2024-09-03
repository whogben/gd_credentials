# Copyright (c) 2024 whogben
# SPDX-License-Identifier: MIT
# See LICENSE for details.
@icon("res://addons/gd_credentials/_gd_credentials_icon.png")
@tool
extends Node
class_name Credentials
## Utility for managing credentials like passwords and API keys.
## 
## A random salt is added to the password, which is then hashed
## password_hash_iterations times to derive a 256 bit encryption key.
## The credentials are encrypted with AESECB and saved at creds_path.[br][br]
## 
## Project Setup: [br][br]
## 
## 1. Set .creds_path to where your project stores credentials[br]
## 2. Set .password_hash_iterations based on your project's time budget[br][br]
## 
## Runtime Usage:[br][br]
## 
## 1. Call load_creds("some password") to load and decrypt all_creds.[br]
## 2. Use the .all_creds dictionary to access / modify creds. The format is up 
## to you.
## 3. Call save_creds("some password") to save encrypted at creds_path.[br][br]
##  
## Caveats:[br]
## - Creds are stored in memory in .all_creds[br]
## - Changing the password_hash_iterations will prevent you from loading creds 
## saved with a different value even if you have the right password.
## - Password is optional but if you do not use one then anyone who obtains the
## creds file can easily decrypt it.
## - Password storage is not built in. How do you store it securely? Beats me - 
## sounds like a you problem.
## - Consider the limitations of this system! No nuclear launch codes please!



## You can store and access your decrypted credentials in all_creds.
## using whatever dictionary format is most appropriate for your use case.
var all_creds:Dictionary

## Location where credentials will be stored
@export_global_file('.json') var creds_path = 'user://credentials.json'

## Number of times the password is hashed when deriving the encryption key.
## More is harder to brute force, set based on your available processor time
## (100_000 iterations takes 75ms on a 3.8ghz processor and Windows 11)
@export var password_hash_iterations = 100_000

## If true, credentials will be loaded when this node enters the tree.
## (not compatible with using a password).
@export var load_on_enter_tree:bool = true

## If true, credentials will be saved when this node exits the tree.
## (not compatible with using a password).
@export var save_on_exit_tree:bool = true


## Loads and decrypts all creds and returns true, or returns false on failure.
## (If no creds file exists sets all_creds = {} and returns true. Calling
## has_creds allows you to avoid this behavior if it is not desired.)
func load_creds(password:String = '') -> bool:
	if not has_creds():
		all_creds = {}
		return true
	var d:Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(creds_path))
	var key = _derive_key_from_password(password, d['salt'])
	var aes = AESContext.new()
	aes.start(AESContext.MODE_ECB_DECRYPT, key)
	var unencrypted_bytes = aes.update(Marshalls.base64_to_raw(d['creds']))
	aes.finish()
	var json = JSON.new()
	var err = json.parse(unencrypted_bytes.get_string_from_utf8().strip_edges())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	all_creds = json.data
	return true

## Encrypts and saves all_creds dict.
## If all_creds is empty creds_path is erased.
## If password is provided load_creds_on_enter_tree and save_creds_on_exit_tree
## will be disabled, as they are not compatible with passwords.
func save_creds(password:String = ''):
	if len(all_creds) == 0:
		erase_creds()
		return
	var d = {'salt': ''}
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(128): d['salt'] += chars[rng.randi() % chars.length()]
	var key = _derive_key_from_password(password, d['salt'])
	var unencrypted = JSON.stringify(all_creds)
	while len(unencrypted) % 16 != 0: unencrypted += ' '
	var aes = AESContext.new()
	aes.start(AESContext.MODE_ECB_ENCRYPT, key)
	var encrypted_bytes = aes.update(unencrypted.to_utf8_buffer())
	aes.finish()
	d['creds'] = Marshalls.raw_to_base64(encrypted_bytes)
	var file = FileAccess.open(creds_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(d))
	if password:
		load_on_enter_tree = false
		save_on_exit_tree = false

## Convenience method checks if the creds_path exists
func has_creds() -> bool:
	return FileAccess.file_exists(creds_path)

## Erases the creds file *but* does nothing to the all_creds property.
func erase_creds():
	if FileAccess.file_exists(creds_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(creds_path))



# var for allowing load/save w/ password from editor inspector
var _password:String = ''

# var for allowing load from editor inspector
var _load_creds_now:bool:
	set(value):
		if value:
			print('Loading credentials from ' + creds_path)
			if not load_creds(_password):
				push_warning('Unable to load credentials from ' + creds_path)

# var for allowing save from editor inspector
var _save_creds_now:bool:
	set(value):
		if value:
			print('Saving credentials to ' + creds_path)
			save_creds(_password)



func _get_property_list():
	var p = []
	if Engine.is_editor_hint():
		p.append({
			'name': 'Editor Controls',
			'type': TYPE_STRING,
			'usage': PROPERTY_USAGE_GROUP
		})
		p.append({
			'name': 'all_creds',
			'type': TYPE_DICTIONARY,
			'usage': PROPERTY_USAGE_EDITOR
		})
		p.append({
			'name': '_password',
			'type': TYPE_STRING,
			'usage': PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SECRET
		})
		p.append({
			'name': '_load_creds_now',
			'type': TYPE_BOOL,
			'usage': PROPERTY_USAGE_EDITOR
		})
		p.append({
			'name': '_save_creds_now',
			'type': TYPE_BOOL,
			'usage': PROPERTY_USAGE_EDITOR
		})
	return p

func _derive_key_from_password(
	password: String,
	salt: String
) -> PackedByteArray:
	var ctx = HashingContext.new()
	var key = (password + salt).to_utf8_buffer()
	for i in range(password_hash_iterations):
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(key)
		key = ctx.finish()
	return key

func _enter_tree():
	if load_on_enter_tree:
		if not load_creds():
			push_error('%s (%s) load_creds failed.' % [name, get_path()])

func _exit_tree():
	if save_on_exit_tree and len(all_creds):
		save_creds()
