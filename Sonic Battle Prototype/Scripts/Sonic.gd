extends CharacterBody3D

# This is the script for the playable character Sonic.
# Most of the code can be copied over to other characters, but a lot of values and
# character-specific actions will need to be adjusted in order to copy this code over.
# Original code by The8BitLeaf.


# Basic movement speed values for Sonic.
const SPEED = 4.0
const JUMP_VELOCITY = 6.0

# Dash speed is the speed value for the dash move executed by double tapping a direction on the ground
# Sonic's midair jump ability is an air dash, and the speed is determined by airdash speed.
const DASH_SPEED = 15.0
const AIRDASH_SPEED = 10.0

# The speed at which Sonic falls, right now everyone and everything should have a gravity of 20.
var gravity = 20

# Boolean to check if Sonic is facing left or right
var facing_left = false

# Booleans for checking when Sonic is jumping or falling, used to make sure
# that Sonic plays the correct animations.
var jumping = false
var falling = false

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

# States for when Sonic is hurt, locking his actions.
var hurt = false
var launched = false

# Skills! These strings determine what Sonic's grounded and midair special type are.
# Immunity determines which category of special move Sonic is immune to.
var ground_skill = "pow"
var air_skill = "shot"
var immunity = "none"

# Sonic's midair "pow" special move bounces off the ground, so this state makes sure he does that.
var bouncing = false

# The prefab for spawning Sonic's "shot" projectile.
var shot_projectile = preload("res://Scenes/SonicWave.tscn")

# active_ring is the object recently created by Sonic's grounded "pow" move, for checking constant positioning.
# thrown_ring indicates when a ring is on the field, to avoid calling a null active_ring
var active_ring
var thrown_ring = false

# The state in which Sonic is moving in the direction of active_ring.
var chasing_ring = false

# The ring prefab that Sonic will throw when he uses his "pow" move on the ground.
var ring = preload("res://Scenes/ThrowRing.tscn")

# The mine prefab for Sonic's "set" special moves.
var set_mine = preload("res://Scenes/SonicMine.tscn")

# The mine object currently on the field, to ensure only one mine can be used at a time.
var active_mine

# Since Sonic's "pow" move is a melee attack and uses his regular hitboxes,
# this boolean ensures that immunities still apply.
var pow_move = false

func _enter_tree():
	
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	
	$MainCam.current = true
	
# Setting a drop shadow is weird in _physics_process(), so the drop shadow code is in _process().
func _process(delta):
	# If the drop shadow ray detects ground, it sets the visual shadow at the collision point.
	if $DropShadowRange.is_colliding():
		$DropShadow.visible = true
		$DropShadow.global_position.y = $DropShadowRange.get_collision_point().y
	else:
		$DropShadow.visible = false

