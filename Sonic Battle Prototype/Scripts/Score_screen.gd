extends Control

# winner ID
var winner
var done: bool = false

@export var win_text_node: RichTextLabel


func _process(_delta):
	if winner != null and done == false:
		done = true
		win_text_node.text = "Player " + str(winner) + " Won!"


## play again with the same settings
func _on_play_again_button_pressed():
	# restart current match
	Instantiables.go_to_stage(GlobalVariables.stage_selected) #restart_current_stage()
	queue_free()
	
	# this reloads the entire Main scene not only the selected stage
	# get_tree().reload_current_scene()



func _on_main_menu_button_pressed():
	#Instantiables.go_to_main_menu_from_battle()
	Instantiables.go_to_hub(GlobalVariables.hub_selected)
	get_tree().paused = false
	GlobalVariables.game_ended = false
	GlobalVariables.character_points = 0
	queue_free()