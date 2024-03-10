extends CharacterBody2D

@export var max_speed = 600
@export var jump_height : float = 10
@export var jump_time_to_peak : float = 0.5
@export var jump_time_to_descent : float = 0.4

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak) * -1.0
@onready var jump_gravity : float = ((-2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0
@onready var fall_gravity : float = ((-2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0

const acceleration = 400
const friction = 4


func _physics_process(delta):
	handle_movement(delta)
	apply_friction(delta)
	if is_on_floor():
		handle_jump()
	else:
		velocity.y += get_gravity() * delta

func handle_movement(delta):

	var input_vector : Vector2 = Vector2.ZERO                       # get input
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector = input_vector.normalized()

	if input_vector != Vector2.ZERO:
		velocity += input_vector * acceleration * delta   # apply acceleration

		if input_vector.x > 0:
			$Sprite2D.flip_h = false
		elif input_vector.x < 0:
			$Sprite2D.flip_h = true
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed  # cap the speed
	else:
		pass

	move_and_slide()

func apply_friction(delta):
	velocity.x = velocity.lerp(Vector2(0, 0), friction * delta).x  # apply friction


func get_gravity() -> float:
	if velocity.y < 0.0:
		return jump_gravity
	else:
		return fall_gravity


func handle_jump():
	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
