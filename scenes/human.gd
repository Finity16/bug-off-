class_name Human
extends CharacterBody2D

signal died(points: int)

enum State { CHASE, WINDUP, RECOVER, HURT }

@export var speed := 120.0
@export var health := 4.0
@export var attack_range := 170.0
@export var hit_range := 120.0
@export var attack_arc := 90.0
@export var windup_time := 0.5
@export var recover_time := 0.9
@export var attack_pause := 0.7
@export var close_distance := 80.0
@export var rush_multiplier := 3.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var state := State.CHASE
var player: Node2D
var can_attack := true
var dead := false
var aim_angle := 0.0
var windup_progress := 0.0
var telegraph: Polygon2D
var flash_material: ShaderMaterial

func _ready():
	collision_layer = 2
	collision_mask = 1
	add_to_group("humans")
	telegraph = Polygon2D.new()
	telegraph.polygon = get_telegraph_shape()
	telegraph.color = Color(1, 0, 0, 0)
	add_child(telegraph)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
"""
	flash_material = ShaderMaterial.new()
	flash_material.shader = shader
	sprite.material = flash_material

func get_telegraph_shape() -> PackedVector2Array:
	return make_wedge(hit_range, attack_arc)

func make_wedge(radius: float, arc_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(arc_degrees / 2.0)
	var steps := 16
	for i in steps + 1:
		var a := -half + (half * 2.0) * i / steps
		points.append(Vector2.from_angle(a) * radius)
	return points

func get_body_radius() -> float:
	var circle := body_shape.shape as CircleShape2D
	if circle == null:
		return 16.0
	return circle.radius * body_shape.global_scale.x

func _physics_process(delta):
	if dead:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	match state:
		State.CHASE:
			chase(delta)
		State.WINDUP:
			tick_windup(delta)
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		_:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()

func chase(_delta: float):
	var to_player := player.global_position - global_position
	if can_attack and to_player.length() < attack_range:
		start_attack()
	else:
		velocity = to_player.normalized() * speed

func player_in_attack_area() -> bool:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var radius: float = player.get_body_radius()
	if distance - radius > hit_range:
		return false
	if distance <= radius:
		return true
	var tolerance := asin(minf(radius / distance, 1.0))
	var limit := deg_to_rad(attack_arc / 2.0) + tolerance
	return absf(angle_difference(aim_angle, to_player.angle())) <= limit

func start_attack():
	state = State.WINDUP
	can_attack = false
	windup_progress = 0.0
	velocity = Vector2.ZERO
	aim_angle = (player.global_position - global_position).angle()
	telegraph.rotation = aim_angle
	telegraph.color = Color(1, 0, 0, 0.15)

func tick_windup(delta: float):
	var distance := player.global_position.distance_to(global_position)
	var closeness := clampf(inverse_lerp(attack_range, close_distance, distance), 0.0, 1.0)
	windup_progress += delta * lerpf(1.0, rush_multiplier, closeness)
	telegraph.color.a = lerpf(0.15, 0.45, minf(windup_progress / windup_time, 1.0))
	if windup_progress >= windup_time:
		land_attack()

func land_attack():
	state = State.RECOVER
	telegraph.color = Color(1, 0, 0, 1)
	if player_in_attack_area():
		player.take_hit(1, Vector2.from_angle(aim_angle))
	var tween := create_tween()
	tween.tween_property(telegraph, "color:a", 0.0, 0.2)
	await get_tree().create_timer(recover_time).timeout
	state = State.CHASE
	await get_tree().create_timer(attack_pause).timeout
	can_attack = true

func flash_white():
	set_flash(1.0)
	var tween := create_tween()
	tween.tween_method(set_flash, 1.0, 0.0, 0.15)

func set_flash(value: float):
	flash_material.set_shader_parameter("flash", value)

func take_hit(dmg: int, from_dir: Vector2):
	if dead:
		return
	health -= dmg
	if state != State.WINDUP:
		velocity = from_dir * 200.0
	flash_white()
	if health <= 0:
		die()
		return

	if state == State.CHASE:
		state = State.HURT
		await get_tree().create_timer(0.25).timeout
		if state == State.HURT:
			state = State.CHASE

func die():
	dead = true
	remove_from_group("humans")
	body_shape.set_deferred("disabled", true)
	telegraph.color.a = 0.0
	died.emit(100)
	await get_tree().create_timer(0.15).timeout
	queue_free()
