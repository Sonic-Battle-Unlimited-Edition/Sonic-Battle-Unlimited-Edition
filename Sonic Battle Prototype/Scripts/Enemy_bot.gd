extends CharacterBody3D

# This is the script for the bots.
# the bots "inputs" comes from the "cpu_controller" node
# Original code by The8BitLeaf. code modified later on

# Basic movement speed values for Sonic.
const SPEED = 4.0
const JUMP_VELOCITY = 6.0

# Dash speed is the speed value for the dash move executed by double tapping a direction on the ground
# Sonic's midair jump ability is an air dash, and the speed is determined by airdash speed.
const DASH_SPEED = 15.0
const AIRDASH_SPEED = 10.0

# amount of time allowed between presses to consider it as a double tap
const DOUBLETAP_DELAY: float = 0.2

# max distance from ground to allow jump through coyote time
const MAX_COYOTE_GROUND_DISTANCE: float = 0.1

# default life total value
const MAX_LIFE_TOTAL = 100

# default max special amount
const MAX_SPECIAL_AMOUNT = 100

# max number of rings to be created when scattering rings
const MAX_SCATTERED_RINGS_ALLOWED: int = 8

# heal points per ring collected
const HEAL_POINTS_PER_RING: int = 2

# Boolean to check if Sonic is facing left or right
var facing_left = false

# input direction
var direction = Vector3.ZERO

# Booleans for checking when Sonic is jumping or falling, used to make sure
# that Sonic plays the correct animations.
var jumping = false
var falling = false
var jump_clicked: bool = false

# Starting determines the state where Sonic is accelerating, usually only impacts ground moves.
# When starting, Sonic can execute a dash or strong attack on the ground.
# Walking is just to differentiate his moving state.
var walking = false
var starting = false

# Boolean for when Sonic is in the middle of a dash animation.
var dashing = false

# Boolean that makes sure Sonic can only airdash once in the air. Resets when on the ground.
var can_airdash = true

# Boolean to determine when to lock Sonic's moveset during an attack.
var attacking = false

# Like can_airdash, but instead determines if a midair attack can be executed.
var can_air_attack = true

# The current punching state for the 3-hit combo.
var current_punch = 0

# This vector determines the strength and direction the hitbox object sends opponents.
# Each move changes the launch power when necessary and the animation handles the hitbox position.
var launch_power : Vector3

# this variable determines the amount of damage that the character will cause
# each move changes the damage caused accordingly
var damage_caused: int

# States for when Sonic is hurt, locking his actions.
var hurt = false
var launched = false
var spiked = false

# Skills! These strings determine what Sonic's grounded and midair special type are.
# Immunity determines which category of special move Sonic is immune to.
var ground_skill
var air_skill
var immunity

# Sonic's midair "pow" special move bounces off the ground, so this state makes sure he does that.
var bouncing = false

# active_ring is the object recently created by Sonic's grounded "pow" move, for checking constant positioning.
# thrown_ring indicates when a ring is on the field, to avoid calling a null active_ring
var active_ring: CharacterBody3D
var thrown_ring = false

# The state in which Sonic is moving in the direction of active_ring.
var chasing_ring = false

# The mine object currently on the field, to ensure only one mine can be used at a time.
var active_mine

# Since Sonic's "pow" move is a melee attack and uses his regular hitboxes,
# this boolean ensures that immunities still apply.
var pow_move = false

# coyote time variables
# timer for coyote time
var coyote_timer: SceneTreeTimer
# distance from ground when on air
var coyote_ground_distance: float = 0.0

# store the keycode of the last button pressed for double tap check
#var last_keycode: int = 0

# store the time left for double tap check
var doubletap_timer = DOUBLETAP_DELAY
# to allow dash only after a double tap
var dash_triggered = false

# values presented on hud
var life_total: int = MAX_LIFE_TOTAL
var special_amount: int = 0
var points: int = 0

# value that will increase when pressing healing to trigger the heal method
var healing_time: float = 0.0
# the rate the healing_time will increase
var healing_pace: float = 0.1
# the amount of heling_time to trigger a heal call
var healing_threshold: float = 3.0
# where the heal effect scene that will be instantiated will be stored
var heal_effect: Node3D
# boolean to check when Sonic is healing
var healing : bool

# boolean to check when the player is chasing after a successful wall jump
var chasing_aggressor : bool
# boolean to check when the player can do the AIM attack
var can_spike : bool
# boolean to check when the player can chase after a strong hit
var can_chase : bool
var punch_timer: SceneTreeTimer

# store the input state transmited by a input node or CPU node
# this allows to separate the inputs from the character script
# which helps creating CPU characters
#var punch_pressed: bool = false
var special_pressed: bool = false
var jump_pressed: bool = false
var attack_pressed: bool = false
var upper_pressed: bool = false
var guard_pressed: bool = false

# rings collected in a stage
# start with an amount to test
var rings: int = MAX_SCATTERED_RINGS_ALLOWED

## the character model which turns accordingly to the input direction
# this is used by the cpu_controller script to have the reference of the Bot's forward
@export var model_node: Node3D

## navigation agent for navmesh
@export var nav: NavigationAgent3D

# was causing errors without this line
# might have been some residual import settings
var camera = null

# the last player who caused damage to this character
var last_aggressor

# to reposition if falling off a pit but still not defeated
var last_spawn_position: Vector3 = Vector3.ZERO

