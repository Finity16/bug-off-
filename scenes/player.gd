extends CharacterBody2D

@export var speed := 220.0
@export var accel := 1400.0
@export var friction := 1000.0
@export var attack_cooldown := 0.35

@onready var pivot: Node2D = $Pivot
@onready var hit_area: Area2D = $Pivot/HitArea

var facing := Vector2.RIGHT
var can_attack := true

func _ready():
	add_to_group("player")

func _physics_process(delta):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	facing = (get_global_mouse_position() - global_position).normalized()
	pivot.rotation = facing.angle()

	if Input.is_action_just_pressed("attack") and can_attack:
		attack()

func attack():
	can_attack = false
	velocity += facing * 250.0
	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("humans"):
			body.take_hit(1, facing)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_hit(_dmg: int, from_dir: Vector2):
	velocity = from_dir * 300.0
