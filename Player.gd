extends CharacterBody2D

@export var speed = 140.0 * 60 # Physic Updates
@export var climbSpeed = 80.0
@export var jumpVelocity = -250.0
@export var jumpBufferTime = 0.1

@export var wallJumpCooldown = 0.1

@export var fallMultiplier = 0.4
@export var lowJumpMultiplier = 0.5

@onready var sprite = $Sprite2D
@onready var coyoteTimer = $Timers/CoyoteTimer
@onready var wallJumpTimer = $Timers/WallJumpTimer
@onready var groundDetector = $GroundDetector
@onready var wallDetectorRight = $WallDetectors/WallDetectorRight
@onready var wallDetectorLeft = $WallDetectors/WallDetectorLeft
@onready var bottomRightCast = $NudgeCasts/BottomRightCast
@onready var topRightCast = $NudgeCasts/TopRightCast
@onready var bottomLeftCast = $NudgeCasts/BottomLeftCast
@onready var topLeftCast = $NudgeCasts/TopLeftCast

var jumpBuffered = false
var jumpStartTime = 0.0
var facingDir = 1

var isTouchingWall = false
var isGrabbingWall = false
var isOnFloor = false
var wasOnFloor = false
var isOnWall = false
var isAttachedToWall = false

enum State { NORMAL, CLIMBING }
var state = State.NORMAL

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var checkpoint = Vector2.ZERO


func _ready():
	checkpoint = global_position

func _physics_process(delta):
	state = get_updated_state()
	
	match state:
		State.NORMAL:
			normal_state(delta)
		State.CLIMBING:
			climbing_state(delta)

func get_updated_state() -> State:
	if facingDir == 1:
		isOnWall = wallDetectorRight.has_overlapping_bodies()
	else:
		isOnWall = wallDetectorLeft.has_overlapping_bodies()
	
	if isOnWall and Input.is_action_pressed("climb"):
		return State.CLIMBING
	return State.NORMAL

func normal_state(delta):
	apply_gravity(delta)
	isOnFloor = is_on_floor() || groundDetector.has_overlapping_bodies()
	wasOnFloor = isOnFloor
	handle_jump_buffer()
	handle_jump()
	handle_movement(delta)
	update_sprite()
	
	extra_gravity(delta)
	nudge_onto_edge()
	move_and_slide()
	update_coyote_data()

func climbing_state(delta):
	attach_to_wall()
	handle_wall_jump()
	handle_wall_movement(delta)
	nudge_onto_edge()
	move_and_slide()

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

func handle_jump_buffer():
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

func handle_wall_jump():
	if Input.is_action_just_pressed("jump"):
		if wallJumpTimer.time_left == 0.0:
			wallJumpTimer.wait_time = wallJumpCooldown
			wallJumpTimer.start()
			jump()

func reset_jump_buffer():
	jumpBuffered = false

func update_sprite():
	if facingDir == 1:
		$Sprite2D.flip_h = false
	else:
		$Sprite2D.flip_h = true

func handle_movement(delta):
	var hor_dir = Input.get_axis("move_left", "move_right")
	if hor_dir:
		velocity.x = hor_dir * speed * delta
		facingDir = hor_dir
	else:
		# Slows down player, only relevant when additional forces are applied
		velocity.x = move_toward(velocity.x, 0, speed * delta)

func handle_wall_movement(delta):
	if wallJumpTimer.time_left > 0.0:
		return
	
	var ver_dir = Input.get_axis("move_up", "move_down")
	if ver_dir:
		velocity.y = ver_dir * speed * delta
	else:
		# Slows down player, only relevant when additional forces are applied
		velocity.y = move_toward(velocity.y, 0, speed * delta)

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

func attach_to_wall():
	isAttachedToWall = is_on_wall()
	if not isAttachedToWall:
		velocity.x = facingDir * 100
	else:
		velocity.x = 0