var after_image_time: float = 0.0

# defeated method should trigger only once
var was_defeated: bool = false

#for checking valid location to spawn
var range: int
var respawning: bool = false 


func _enter_tree():
	set_multiplayer_authority(0) #str(name).to_int())
	#set_multiplayer_authority(GlobalVariables.character_id)
	
	var bots_list = get_tree().get_nodes_in_group("Bot")
	name = "BOT " + str(bots_list.size())


func _ready():
	if GlobalVariables.play_online == false:
		points = GlobalVariables.bot_points

	if GlobalVariables.current_stage == null:
		ground_skill = "POW"
		air_skill = "POW"
	
	last_spawn_position = position


# Setting a drop shadow is weird in _physics_process(), so the drop shadow code is in _process().
func _process(delta):
	# If the drop shadow ray detects ground, it sets the visual shadow at the collision point.
	if $DropShadowRange.is_colliding():
		$DropShadow.visible = true
		var ground_height = $DropShadowRange.get_collision_point().y
		$DropShadow.global_position.y = ground_height
		
		# coyote time to help responsiveness jump
		if !is_on_floor():
			coyote_ground_distance = position.y - ground_height
	else:
		$DropShadow.visible = false
		
	# coyote time between gaps
	if coyote_timer == null:
		create_coyote_timer()
	
	# call coyote light feet here so it can work with coyote edge by creating it's timer
	coyote_light_feet()
	
	# to check the time between key presses
	# could create an actual timer instead
	if doubletap_timer > 0:
		doubletap_timer -= delta
	
	# control how often an after image will appear
	if after_image_time > 0:
		after_image_time -= delta
	if !$DropShadowRange.is_colliding() and respawning == true:
		range -= 0.1
		respawn(range)
	else:
		respawning = false
		range = 2.5


func _physics_process(delta):
	if !is_on_floor():
		# add the gravity.
		# The speed at which Sonic falls
		velocity.y -= GlobalVariables.gravity * delta
		# Since starting and walking only do things on the ground, they are set to inactive here.
		starting = false
		walking = false
	else:
		if spiked:
			$sonicrigged2/AnimationPlayer.play("KO")
			spiked = false
		# remove current coyote timer form the variable
		coyote_timer = null
		# Being on the ground means you aren't jumping or falling
		jumping = false
		falling = false
		jump_clicked = false
		# Because Sonic's dash is a sort of jump, this is how the move resets itself.
		# For characters that slide along the ground (i.e. Shadow), this may change.
		dashing = false
		# Midair moves can only be used after a jump once, and they can be used again after touching the ground.
		can_airdash = true
		can_air_attack = true
		chasing_aggressor = false
		can_spike = false
		# If Sonic is in his midair "pow" bouncing state, his velocity sends him upwards off the ground.
		if bouncing:
			velocity.y = 5
			can_airdash = false
			can_air_attack = false	# As funny as it would be to have the SA2 bounce spam, it would be too OP here.
		
		if chasing_ring:
			attacking = false
			chasing_ring = false
			starting = false
			pow_move = false
		
	
	
	if is_on_wall() && $sonicrigged2/AnimationPlayer.current_animation == "LAUNCHED":
		velocity.y = 0
		$sonicrigged2/AnimationPlayer.play("WALL")
	
	if !attacking && !hurt && !chasing_aggressor && !can_spike:
		if !healing:
			handle_jump()

			handle_dash()
			
			handle_movement_input()
			
			handle_sprite_orientation()
			
			handle_attack()
			
			# TODO: make the CPU bot do updraft attacks sometimes
			handle_upper()
			
			rotate_model()
		else:
			# if Sonic is in his healing state, he slows to a halt.
			velocity.x = lerp(velocity.x, 0.0, 0.1)
			velocity.z = lerp(velocity.z, 0.0, 0.1)
		handle_healing()
		
	else:
		if !chasing_ring && !bouncing && !chasing_aggressor:
			# if Sonic is in his attacking or hurt state, he slows to a halt.
			velocity.x = lerp(velocity.x, 0.0, 0.1)
			velocity.z = lerp(velocity.z, 0.0, 0.1)
		if $sonicrigged2/AnimationPlayer.current_animation == "WALL" || can_chase:
			handle_walljump()
	
	# defeated if going lower than the lower limit of the map or
	# life total is less than or equal to zero
	# or the character is not in a battle and don't have rings
	if position.y < -5.0:
		#cause damage
		life_total -= 10
		if life_total < 0:
			life_total = 0
		#reposition or respawn
		if life_total <= 0:
			defeated()
		else:
			respawning = true
			respawn(range)
		
	# If Sonic is currently chasing an aggressor after successfully executing a wall jump, he accelerates to above its position.
	if chasing_aggressor && last_aggressor != null:
		velocity.x = lerp(velocity.x, (last_aggressor.transform.origin - transform.origin).normalized().x * 20, 0.25)
		velocity.z = lerp(velocity.z, (last_aggressor.transform.origin - transform.origin).normalized().z * 20, 0.25)
		
		if velocity.y <= 0:
			chasing_aggressor = false
			can_spike = true
	
	if can_spike:
		handle_spike()

	handle_after_image()

	# Automatically handle the animation and character controller physics.
	handle_animation()
	move_and_slide()