func _physics_process(delta):
	if !is_multiplayer_authority(): return
	
	if !is_on_floor():
		# add the gravity.
		velocity.y -= gravity * delta
		# Since starting and walking only do things on the ground, they are set to inactive here.
		starting = false
		walking = false
	else:
		# Being on the ground means you aren't jumping or falling
		jumping = false
		falling = false
		# Because Sonic's dash is a sort of jump, this is how the move resets itself.
		# For characters that slide along the ground (i.e. Shadow), this may change.
		dashing = false
		# Midair moves can only be used after a jump once, and they can be used again after touching the ground.
		can_airdash = true
		can_air_attack = true
		# If Sonic is in his midair "pow" bouncing state, his velocity sends him upwards off the ground.
		if bouncing:
			velocity.y = 5
			can_air_attack = false	# As funny as it would be to have the SA2 bounce spam, it would be too OP here.
		
		# This set of "if" statements handles the dash. Pressing your current velocity direction
		# while in the starting state causes Sonic to dash in that direction, recreating the "double-tap" input.
		# This is probably a very workaround solution and there's probably a way to make it work better
		# But this is the best solution I could come up with.
		if Input.is_action_just_pressed("ui_left") && $AnimationPlayer.current_animation == "startWalk" && velocity.x < 0:
			velocity = Vector3(-DASH_SPEED, 4, velocity.z)
			$AnimationPlayer.play("dash")
			dashing = true
		elif Input.is_action_just_pressed("ui_right") && $AnimationPlayer.current_animation == "startWalk" && velocity.x > 0:
			velocity = Vector3(DASH_SPEED, 4, velocity.z)
			$AnimationPlayer.play("dash")
			dashing = true
		elif Input.is_action_just_pressed("ui_up") && $AnimationPlayer.current_animation == "startWalk" && velocity.z < 0:
			velocity = Vector3(velocity.x, 4, -DASH_SPEED)
			$AnimationPlayer.play("dash")
			dashing = true
		elif Input.is_action_just_pressed("ui_down") && $AnimationPlayer.current_animation == "startWalk" && velocity.z > 0:
			velocity = Vector3(velocity.x, 4, DASH_SPEED)
			$AnimationPlayer.play("dash")
			dashing = true
		
	
	if !attacking && !hurt:
		# Get the input direction
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		# Handle Jump.
		# If you're in the air, Sonic performs his midair action (as long as he hasn't used it yet.)
		if Input.is_action_just_pressed("ui_select") && is_on_floor():
			velocity.y = JUMP_VELOCITY
			jumping = true
		elif Input.is_action_just_pressed("ui_select") && !is_on_floor() && can_airdash:
			dashing = true
			can_airdash = false
			$AnimationPlayer.play("airdash")
			# If Sonic is inputting a direction, he airdashes in that direction.
			# If no direction is held, he moves horizontally in the direction he's facing.
			if direction:
				velocity = Vector3(direction.x * AIRDASH_SPEED, 4, direction.z * AIRDASH_SPEED)
			else:
				if facing_left:
					velocity = Vector3(-AIRDASH_SPEED, 4, 0)
				else:
					velocity = Vector3(AIRDASH_SPEED, 4, 0)
		
		# Code for handling basic movement
		if direction:
			# If Sonic is at a standstill before moving, he enters his starting state for dashes and strong attacks.
			if !starting && !walking && is_on_floor():
				starting = true
				$AnimationPlayer.play("startWalk")
			velocity.x = lerp(velocity.x, direction.x * SPEED, 0.1)
			velocity.z = lerp(velocity.z, direction.z * SPEED, 0.1)
		else:
			walking = false
			velocity.x = lerp(velocity.x, 0.0, 0.1)
			velocity.z = lerp(velocity.z, 0.0, 0.1)
		
		# Code for determining the direction Sonic is facing.
		# Since some moves hold backwards without turning.
		if velocity.x > 2:
			facing_left = false
			$Sprite3D.flip_h = false
			$Hitbox.rotation.y = deg_to_rad(0)
		elif velocity.x < -2:
			facing_left = true
			$Sprite3D.flip_h = true
			$Hitbox.rotation.y = deg_to_rad(180)
		
		# ALL the basic attacks are handled in this chain of if statements.
		if Input.is_action_just_pressed("ui_accept") && starting:
			# The code for Sonic's strong attacks. If he's holding the opposite direction,
			# he executes an up strong attack which slightly bumps him backwards.
			if (facing_left && direction.x > 0) || (!facing_left && direction.x < 0):
				$AnimationPlayer.play("upStrong")
				launch_power = Vector3(0, 7, 0)
				if facing_left:
					velocity.x = 1
				else:
					velocity.x = -1
			else:
				# If sonic holds any other direction, he executes a normal strong attack
				# that sends the opponent in the direction he specifies.
				$AnimationPlayer.play("strong")
				launch_power = Vector3(direction.x * 20, 5, direction.z * 20)
			attacking = true
		elif Input.is_action_just_pressed("ui_accept") && dashing && can_airdash:
			# The code for Sonic's dash attack. His dash attack stalls him in the air for a short time.
			can_airdash = false
			attacking = true
			$AnimationPlayer.play("dashAttack")
			launch_power = Vector3(velocity.x, 2, velocity.z)
			velocity.y = 3
		elif Input.is_action_just_pressed("ui_accept") && !dashing && !is_on_floor() && can_air_attack:
			# The code for Sonic's midair attack. He can only use this once before landing, and it
			# sends the opponent downwards.
			attacking = true
			can_air_attack = false
			$AnimationPlayer.play("airAttack")
			if facing_left:
				launch_power = Vector3(-5, -2, 0)
			else:
				launch_power = Vector3(5, -2, 0)
			velocity.y = 4
		elif Input.is_action_just_pressed("ui_accept") && is_on_floor() && !starting:
			# The code to initiate Sonic's 3-hit combo. The rest of the punches are in _on_animation_player_animation_finished().
			attacking = true
			$AnimationPlayer.play("punch1")
			launch_power = Vector3(0, 2, 0)
			current_punch = 1
		
		# The code for initiating Sonic's grounded and midair specials, which go to functions that check the selected skills.
		if Input.is_action_just_pressed("ui_cancel") && is_on_floor():
			attacking = true
			rpc("ground_special", randi(), direction)
		elif Input.is_action_just_pressed("ui_cancel") && !is_on_floor() && can_air_attack:
			attacking = true
			can_air_attack = false
			rpc("air_special", randi(), direction)
	else:
		# if Sonic is in his attacking or hurt state, he slows to a halt.
		velocity.x = lerp(velocity.x, 0.0, 0.1)
		velocity.z = lerp(velocity.z, 0.0, 0.1)
	
	# If Sonic is currently chasing a ring he threw from his ground "pow" move, he accelerates to its position.
	if chasing_ring:
		velocity = lerp(velocity, (active_ring.transform.origin - transform.origin) * 20, 0.5)
	
	# Automatically handle the animation and character controller physics.
	handle_animation()
	move_and_slide()

