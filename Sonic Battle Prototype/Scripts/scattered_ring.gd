extends CharacterBody3D

# Original code by The8BitLeaf. changed later

const DEFAULT_BOUNCE_VALUE: float = 4.0
const MIN_TIME: float = 3.5
var bounce_amount: float = DEFAULT_BOUNCE_VALUE
var blinking_period: float = 0.0

@export var ring: Node3D
@export var collision_area: Area3D


func _ready():
	#collision_area.monitorable = false
	collision_area.set_deferred("monitorable", false)


func _physics_process(delta):
	# Add the gravity.
	if !is_on_floor():
		# The speed at which the ring falls
		velocity.y -= GlobalVariables.gravity * delta
	else:
		bounce_amount = move_toward(bounce_amount, 0, 0.4)
		# If the ring hits the ground, it bounces.
		velocity.y = bounce_amount
	
	# The ring slows down after moving for a while, becoming stationary.
	velocity.x = lerp(velocity.x, 0.0, 0.02)
	velocity.z = lerp(velocity.z, 0.0, 0.02)
	
	move_and_slide()
	
	if GlobalVariables.scattered_ring_timer != null:
		# enable the detection after it scattered
		if GlobalVariables.scattered_ring_timer.time_left <= MIN_TIME:
			collision_area.monitorable = true
		
		if GlobalVariables.scattered_ring_timer.time_left <= 3.0:
			# blink faster as the time out approaches
			if blinking_period <= 0:
				blinking_period = GlobalVariables.scattered_ring_timer.time_left / 5.0
			blinking_period -= delta * 5
			if blinking_period <= 0.0:
				if ring.is_visible_in_tree():
					ring.hide()
				else:
					ring.show()
		
		# delete when scaterred rings timer runs out
		if GlobalVariables.scattered_ring_timer.time_left <= 0:
			delete()


## add a method unique to the ring
## to prevent deleting another object
func delete_ring():
	if GlobalVariables.scattered_ring_timer != null\
	 and GlobalVariables.scattered_ring_timer.time_left <= MIN_TIME:
		delete()


@rpc("any_peer", "call_local")
func delete():
	queue_free()