func respawn(range):
	velocity = Vector3.ZERO
	if range <= 0.1:
		range = 0.1
	#spawn next to the player
	if GlobalVariables.current_character != null:
		position = GlobalVariables.current_character.position +  Vector3(randf_range(-range, range), 1.1, randf_range(-range, range))#last_spawn_position
	else:
		position = last_spawn_position


## handle the movement of the character given an input
func handle_movement_input():	
	# Code for handling basic movement
	if direction:
		# If Sonic is at a standstill before moving, he enters his starting state for dashes and strong attacks.
		if !starting && !walking && is_on_floor():
			starting = true
			$AnimationPlayer.play("startWalk")
			$sonicrigged2/AnimationPlayer.play("WALK START")
		velocity.x = lerp(velocity.x, direction.x * SPEED, 0.1)
		velocity.z = lerp(velocity.z, direction.z * SPEED, 0.1)
	else:
		walking = false
		velocity.x = lerp(velocity.x, 0.0, 0.1)
		velocity.z = lerp(velocity.z, 0.0, 0.1)


## Code for determining the direction the character is facing.
func handle_sprite_orientation():
	$Hitbox.rotation = $sonicrigged2.rotation


## method to check and perform the dash movement
func handle_dash():
	# This set of "if" statements handles the dash. Pressing your current velocity direction
	# while in the starting state causes Sonic to dash in that direction, recreating the "double-tap" input
	# This is probably a very workaround solution and there's probably a way to make it work better
	# But this is the best solution I could come up with.
	# added a dash_triggered to prevent dashing when simply pressing diagonals
	# (was suposed to substitute the double tap completely but the character was making a
	# jump animation instead of dash animation so added the dash_triggered variable instead)
	if dash_triggered:
		velocity = Vector3(velocity.normalized().x * DASH_SPEED, 4, velocity.normalized().z * DASH_SPEED)
		dashing = true
		coyote_timer = null
		$AnimationPlayer.play("dash")
		$sonicrigged2/AnimationPlayer.play("DASH")
		Audio.play(Audio.dash, self)
		
		var dust_effect = Instantiables.DUST_PARTICLE.instantiate()
		dust_effect.position = position
		get_parent().add_child(dust_effect)
		dust_effect.look_at(position - velocity.normalized())
		dust_effect.get_child(0).emitting = true
		dust_effect.get_child(1).emitting = true
	
	dash_triggered = false


## method to control the jump
func handle_jump():
	# If you're in the air, Sonic performs his midair action (as long as he hasn't used it yet.)
	if jump_pressed && (is_on_floor() || coyote_time()) && !dashing:
		Audio.play(Audio.jump, self)
		velocity.y = JUMP_VELOCITY
		jumping = true
		jump_clicked = true
		# remove current coyote timer form the variable
		coyote_timer = null
	elif jump_pressed && !is_on_floor() && can_airdash:
		Audio.play(Audio.airDash, self) #spin)
		dashing = true
		can_airdash = false
		# remove current coyote timer form the variable
		coyote_timer = null
		$AnimationPlayer.play("airdash")
		$sonicrigged2/AnimationPlayer.play("DJMP 1")
		# If Sonic is inputting a direction, he airdashes in that direction.
		# If no direction is held, he moves horizontally in the direction he's facing.
		if direction:
			velocity = Vector3(direction.x * AIRDASH_SPEED, 4, direction.z * AIRDASH_SPEED)
		else:
			var new_velocity = $sonicrigged2.transform.basis.z.normalized() * AIRDASH_SPEED
			new_velocity.y = 4
			velocity = new_velocity


func handle_walljump():
	if jump_pressed:
		hurt = false
		can_chase = false
		attacking = false
		velocity.y = 7
		chasing_aggressor = true

## help responsiveness feeling by forgiving the difference between the human response and the machine accuracy
func coyote_time() -> bool:
	if coyote_edge() and coyote_light_feet():
		push_warning("coyote light feet edge case")
	return coyote_edge() or coyote_light_feet()


## help responsiveness feeling by allowing to jump right after passing an edge
func coyote_edge() -> bool:
	var can_jump = false
	if coyote_timer != null and coyote_timer.time_left > 0 and jump_clicked == false:
		can_jump = true
	return can_jump


## help responsiveness feeling by allowing to jump right before touching the ground
func coyote_light_feet() -> bool:
	var can_jump = false
	if !is_on_floor() and coyote_ground_distance <= MAX_COYOTE_GROUND_DISTANCE and jump_clicked == false:
		can_jump = true
		# creating the timer here will allow the coyote light feet to work with coyote edge
		# so that the player to jump when passing very close to the edge of a platform
		create_coyote_timer()
	return can_jump


## create a timer for the coyote time
func create_coyote_timer():
	coyote_timer = get_tree().create_timer(0.2, false, true)


## create a timer for the punch combo
func create_punch_timer():
	punch_timer = get_tree().create_timer(0.5, false, true)


## method to handle when the updraft button is pressed
func handle_upper():
	if upper_pressed:
		if is_on_floor():
			$AnimationPlayer.play("upStrong")
			$sonicrigged2/AnimationPlayer.play("UPPER")
			Audio.play(Audio.attackStrong, self)
			launch_power = Vector3(0, 7, 0)
			damage_caused = 7
			attacking = true
			velocity = -$sonicrigged2.basis.z.normalized() * 2
		else:
			if can_air_attack:
				can_air_attack = false
				$AnimationPlayer.play("pac")
				$sonicrigged2/AnimationPlayer.play("PAC")
				Audio.play(Audio.attackStrong, self)
				launch_power = Vector3($sonicrigged2.basis.z.normalized().x * 5, 5, $sonicrigged2.basis.z.normalized().x * 5)
				velocity.y = 3
				damage_caused = 7
				attacking = true

