extends Control

# script for the options menu
# inputmap

var is_listening = false

# the action that is being changed
# "left", &"right", &"up", &"down"
# &"guard", &"punch", &"pause", &"jump"
# &"special", &"change_cam_position", &"upper"
var current_action = ""

# to change the text in the buttons after remapping
@export var up_button: Button
@export var left_button: Button
@export var down_button: Button
@export var right_button: Button
@export var punch_button: Button
@export var special_button: Button
@export var jump_button: Button
@export var guard_button: Button

var current_button = null

var buttons: Array

var actions_list = ["up", "left", "down", "right", "punch", "special", "jump", "guard"]
var default_inputs = {"up": null, "left": null, "down": null, "right": null, "punch": null, "special": null, "jump": null, "guard": null}
var current_inputs = {}


func _ready():
	# add the button nodes to the list
	buttons = [up_button, left_button, down_button, right_button, punch_button, special_button, jump_button, guard_button]
	# store the default inputs from global variables
	current_inputs = GlobalVariables.DEFAULT_INPUTS.duplicate()
	# load the default inputs
	load_input_values()


func _on_restore_default_button_pressed():
	#print(InputMap.get_actions())
	InputMap.load_from_project_settings()
	set_default_values()
	#print("after")
	#print(InputMap.get_actions())


func _on_up_button_pressed():
	if current_action == "":
		current_action = "up"
		current_button = up_button
		# grey out the button
		current_button.disabled = true


func _on_left_button_pressed():
	if current_action == "":
		current_action = "left"
		current_button = left_button
		# grey out the button
		current_button.disabled = true


func _on_down_button_pressed():
	if current_action == "":
		current_action = "down"
		current_button = down_button
		# grey out the button
		current_button.disabled = true


func _on_right_button_pressed():
	if current_action == "":
		current_action = "right"
		current_button = right_button
		# grey out the button
		current_button.disabled = true


func _on_punch_button_pressed():
	if current_action == "":
		current_action = "punch"
		current_button = punch_button
		# grey out the button
		current_button.disabled = true


func _on_special_button_pressed():
	if current_action == "":
		current_action = "special"
		current_button = special_button
		# grey out the button
		current_button.disabled = true


func _on_jump_button_pressed():
	if current_action == "":
		current_action = "jump"
		current_button = jump_button
		# grey out the button
		current_button.disabled = true


func _on_guard_button_pressed():
	if current_action == "":
		current_action = "guard"
		current_button = guard_button
		# grey out the button
		current_button.disabled = true


# load the values in the project settings and store
func load_input_values():
	for i in range(buttons.size()):
		# get first input from the inputs for that move
		var input = actions_list[i] #InputMap.action_get_events(actions_list[i])[0]
		# get a human readable string form
		var key = current_inputs[input] #OS.get_keycode_string(input.physical_keycode)
		#print(key)
		# set the key to the respective action
		default_inputs[actions_list[i]] = key
		# write the text in the respective button
		buttons[i].text = key
		
		# need to load the inputs from a save file
		
		# make the buttons actually work accordingly to the give inputs
		#InputMap.action_erase_events(input)
		#var new_event_key = event.new()
		#new_event_key = OS.set_keycode_string()
		#InputMap.action_add_event(input, key)
	#print(default_inputs)
		
	current_action = ""
	current_button = null


# write the text on the buttons accordingly to the inputs
func set_default_values():
	#var default_inputs = {"up": null, "left": null, "down": null, "right": null, "punch": null, "special": null, "jump": null, "guard": null}
	
	for i in range(buttons.size()):
		var input = InputMap.action_get_events(default_inputs[i][0])[0]
		
		InputMap.action_erase_events(default_inputs[i][0])
		InputMap.action_add_event(default_inputs[i][0], input)
		
		buttons[i].text = str(input)
		
	current_action = ""
	current_button = null


func _input(event):
	if current_action != "" and not event is InputEventMouseMotion:
		# erase previous input registered for that move
		InputMap.action_erase_events(current_action)
		# make the button pressed the new input for that move
		InputMap.action_add_event(current_action, event)
		# reset the current action
		current_action = ""
		# change the input text in the button
		if event is InputEventKey:
			print(OS.get_keycode_string(event.keycode))
			current_button.text = OS.get_keycode_string(event.keycode)
		elif event is InputEventMouseButton:
			print(event.button_index)
			if event.button_index == 1:
				current_button.text = "LMB"
			if event.button_index == 2:
				current_button.text = "RMB"
			if event.button_index == 3:
				current_button.text = "MMB"
			if event.button_index == 4:
				current_button.text = "MMB UP"
			if event.button_index == 5:
				current_button.text = "MMB DOWN"
		
		# check joystick
		print(event)
		
		# enable it
		current_button.disabled = false
		# reset current button
		current_button = null


func _on_shake_camera_check_box_pressed():
	if GlobalVariables.can_shake_camera:
		GlobalVariables.can_shake_camera = false
	else:
		GlobalVariables.can_shake_camera = true