# This function mostly handles what animations play with what booleans.
func handle_animation():
	# None of these animations play when Sonic is in his hurt or attacking state.
	if !attacking && !hurt:
		if is_on_floor():
			# Animations that play when Sonic is on the ground. If he's not starting movement, at least.
			if !starting:
				if round(velocity.x) != 0 || round(velocity.z) != 0:
					$AnimationPlayer.play("walk")
				else:
					$AnimationPlayer.play("idle")
		else:
			# Midair animations. These don't play when Sonic is dashing.
			if !dashing:
				if velocity.y > 0:
					$AnimationPlayer.play("jump")
					falling = false
				elif velocity.y <= 0 && !falling:
					# Because falling should only play once, this is tied to the falling state.
					$AnimationPlayer.play("fall")
					falling = true

# Signal function for when animations are finished.
func _on_animation_player_animation_finished(anim_name):
	if anim_name == "startWalk":
		# End the "starting" state when the starting animation ends.
		starting = false
		walking = true
	elif anim_name == "airdash":
		# Go back to falling state when airdash ends.
		dashing = false
		$AnimationPlayer.play("fall")
		falling = true
	elif anim_name == "strong":
		# Sonic's normal strong attack has an extra effect where he has to recoil backwards,
		# so this code plays that recoil and adjusts his velocity accordingly.
		$AnimationPlayer.play("strongRecoil")
		if facing_left:
			velocity.x = 3
		else:
			velocity.x = -3
		velocity.y = 3
	elif anim_name == "strongRecoil" || anim_name == "upStrong":
		# Resets Sonic's attacking state when the up strong or the regular strong recoil ends.
		attacking = false
		starting = false
	elif anim_name == "dashAttack":
		# Resets Sonic's attacking state when his dash attack ends.
		attacking = false
		dashing = false
	elif anim_name == "airAttack":
		# Resets Sonic's attacking state when his air attack ends. Also sets him to falling state.
		attacking = false
		jumping = false
		falling = true
		$AnimationPlayer.play("fall")
	elif anim_name == "punch1" || anim_name == "punch2" || anim_name == "punch3":
		# The 3-hit combo. If the player is holding the attack button by the time a punch finishes,
		# it moves on to the next punch.
		# NOTE: I tried making it so that the punches execute with pressing the button instead of holding,
		# but I couldn't get it working right so this will have to do for now.
		if Input.is_action_pressed("ui_accept"):
			if current_punch == 1:
				$AnimationPlayer.play("punch2")
				launch_power = Vector3(0, 2, 0)
				current_punch = 2
			elif current_punch == 2:
				$AnimationPlayer.play("punch3")
				launch_power = Vector3(0, 2, 0)
				current_punch = 3
			elif current_punch == 3:
				# The final part of the combo does an immediate strong attack.
				$AnimationPlayer.play("strong")
				if facing_left:
					launch_power = Vector3(-20, 5, 0)
				else:
					launch_power = Vector3(20, 5, 0)
				current_punch = 0
		else:
			# If the player doesn't continue the combo, Sonic's states reset as usual.
			attacking = false
			current_punch = 0
	elif anim_name == "hurt" || anim_name == "hurtAir":
		# Reset's Sonic's "hurt" state when the animation ends.
		hurt = false
		starting = false
	elif anim_name == "hurtStrong":
		# For as long as Sonic is in the air, the animation loops. When he hits the ground, his state resets.
		if is_on_floor():
			hurt = false
			starting = false
		else:
			$AnimationPlayer.play("hurtStrong")
	elif anim_name in ["shotGround", "shotAir", "powGround", "powAir", "setGround", "setAir"]:
		# Handles Sonic's reset states for all of his special moves.
		attacking = false
		starting = false
		bouncing = false
		pow_move = false
		# If the animation is used for chasing the ring, the ring disappears and more states reset.
		if chasing_ring:
			chasing_ring = false
			thrown_ring = false
			active_ring.queue_free()
		if !is_on_floor():
			# Sets Sonic's falling state if he's in the air.
			jumping = false
			falling = true
			$AnimationPlayer.play("fall")