## method to execute the AIM attack
func handle_spike():
	if attack_pressed:
		can_spike = false
		$AnimationPlayer.play("aim")
		$sonicrigged2/AnimationPlayer.play("AIM")
		Audio.play(Audio.attackStrong, self)
		launch_power = Vector3(0, -5, 0)
		damage_caused = 7
		attacking = true

## method to determine what happens when punch attack is pressed, grounded or not
## ALL the basic attacks are handled in this chain of if statements.
func handle_attack():
	if attack_pressed && starting:
		# The code for Sonic's strong attacks. If he's holding the opposite direction,
		# he executes an up strong attack which slightly bumps him backwards.
		
		# If sonic holds any other direction, he executes a normal strong attack
		# that sends the opponent in the direction he specifies.
		$AnimationPlayer.play("strong")
		$sonicrigged2/AnimationPlayer.play("PGC 4")
		Audio.play(Audio.attackStrong, self)
		var new_launch = $sonicrigged2.transform.basis.z.normalized() * 20
		new_launch.y = 5
		launch_power = new_launch
		damage_caused = 7
		attacking = true
	elif attack_pressed && dashing && can_airdash:
		# The code for Sonic's dash attack. His dash attack stalls him in the air for a short time.
		can_airdash = false
		attacking = true
		$AnimationPlayer.play("dashAttack")
		$sonicrigged2/AnimationPlayer.play("DASH ATK")
		Audio.play(Audio.attack2, self)
		launch_power = Vector3(velocity.x, 2, velocity.z)
		damage_caused = 7
		velocity.y = 3
	elif attack_pressed && !dashing && !is_on_floor() && can_air_attack:
		# The code for Sonic's midair attack. He can only use this once before landing, and it
		# sends the opponent downwards.
		attacking = true
		can_air_attack = false
		$AnimationPlayer.play("airAttack")
		$sonicrigged2/AnimationPlayer.play("AIR")
		Audio.play(Audio.attack2, self)
		
		var new_launch = $sonicrigged2.transform.basis.z.normalized() * 5
		new_launch.y = -2
		launch_power = new_launch
		damage_caused = 7

		velocity.y = 4
	elif attack_pressed && is_on_floor() && !starting:
		create_punch_timer()
		attacking = true
		if current_punch == 0:
			# The code to initiate Sonic's 3-hit combo. The rest of the punches are in _on_animation_player_animation_finished().
			$AnimationPlayer.play("punch1")
			$sonicrigged2/AnimationPlayer.play("PGC 1")
			Audio.play(Audio.attack1, self)
			launch_power = Vector3(0, 0, 0)
			damage_caused = 7
			current_punch = 1
		elif current_punch == 1:
			$AnimationPlayer.play("punch2")
			$sonicrigged2/AnimationPlayer.play("PGC 2")
			Audio.play(Audio.attack2, self)
			launch_power = Vector3(0, 0, 0)
			damage_caused = 7
			current_punch = 2
			
		elif current_punch == 2:
			$AnimationPlayer.play("punch3")
			$sonicrigged2/AnimationPlayer.play("PGC 3")
			Audio.play(Audio.attack2, self)
			launch_power = Vector3(0, 0, 0)
			damage_caused = 7
			current_punch = 3
		
		elif current_punch == 3:
			$AnimationPlayer.play("strong")
			$sonicrigged2/AnimationPlayer.play("PGC 4")
			
			Audio.play(Audio.attackStrong, self)
			var new_launch = $sonicrigged2.transform.basis.z.normalized() * 20
			new_launch.y = 5
			launch_power = new_launch
			damage_caused = 7
			current_punch = 0
	
	# The code for initiating Sonic's grounded and midair specials, which go to functions that check the selected skills.
	# no abilities on the hub areas
	if ground_skill != null and air_skill != null: #GlobalVariables.current_hub == null and GlobalVariables.current_area == null:
		if special_pressed && is_on_floor():
			attacking = true
			rpc("ground_special", randi(), direction)
		elif special_pressed && !is_on_floor() && can_air_attack:
			attacking = true
			can_air_attack = false
			rpc("air_special", randi(), direction)


## method to pace the healing of the character given an input
func handle_healing():
	if guard_pressed && is_on_floor():
		healing_time += healing_pace
		if healing_time >= healing_threshold:
			healing = true
			heal()
			Audio.play(Audio.heal, self)
			healing_time = 0
	else:
		if healing:
			$sonicrigged2/AnimationPlayer.play("IDLE")
		healing = false
		healing_time = 0
		if heal_effect != null:
			heal_effect.hide()


## method to heal the character's life total
func heal(amount = 4):
	if heal_effect == null:
		heal_effect = Instantiables.HEALING_EFFECT.instantiate()
		heal_effect.position = Vector3(0, -0.15, 0)
		add_child(heal_effect)
		heal_effect.get_child(0).emitting = true
	else:
		heal_effect.show()
		heal_effect.get_child(0).emitting = true
	
	if life_total < MAX_LIFE_TOTAL:
		life_total += amount
	if life_total > MAX_LIFE_TOTAL:
		life_total = MAX_LIFE_TOTAL
	
	increase_special(1)


