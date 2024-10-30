# GD Credentials
### A Godot addon for storing credentials like passwords and API keys.

The new Credentials node can be added to any scene and used to store and retrieve sensitive information.

The .all_creds dictionary stores your credentials in whatever format you please. 

The .creds_path property specifies where credentials will be stored, and defaults to `user://credentials.creds`. Stored credentials are encrypted with AES ECB, but to make the file secure, you must supply a password to save_creds() and load_creds(). The password is not stored in the file so you must remember it or store it securely.

By default, an autoload singleton named "Creds" will be added to the project and enabled. The credentials stored by this autoload singleton can be modified in the editor from Project -> Tools -> Manage Credentials.

# How to Use

Using the Creds singleton to get an API key
```gdscript
var key = Creds.all_creds.get('MyAPIKey')
```

Using your own creds node
```gdscript
# Get your creds node
var creds_node = $Credentials

# Load the creds with your password
creds_node.load_creds("your_password")

# Work with credentials via the all_creds dictionary
creds_node.all_creds["MyAPIKey"] = "k87478716"

# Save the creds with a password when you're done
creds_node.save_creds("your_password_or_a_new_password")
```

# Other Notes
- The autoload singleton Creds does not use a password, meaning an attacker who gets the creds file will be able to decrypt it. It is primarily included for developer use in the Editor, and you should use a password to secure the file in your game.
- Secure password storage sounds like a YOU problem, definitely don't store it near the credentials file. It is your responsibilty to judge security risks and implement appropriate measures. This software is provided AS IS with no warranty.