# A function that handles Sonic getting hurt. Knockback is determined by the thing that initiates this
# function, which is why you don't see it here.
@rpc("any_peer","reliable","call_local")
func get_hurt(launch_speed):
	# A bunch of states reset to make sure getting hurt cancels them out.
	hurt = true
	falling = false
	jumping = false
	bouncing = false
	
	velocity = launch_speed
	# If Sonic was chasing a ring, the ring is deleted.
	if chasing_ring:
			chasing_ring = false
			thrown_ring = false
			active_ring.queue_free()
	
	# Depending on where Sonic is and what his velocity is, the animation is different.
	if abs(velocity.x) > 8 || abs(velocity.z) > 8:
		$AnimationPlayer.play("hurtStrong")
	else:
		if !is_on_floor():
			$AnimationPlayer.play("hurtAir")
		else:
			$AnimationPlayer.play("hurt")
	
	# More state resets. Idk why these are placed at the end.
	current_punch = 0
	dashing = false
	attacking = false

# Very simple signal state determining when the attack hitbox actually hits something.
func _on_hitbox_body_entered(body):
	if !is_multiplayer_authority(): return
	if body.is_in_group("CanHurt") && body != self:
		# If the current attack is Sonic's "pow" move, the hitbox pays attention to immunities.
		if !pow_move || body.immunity != "pow":
			body.get_hurt.rpc_id(body.get_multiplayer_authority(), launch_power)

# The function for determining what happens with each selected grounded special move.
@rpc("any_peer", "reliable", "call_local")
func ground_special(id, dir):
	if ground_skill == "shot":
		# Sonic's ground "shot" move sends a shockwave in the direction specified by the player.
		# Sonic is also launched back away from the direction of the projectile.
		# If no direction is held, the direction is determined by facing_left.
		can_air_attack = false
		$AnimationPlayer.play("shotGround")
		#Instantiates a new shot projectile.
		var new_shot = shot_projectile.instantiate()
		new_shot.user = self	# This makes sure Sonic can't hit himself with a projectile.
		new_shot.set_meta("author", name)
		new_shot.name = "wave" + str(id)
		# Code for choosing what direction the projectile is sent and where Sonic is sent.
		if dir:
			new_shot.velocity = Vector3(dir.x * 3, 0, dir.z * 3)
			velocity = Vector3(dir.x * -5, 5, dir.z * -5)
		else:
			if $Sprite3D.flip_h:
				new_shot.velocity = Vector3(-3, 0, 0)
				velocity = Vector3(5, 5, 0)
			else:
				new_shot.velocity = Vector3(3, 0, 0)
				velocity = Vector3(-5, 5, 0)
		
		new_shot.position = position
		# Creates the projectile.
		new_shot.set_multiplayer_authority(get_multiplayer_authority())
		# get_tree().current_scene.add_child(new_shot, true)
		get_tree().current_scene.add_child(new_shot, true)
	elif ground_skill == "pow":
		# Sonic's ground "pow" move first throws a ring. If the player inputs the move again,
		# Sonic will accelerate in the direction of the ring.
		# The ring is sent in a specified direciton, if there is no direction it is sent based on facing_left.
		if !thrown_ring:	# When no ring is on the field.
			$AnimationPlayer.play("powGround")
			#Instantiates a new ring projectile
			var new_ring = ring.instantiate()
			active_ring = new_ring
			new_ring.name = "ring" + str(id)
			thrown_ring = true
			new_ring.position = position
			# Code to determine what direction the ring is thrown.
			if dir:
				new_ring.velocity = Vector3(dir.x * 3, 5, dir.z * 3)
			else:
				if $Sprite3D.flip_h:
					new_ring.velocity = Vector3(-3, 5, 0)
				else:
					new_ring.velocity = Vector3(3, 5, 0)
			# Creates the ring projectile.
			get_tree().current_scene.add_child(new_ring, true)
		else:	# When a ring is on the field.
			launch_power = Vector3(0, 2, 0)
			pow_move = true
			$AnimationPlayer.play("powAir")
			chasing_ring = true
	elif ground_skill == "set":
		# Sonic's grounded "set" move sets down a mine where he's standing, which explodes over time
		# or on contact.
		$AnimationPlayer.play("setGround")
		if active_mine == null: # Only works if there's no mine already active.
			# Instantiates a new mine object.
			var new_mine = set_mine.instantiate()
			new_mine.position = position
			new_mine.name = "mine" + str(id)
			new_mine.set_multiplayer_authority(get_multiplayer_authority())
			new_mine.user = self	# This makes sure Sonic can't hit himself with his own mine.
			active_mine = new_mine
			# Creates the mine
			get_tree().current_scene.add_child(new_mine, true)