## method to fill the character's special amount
func increase_special(amount = 1):
	if special_amount < MAX_SPECIAL_AMOUNT:
		special_amount += amount
	if special_amount > MAX_SPECIAL_AMOUNT:
		special_amount = MAX_SPECIAL_AMOUNT


## increase the total points gained in-game by one
func increase_points():
	points += 1
	GlobalVariables.bot_points = points
	if points >= GlobalVariables.points_to_win:
			GlobalVariables.win(self)


func collect_ring(ring):
	# increase the amount of rings
	# rings collected in a stage should count towards
	# the rings total only after the battle is over
	Audio.play(Audio.ring, self)
	if GlobalVariables.current_stage != null:
		rings += 1
		heal(HEAL_POINTS_PER_RING)
	
	if ring.has_method("delete_ring"):
		ring.delete_ring()


## scatter rings in a circular pattern
func scatter_rings(amount = 1):
	# inside a stage scatter one ring per hit
	# and more rings if the hit was strong
	# if on a hub or area scatter all rings
	if GlobalVariables.current_stage == null:
		amount = rings
	
	var number_of_rings_to_scatter = amount
	
	# clamp the value
	number_of_rings_to_scatter = clamp(number_of_rings_to_scatter, 0, MAX_SCATTERED_RINGS_ALLOWED)
	
	if rings > 0:
		rings -= amount
		if rings < 0:
			rings = 0

	# relative ring position
	var proxy_position = position + transform.basis.z
	var angle = 360.0
	if number_of_rings_to_scatter > 0:
		angle = 360.0 / number_of_rings_to_scatter
	# circular pattern
	for i in number_of_rings_to_scatter:
		proxy_position = proxy_position.rotated(Vector3.UP, deg_to_rad(angle * i))
		var new_ring_position = position + proxy_position.normalized()
		Instantiables.create_scattered_ring(new_ring_position, position)


## This function mostly handles what animations play with what booleans.
func handle_animation():
	# None of these animations play when Sonic is in his hurt or attacking state.
	if !attacking && !hurt && !healing && !chasing_aggressor && !can_spike:
		if is_on_floor():
			# Animations that play when Sonic is on the ground. If he's not starting movement, at least.
			if !starting && !dashing:
				if round(velocity.x) != 0 || round(velocity.z) != 0:
					$AnimationPlayer.play("walk")
					$sonicrigged2/AnimationPlayer.play("WALK")
				else:
					$AnimationPlayer.play("idle")
					$sonicrigged2/AnimationPlayer.play("IDLE")
		else:
			# Midair animations. These don't play when Sonic is dashing.
			if !dashing:
				if velocity.y > 0:
					$AnimationPlayer.play("jump")
					$sonicrigged2/AnimationPlayer.play("JUMP")
					falling = false
				elif velocity.y <= 0 && !falling:
					# Because falling should only play once, this is tied to the falling state.
					$AnimationPlayer.play("fall")
					$sonicrigged2/AnimationPlayer.play("FALL")
					falling = true
	else:
		if !is_on_floor() && "PGC" in $sonicrigged2/AnimationPlayer.current_animation:
			if $sonicrigged2/AnimationPlayer.current_animation != "PGC 5":
				attacking = false
				current_punch = 0
				if velocity.y > 0:
					$AnimationPlayer.play("jump")
					$sonicrigged2/AnimationPlayer.play("JUMP")
					falling = false
				elif velocity.y <= 0 && !falling:
					# Because falling should only play once, this is tied to the falling state.
					$AnimationPlayer.play("fall")
					$sonicrigged2/AnimationPlayer.play("FALL")
					falling = true
		elif is_on_floor() && $sonicrigged2/AnimationPlayer.current_animation == "PAC":
				attacking = false
				$AnimationPlayer.play("idle")
				$sonicrigged2/AnimationPlayer.play("IDLE")
		elif healing:
			$AnimationPlayer.play("idle")
			$sonicrigged2/AnimationPlayer.play("HEAL")
		elif chasing_aggressor || can_spike:
			$AnimationPlayer.play("idle")
			$sonicrigged2/AnimationPlayer.play("TARGET")


## method to set the abilities and immunity of the character
## "SHOT", "POW" and SET" 
func set_abilities(new_abilities: Array):
	if new_abilities.size() == 3:
		ground_skill = new_abilities[0]
		air_skill = new_abilities[1]
		immunity = new_abilities[2]


func handle_after_image():
	if $sonicrigged2/AnimationPlayer.current_animation == "DASH" \
	or "DJMP" in $sonicrigged2/AnimationPlayer.current_animation \
	or chasing_ring or bouncing  or chasing_aggressor:
		create_after_image()


func create_after_image():
	if after_image_time <= 0:
		after_image_time = 0.05
		var new_after_image = Instantiables.AFTER_IMAGE.instantiate()
		new_after_image.position = position
		new_after_image.get_child(0).transform.basis.z = $sonicrigged2.transform.basis.z
		new_after_image.current_animation_name = $sonicrigged2/AnimationPlayer.current_animation
		new_after_image.current_animation_time = $sonicrigged2/AnimationPlayer.current_animation_position

		get_parent().add_child(new_after_image)


