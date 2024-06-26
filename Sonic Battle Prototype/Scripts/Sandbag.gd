extends CharacterBody3D

# Silly little sandbag object for testing knockback.
# Original code by The8BitLeaf.

# The speed at which Sandbag falls, right now everyone and everything should have a gravity of 20.
var gravity = 20

# Immunity value for testing immunities (Also the collision code relies on checking immunities so this has to be here)
var immunity = "none"

func _physics_process(delta):
	# Add the gravity.
	if !is_on_floor():
		velocity.y -= gravity * delta
	
	# Slows to a halt after being launched.
	velocity.x = lerp(velocity.x, 0.0, 0.1)
	velocity.z = lerp(velocity.z, 0.0, 0.1)
	
	move_and_slide()

# Literally just a blank function since the hitbox code calls a "get_hurt()" function
func get_hurt():
	pass