@rpc("authority","call_local")
func air_special(id, dir):
	if air_skill == "shot":
		# This works almost exactly the same as the grounded version,
		# Sonic sends a wave projectile that falls to the ground, which moves based on a specified
		# direction. He is also sent backwards away from the projectile.
		$AnimationPlayer.play("shotAir")
		#Instantiates a new shot projectile.
		var new_shot = shot_projectile.instantiate()
		new_shot.user = self	# This makes sure Sonic can't hit himself with a projectile.
		new_shot.name = "wave" + str(id)
		new_shot.set_multiplayer_authority(get_multiplayer_authority())
		new_shot.position = position
		# Code for choosing what direction the projectile is sent and where Sonic is sent.
		if dir:
			new_shot.velocity = Vector3(dir.x * 3, 0, dir.z * 3)
			velocity = Vector3(dir.x * -5, 2, dir.z * -5)
		else:
			if $Sprite3D.flip_h:
				new_shot.velocity = Vector3(-3, 0, 0)
				velocity = Vector3(5, 2, 0)
			else:
				new_shot.velocity = Vector3(3, 0, 0)
				velocity = Vector3(-5, 2, 0)
		
		# Creates the projectile
		get_tree().current_scene.add_child(new_shot, true)
	elif air_skill == "pow":
		# Sonic's midair "pow" move causes him to curl into a ball and launch himself towards the ground
		# and foward slightly depending on held direction/facing_left.
		# If Sonic hits the ground, he bounces once.
		$AnimationPlayer.play("powAir")
		pow_move = true
		bouncing = true	# Initiates the "bouncing" state for bouncing off the ground.
		launch_power = Vector3(0, 2, 0)
		# Code for choosing what direction Sonic is sent.
		if dir:
			velocity = Vector3(dir.x * 10, -5, dir.z * 10)
		else:
			if $Sprite3D.flip_h:
				velocity = Vector3(-10, -5, 0)
			else:
				velocity = Vector3(10, -5, 0)
	elif air_skill == "set":
		# Works exactly like the grounded variant, Sonic places a mine that falls to the ground.
		# The mine explodes over time or on impact.
		# In the air, Sonic also gets a slight bit of air stall.
		$AnimationPlayer.play("setAir")
		can_air_attack = false
		if active_mine == null:	# Only works if there's no mine already active.
			velocity.y = 3
			# Instantiates a new mine object.
			var new_mine = set_mine.instantiate()
			new_mine.name = "mine" + str(id)
			new_mine.position = position
			new_mine.user = self	# This makes sure Sonic can't hit himself with his own mine.
			active_mine = new_mine
			# Creates the mine object.
			get_tree().current_scene.add_child(new_mine, true)