func anim_end(anim_name):
	if anim_name == "WALK START":
		# End the "starting" state when the starting animation ends.
		starting = false
		walking = true
	elif anim_name == "DJMP 1":
		$sonicrigged2/AnimationPlayer.play("DJMP 3")
		can_air_attack = false
		can_airdash = false
		coyote_timer = null
	elif anim_name == "DJMP 3":
		# Go back to falling state when airdash ends.
		dashing = false
		$AnimationPlayer.play("fall")
		$sonicrigged2/AnimationPlayer.play("FALL")
		falling = true
	elif anim_name == "PGC 4":
		# Sonic's normal strong attack has an extra effect where he has to recoil backwards,
		# so this code plays that recoil and adjusts his velocity accordingly.
		$AnimationPlayer.play("strongRecoil")
		$sonicrigged2/AnimationPlayer.play("PGC 5")
		velocity = -$sonicrigged2.basis.z.normalized() * 3
		velocity.y = 3
		can_air_attack = false
		can_airdash = false
	elif anim_name == "PGC 5" || anim_name == "UPPER":
		# Resets Sonic's attacking state when the up strong or the regular strong recoil ends.
		attacking = false
		starting = false
		can_air_attack = false
		can_airdash = false
		can_chase = false
	elif anim_name == "DASH ATK":
		# Resets Sonic's attacking state when his dash attack ends.
		attacking = false
		dashing = false
	elif anim_name == "AIM":
		attacking = false
		can_air_attack = false
	elif anim_name == "AIR" || anim_name == "PAC":
		# Resets Sonic's attacking state when his air attack ends. Also sets him to falling state.
		attacking = false
		jumping = false
		falling = true
		$AnimationPlayer.play("fall")
		$sonicrigged2/AnimationPlayer.play("FALL")
	elif anim_name == "PGC 1" || anim_name == "PGC 2" || anim_name == "PGC 3":
		# The 3-hit combo. Press the punch button again before punch_timer runs out to do the next attack
		if attack_pressed and punch_timer != null and punch_timer.time_left > 0:
			# create a new timer to give time for a possible combo sequence
			create_punch_timer()
			if current_punch == 1:
				$AnimationPlayer.play("punch2")
				$sonicrigged2/AnimationPlayer.play("PGC 2")
				#Audio.play(Audio.attack2, self)
				launch_power = Vector3(0, 0, 0)
				damage_caused = 7
				current_punch = 2
			elif current_punch == 2:
				$AnimationPlayer.play("punch3")
				$sonicrigged2/AnimationPlayer.play("PGC 3")
				#Audio.play(Audio.attack2, self)
				launch_power = Vector3(0, 0, 0)
				damage_caused = 7
				current_punch = 3
			elif current_punch == 3:
				# The final part of the combo does an immediate strong attack.
				$AnimationPlayer.play("strong")
				$sonicrigged2/AnimationPlayer.play("PGC 4")
				#Audio.play(Audio.attackStrong, self)
				
				var new_launch = $sonicrigged2.transform.basis.z.normalized() * 20
				new_launch.y = 5
				launch_power = new_launch
				damage_caused = 7
				current_punch = 0
		else:
			attacking = false

	elif anim_name == "HURT 1" || anim_name == "HURT 2":
		# Reset's Sonic's "hurt" state when the animation ends.
		hurt = false
		starting = false
		can_air_attack = false
	elif anim_name == "KO":
		if life_total > 0:
			$sonicrigged2/AnimationPlayer.play("GET UP FULL")
		else:
			defeated()
	elif anim_name == "GET UP FULL":
		hurt = false
		starting = false
		can_air_attack = false
	elif anim_name == "WALL":
		hurt = false
		starting = false
		can_air_attack = false
	elif anim_name == "LAUNCHED":
		# For as long as Sonic is in the air, the animation loops. When he hits the ground, his state resets.
		if is_on_floor():
			$sonicrigged2/AnimationPlayer.play("KO")
		else:
			$AnimationPlayer.play("hurtStrong")
			$sonicrigged2/AnimationPlayer.play("LAUNCHED")
	elif anim_name == "SPIKED":
		if !is_on_floor():
			$sonicrigged2/AnimationPlayer.play("SPIKED")
		else:
			$sonicrigged2/AnimationPlayer.play("KO")
			spiked = false
	elif anim_name in ["RING", "BOMB G (LAZY)", "BOMB A"]:
		# Handles Sonic's reset states for all of his special moves.
		attacking = false
		starting = false
		bouncing = false
		pow_move = false
		if !is_on_floor():
			# Sets Sonic's falling state if he's in the air.
			jumping = false
			falling = true
			$AnimationPlayer.play("fall")
			$sonicrigged2/AnimationPlayer.play("FALL")
	elif anim_name == "DJMP 2":
		if !is_on_floor() && chasing_ring:
			$sonicrigged2/AnimationPlayer.play("DJMP 2")
		else:
			attacking = false
			starting = false
			bouncing = false
			pow_move = false
		if !is_on_floor():
			# Sets Sonic's falling state if he's in the air.
			jumping = false
			falling = true
			$AnimationPlayer.play("fall")
			$sonicrigged2/AnimationPlayer.play("FALL")

	if punch_timer == null or punch_timer.time_left <= 0:
		# If the player doesn't continue the combo, Sonic's states reset as usual.
		current_punch = 0

