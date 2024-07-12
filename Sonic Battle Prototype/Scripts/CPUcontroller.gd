extends Label3D

# the character that have this node as input
var cpu_character
# the current target the bot is following
var target
# the player which is the main target to follow
var player_target

# store the bot states
# for future use
enum states {idle, pursue, attack, hit}
var current_state: states = states.idle

# the direction towards target
var target_direction: Vector3
# the distance to the target
var distance_to_target: float
# the minimum distance to stop chasing the player and start attacking
var min_attack_distance: float = 0.5
# the minimum offset towards a point in the stage to stop following such point
var min_offset: float = 0.5

# store if there are rings around the stage
var rings_around: Array
# store possible targets like a player or a ring
var possible_targets: Array

# timer between jumps
var jump_timer: SceneTreeTimer

# store the last height the player was
var new_height: float = -10
# store the last high points the player landed on to follow later
var points_path:Array[Marker3D]

## The container of the raycasts
## it will point towards the direction the bot is going
@export var raycasts_container: Marker3D
## the raycast used to detect if there is a wall in front of the bot to jump
@export var wall_detector: RayCast3D
## the raycast used to detect if there is a platform for the bot to land after jumping
@export var platform_detector: RayCast3D


func _physics_process(_delta):
	# select a target
	if target == null:
		target = GlobalVariables.current_character
	player_target = GlobalVariables.current_character
	rings_around = get_tree().get_nodes_in_group("Ring").duplicate()
	
	# store variables for possible targets
	possible_targets.clear()
	possible_targets = rings_around.duplicate()
	possible_targets.append(player_target)
	if points_path.size():
		possible_targets.append(points_path[0])
	
	# if a ring is closer than the player, set the ring as target
	if possible_targets.size() > 0:
		var new_target_distance
		for new_target in possible_targets:
			if is_instance_valid(new_target):
				new_target_distance = (new_target.position - position).length()
				if new_target_distance < distance_to_target:
					target = new_target
	
	# if this node has a parent
	if cpu_character:
		# make the lifetotal label face the camera
		if get_viewport().get_camera_3d() != null:
			look_at(-get_viewport().get_camera_3d().position)
		# update lifetotal label text
		text = str(cpu_character.life_total)
		
		# if there is a target and a player target
		if target and player_target:
			# go closer to target
			# store the distance and direction
			target_direction = (target.position - cpu_character.position).normalized()
			distance_to_target = (target.position - cpu_character.position).length()
			
			# maybe reduce the distance if chasing a ring
			if distance_to_target > min_attack_distance:
				# prevent loops by reseting the properties
				reset_properties()
				
				# path towards player
				
				# store planar variables
				# position with y axis at zero
				var planar_position = target.position
				planar_position.y = 0
				var planar_distance = (planar_position - cpu_character.position).length()
				
				# check if player target is right above the bot
				if planar_distance < min_attack_distance \
				and distance_to_target > min_attack_distance:
					if cpu_character.life_total < cpu_character.MAX_LIFE_TOTAL:
						# if the player is trying to keep distance, keep guard on
						# to heal
						cpu_character.guard_pressed = true
				else:
					cpu_character.guard_pressed = false
					
					# if there is a hole right in front of the bot jump
					if platform_detector.get_collision_point().y < cpu_character.position.y - min_offset:
						jump()
					
					move_towards_target()
				
				# if there is an obstacle, jump
				jump_check()
				
				# dash
				# cpu_character.dash_triggered = true
			
			# if close enough to attack, attack target
			else:
				# points_path.erase(points_path[0])
				if target.is_in_group("Player"):
					points_path.clear()
					cpu_character.guard_pressed = false
					attack_target()
			
			# guard/block/defend check
			if target.is_in_group("Player") and target.attacking and distance_to_target <= min_attack_distance:
				cpu_character.guard_pressed = true
			
	else:
		if cpu_character == null and get_parent() != null:
			cpu_character = get_parent()


func move_towards_target():
	# Set the input direction
	cpu_character.direction = (cpu_character.transform.basis * Vector3(target_direction.x, 0, target_direction.z)).normalized()


func jump_check():
	var direction = cpu_character.direction
	direction.y = 0
	raycasts_container.transform.basis.z = direction
	if wall_detector.is_colliding():
		if platform_detector.is_colliding() and (jump_timer == null or (jump_timer != null and jump_timer.time_left <= 0)):
			jump()


func jump():
	cpu_character.jump_pressed = true
	jump_timer = get_tree().create_timer(0.35, false, true)


func attack_target():
	if target.is_in_group("Player") and target.hurt:
		# special attack check
		cpu_character.special_pressed = true
	else:
		# attack check
		cpu_character.attack_pressed = true


func reset_properties():
	cpu_character.direction = Vector3.ZERO
	cpu_character.special_pressed = false
	cpu_character.attack_pressed = false
	#cpu_character.guard_pressed = false
	cpu_character.jump_pressed = false
	