extends CharacterBody2D

@export var speed = 140.0
@export var climbSpeed = 80.0
@export var jumpVelocity = -250.0
@export var jumpBufferTime = 0.1

@export var fallMultiplier = 0.4
@export var lowJumpMultiplier = 0.5

@onready var coyoteTimer = $CoyoteTimer
@onready var groundDetector = $GroundDetector
@onready var bottomRightCast = $BottomRightCast
@onready var topRightCast = $TopRightCast
@onready var bottomLeftCast = $BottomLeftCast
@onready var topLeftCast = $TopLeftCast

var jumpBuffered = false

var jumpStartTime = 0.0

var isTouchingWall = false
var isGrabbingWall = false
var isOnFloor = false
var wasOnFloor = false

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var checkpoint = Vector2.ZERO


func _ready():
	checkpoint = global_position

func _physics_process(delta):
	apply_gravity(delta)
	isOnFloor = is_on_floor() || groundDetector.has_overlapping_bodies()
	wasOnFloor = isOnFloor
	handle_buffers()
	handle_jump()
	handle_movement(delta)
	
	extra_gravity(delta)
	nudge_onto_edge()
	move_and_slide()
	update_coyote_data()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

func extra_gravity(delta):
	var currentTime = Time.get_ticks_msec()
	var timeSinceJump = (currentTime - jumpStartTime) / 1000.0
	
	if velocity.y > 0: # If player is falling, apply more gravity
		velocity.y += gravity * fallMultiplier * delta
		
	elif velocity.y < 0 && !Input.is_action_pressed("jump"): # If player did small jump, apply more gravity
		if timeSinceJump < 0.2:
			var multiplier = (1 - timeSinceJump) * 3 # Longer jump = more gravity
			velocity.y += gravity * (lowJumpMultiplier * multiplier) * delta

func handle_buffers():
	if isOnFloor:
		if jumpBuffered:
			jump()

# Jumps if on ground, or starts buffer
# Buffer will jump automatically if player touches ground soon after
func handle_jump():
	if Input.is_action_just_pressed("jump"):
		if isOnFloor or coyoteTimer.time_left > 0.0:
			jump()
		else:
			jumpBuffered = true
			get_tree().create_timer(jumpBufferTime).timeout.connect(reset_jump_buffer)

func jump():
	jumpStartTime = Time.get_ticks_msec()
	velocity.y = jumpVelocity

func reset_jump_buffer():
	jumpBuffered = false

func handle_movement(delta):
	var hor_dir = Input.get_axis("move_left", "move_right")
	if hor_dir:
		velocity.x = hor_dir * speed
	else:
		# Slows down player, only relevant when additional forces are applied
		velocity.x = move_toward(velocity.x, 0, speed)

func update_coyote_data():
	# Check if just left floor after move_and_slide()
	if wasOnFloor and not is_on_floor() and velocity.y >= 0:
		coyoteTimer.start()

func nudge_onto_edge():
	if velocity.y > 0.0:
		return
	
	var collision_count = get_slide_collision_count()
	if collision_count < 1:
		return
	
	var collision = get_slide_collision(collision_count - 1)
	if not collision:
		return
	
	var dir = collision.get_normal() * -1
	if dir == Vector2(1, 0):
		if bottomRightCast.is_colliding() and not topRightCast.is_colliding():
			var yDist = topRightCast.global_position.y - bottomRightCast.global_position.y
			global_position += Vector2(1, yDist)
	elif dir == Vector2(-1, 0):
		pass
		if bottomLeftCast.is_colliding() and not topLeftCast.is_colliding():
			var yDist = topLeftCast.global_position.y - bottomLeftCast.global_position.y
			global_position += Vector2(-1, yDist)

func _on_spiked_entered(body):
	global_position = checkpoint