## Very simple signal state determining when the attack hitbox actually hits something.
func _on_hitbox_body_entered(body):
	if body.is_in_group("CanHurt") && body != self and attacking:
		Audio.play(Audio.hit, self)
		if $sonicrigged2/AnimationPlayer.current_animation == "PGC 4":
			last_aggressor = body
			can_chase = true
		# If the current attack is Sonic's "pow" move, the hitbox pays attention to immunities.
		if !pow_move || body.immunity != "pow":
			body.get_hurt.rpc_id(body.get_multiplayer_authority(), launch_power, self, damage_caused)


func defeated():
	if was_defeated == false:
		# trigger once per instance
		was_defeated = true
		
		var ko_effect = Instantiables.KO_EFFECT.instantiate()
		ko_effect.position = position
		get_parent().add_child(ko_effect)
		ko_effect.get_child(0).emitting = true

		# give a point for defeating the character
		if last_aggressor != null:
			if last_aggressor.has_method("increase_points"):
				last_aggressor.increase_points()
		
		if GlobalVariables.game_ended == false:
			Instantiables.spawn_bot()
	queue_free()


## A function that handles Sonic getting hurt. Knockback is determined by the thing that initiates this
# function, which is why you don't see it here.
@rpc("any_peer","reliable","call_local")
func get_hurt(launch_speed, owner_of_the_attack, damage_taken = 1):
	if $sonicrigged2/AnimationPlayer.current_animation != "KO" and $sonicrigged2/AnimationPlayer.current_animation != "SPIKED":
		# store the last player who damaged this character
		last_aggressor = owner_of_the_attack
		
		var sparks = Instantiables.SPARKS.instantiate()
		sparks.position = position + Vector3(0, 0.1, 0)
		get_parent().add_child(sparks)
		sparks.get_child(0).emitting = true
		
		# give a invunerability time
		
		if !hurt:
			# rings shouldn't provid all life points back
			if damage_taken > MAX_SCATTERED_RINGS_ALLOWED * HEAL_POINTS_PER_RING:
				scatter_rings(MAX_SCATTERED_RINGS_ALLOWED)
				Audio.play(Audio.ring_spread, self)
			else:
				scatter_rings()
		
		life_total -= damage_taken
		if life_total < 0:
			life_total = 0
		# A bunch of states reset to make sure getting hurt cancels them out.
		hurt = true
		falling = false
		jumping = false
		bouncing = false
		healing = false
		can_chase = false
		
		velocity = launch_speed
		# If Sonic was chasing a ring, the ring is deleted.
		if chasing_ring:
			chasing_ring = false
			thrown_ring = false
			if active_ring != null:
				active_ring.queue_free()
		
		# Depending on where Sonic is and what his velocity is, the animation is different.
		if abs(velocity.x) > 8 || abs(velocity.z) > 8:
			$AnimationPlayer.play("hurtStrong")
			$sonicrigged2/AnimationPlayer.play("LAUNCHED")
		else:
			if launch_speed.y > 5:
				$AnimationPlayer.play("hurtAir")
				$sonicrigged2/AnimationPlayer.play("HURT 2")
			elif launch_speed.y < 0 && !is_on_floor():
				$AnimationPlayer.play("hurtAir")
				$sonicrigged2/AnimationPlayer.play("SPIKED")
				spiked = true
			else:
				$AnimationPlayer.play("hurt")
				$sonicrigged2/AnimationPlayer.play("HURT 1")
		
		# More state resets. Idk why these are placed at the end.
		current_punch = 0
		dashing = false
		attacking = false
		
		if GlobalVariables.current_stage != null:
			if (life_total <= 0 and GlobalVariables.game_ended == false):
				if !is_on_floor():
					$AnimationPlayer.play("hurtAir")
					$sonicrigged2/AnimationPlayer.play("SPIKED")
				else:
					$AnimationPlayer.play("hurt")
					$sonicrigged2/AnimationPlayer.play("KO")


