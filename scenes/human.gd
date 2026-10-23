extends CharacterBody2D

signal died(points: int)

enum State { CHASE, WINDUP, RECOVER, HURT }

@export var speed := 100.0
@export var health := 3
@export var attack_range := 120.0
@export var hit_range := 135.0
@export var windup_time := 0.4
@export var recover_time := 0.7
@export var attack_pause := 0.5

var state := State.CHASE
var player: Node2D
var can_attack := true

func _ready():
	add_to_group("humans")

func _physics_process(delta):
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	match state:
		State.CHASE:
			var to_player := player.global_position - global_position
			if can_attack and to_player.length() < attack_range:
				start_attack()
			else:
				velocity = to_player.normalized() * speed
		_:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()

func start_attack():
	state = State.WINDUP
	can_attack = false
	velocity = Vector2.ZERO
	modulate = Color.RED
	await get_tree().create_timer(windup_time).timeout
	if global_position.distance_to(player.global_position) < hit_range:
		player.take_hit(1, (player.global_position - global_position).normalized())
	modulate = Color.WHITE
	state = State.RECOVER
	await get_tree().create_timer(recover_time).timeout
	state = State.CHASE
	await get_tree().create_timer(attack_pause).timeout
	can_attack = true

func take_hit(dmg: int, from_dir: Vector2):
	health -= dmg
	velocity = from_dir * 200.0
	if health <= 0:
		died.emit(100)
		queue_free()
		return

	if state == State.CHASE:
		state = State.HURT
		await get_tree().create_timer(0.25).timeout
		if state == State.HURT:
			state = State.CHASE