## The function for determining what happens with each selected grounded special move.
@rpc("any_peer", "reliable", "call_local")
func ground_special(id, _dir):
	if ground_skill == "SHOT":
		# Sonic's ground "shot" move sends a shockwave in the direction specified by the player.
		# Sonic is also launched back away from the direction of the projectile.
		can_air_attack = false
		can_airdash = false
		$AnimationPlayer.play("shotGround")
		$sonicrigged2/AnimationPlayer.play("DJMP 2")
		Audio.play(Audio.shot, self)
		#Instantiates a new shot projectile.
		var new_shot = Instantiables.create(Instantiables.objects.SHOT_PROJECTILE)
		new_shot.user = self	# This makes sure Sonic can't hit himself with a projectile.
		new_shot.set_meta("author", name)
		new_shot.name = "wave" + str(id)
		var new_forward = $sonicrigged2.transform.basis.z.normalized()
		new_forward.y = 0
		new_shot.transform.basis.z = new_forward		
		new_shot.velocity = Vector3($sonicrigged2.basis.z.normalized().x * 3, 0, $sonicrigged2.basis.z.normalized().z * 3)
		velocity = -$sonicrigged2.basis.z.normalized() * 5
		velocity.y = 5
		
		new_shot.position = position
		# Creates the projectile.
		new_shot.set_multiplayer_authority(get_multiplayer_authority())
		get_tree().current_scene.add_child(new_shot, true)
	elif ground_skill == "POW":
		# Sonic's ground "pow" move first throws a ring. If the player inputs the move again,
		# Sonic will accelerate in the direction of the ring.
		# The ring is sent in a specified direciton.
		if !thrown_ring:	# When no ring is on the field.
			$AnimationPlayer.play("powGround")
			$sonicrigged2/AnimationPlayer.play("RING")
			Audio.play(Audio.ring, self)
			#Instantiates a new ring projectile
			var new_ring = Instantiables.create(Instantiables.objects.TOSS_RING)
			new_ring.ring_owner = self
			active_ring = new_ring
			new_ring.name = "ring" + str(id)
			thrown_ring = true
			new_ring.position = position
			new_ring.velocity = Vector3($sonicrigged2.basis.z.normalized().x * 3, 5, $sonicrigged2.basis.z.normalized().z * 3)
			# Creates the ring projectile.
			get_tree().current_scene.add_child(new_ring, true)
		else:	# When a ring is on the field.
			launch_power = Vector3(0, 6, 0)
			damage_caused = 7
			velocity = (active_ring.transform.origin - transform.origin).normalized() * 7
			velocity.y = 5
			pow_move = true
			$AnimationPlayer.play("powAir")
			$sonicrigged2/AnimationPlayer.play("DJMP 2")
			Audio.play(Audio.bounce, self)
			thrown_ring = false
			chasing_ring = true
			if active_ring != null:
				active_ring.queue_free()
	elif ground_skill == "SET":
		# Sonic's grounded "set" move sets down a mine where he's standing, which explodes over time
		# or on contact.
		$AnimationPlayer.play("setGround")
		$sonicrigged2/AnimationPlayer.play("BOMB G (LAZY)")
		if active_mine == null: # Only works if there's no mine already active.
			# Instantiates a new mine object.
			var new_mine = Instantiables.create(Instantiables.objects.SET_MINE) #set_mine.instantiate()
			new_mine.position = position
			new_mine.name = "mine" + str(id)
			new_mine.set_multiplayer_authority(get_multiplayer_authority())
			new_mine.user = self	# This makes sure Sonic can't hit himself with his own mine.
			active_mine = new_mine
			# Creates the mine
			get_tree().current_scene.add_child(new_mine, true)


## The function for determining what happens with each selected air special move.
@rpc("authority","call_local")
func air_special(id, _dir):
	if air_skill == "SHOT":
		# This works almost exactly the same as the grounded version,
		# Sonic sends a wave projectile that falls to the ground, which moves based on a specified
		# direction. He is also sent backwards away from the projectile.
		$AnimationPlayer.play("shotAir")
		$sonicrigged2/AnimationPlayer.play("DJMP 2")
		Audio.play(Audio.shot, self)
		can_air_attack = false
		can_airdash = false
		can_air_attack = false
		can_airdash = false
		#Instantiates a new shot projectile.
		var new_shot = Instantiables.create(Instantiables.objects.SHOT_PROJECTILE) #shot_projectile.instantiate()
		new_shot.user = self	# This makes sure Sonic can't hit himself with a projectile.
		new_shot.name = "wave" + str(id)
		new_shot.set_multiplayer_authority(get_multiplayer_authority())
		new_shot.position = position

		var new_forward = $sonicrigged2.transform.basis.z.normalized()
		new_forward.y = 0
		new_shot.transform.basis.z = new_forward

		new_shot.velocity = Vector3($sonicrigged2.basis.z.normalized().x * 3, 0, $sonicrigged2.basis.z.normalized().z * 3)
		velocity = -$sonicrigged2.basis.z.normalized() * 5
		velocity.y = 2
		
		# Creates the projectile
		get_tree().current_scene.add_child(new_shot, true)
	elif air_skill == "POW":
		# Sonic's midair "pow" move causes him to curl into a ball and launch himself towards the ground
		# If Sonic hits the ground, he bounces once.
		$AnimationPlayer.play("powAir")
		$sonicrigged2/AnimationPlayer.play("DJMP 2")
		Audio.play(Audio.bounce, self)
		pow_move = true
		bouncing = true	# Initiates the "bouncing" state for bouncing off the ground.
		launch_power = Vector3(0, 6, 0)
		velocity.y = -5
		damage_caused = 7
		#velocity = $sonicrigged2.basis.z.normalized() * 10
		#velocity.y = -5
	elif air_skill == "SET":
		# Works exactly like the grounded variant, Sonic places a mine that falls to the ground.
		# The mine explodes over time or on impact.
		# In the air, Sonic also gets a slight bit of air stall.
		$AnimationPlayer.play("setAir")
		$sonicrigged2/AnimationPlayer.play("BOMB A")
		can_air_attack = false
		can_airdash = false
		if active_mine == null:	# Only works if there's no mine already active.
			velocity.y = 3
			# Instantiates a new mine object.
			var new_mine = Instantiables.create(Instantiables.objects.SET_MINE) #set_mine.instantiate()
			new_mine.name = "mine" + str(id)
			new_mine.position = position
			new_mine.user = self	# This makes sure Sonic can't hit himself with his own mine.
			active_mine = new_mine
			# Creates the mine object.
			get_tree().current_scene.add_child(new_mine, true)


## use Area3D to detect collectables like rings and hazards
func _on_ring_collider_area_entered(area):
	# store the parent of the Area3D the character collided
	if area.get_parent() != null && life_total > 0:
		var collided_object = area.get_parent()
		
		# collect ring
		if collided_object.is_in_group("Ring"):
			collect_ring(collided_object)


func rotate_model():
	if direction && !attacking && !healing:
		$sonicrigged2.rotation.y = Vector2(velocity.z, velocity.x).angle()
