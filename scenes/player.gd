extends CharacterBody2D

@export var speed := 300.0
@export var accel := 1400.0
@export var friction := 1000.0
@export var attack_cooldown := 0.6
@export var attack_stun := 0.2
@export var attack_radius := 110.0
@export var attack_arc := 90.0
@export var frame_width := 32
@export var fly_fps := 12.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pivot: Node2D = $Pivot
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var facing := Vector2.RIGHT
var can_attack := true
var stunned := false
var dead := false
var wedge: Polygon2D

func _ready():
	collision_mask = 3
	add_to_group("player")
	add_to_group("player")
	wedge = Polygon2D.new()
	wedge.polygon = make_wedge(attack_radius, attack_arc)
	wedge.color = Color(1, 1, 1, 0)
	pivot.add_child(wedge)
	sprite.sprite_frames = build_frames("res://art/Bug.png")
	sprite.play("fly")

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
		return

	if stunned:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	facing = (get_global_mouse_position() - global_position).normalized()
	pivot.rotation = facing.angle()
	sprite.flip_h = facing.x < 0

	if Input.is_action_just_pressed("attack") and can_attack:
		attack()

func wedge_hits(human: Node2D) -> bool:
	var to_human := human.global_position - global_position
	var distance := to_human.length()
	var radius: float = human.get_body_radius()
	if distance - radius > attack_radius:
		return false
	if distance <= radius:
		return true
	var tolerance := asin(minf(radius / distance, 1.0))
	var limit := deg_to_rad(attack_arc / 2.0) + tolerance
	return absf(angle_difference(facing.angle(), to_human.angle())) <= limit

func attack():
	can_attack = false
	stunned = true
	velocity = Vector2.ZERO
	flash_wedge()
	for human in get_tree().get_nodes_in_group("humans"):
		if wedge_hits(human):
			human.take_hit(1, facing)
	await get_tree().create_timer(attack_stun).timeout
	stunned = false
	await get_tree().create_timer(maxf(attack_cooldown - attack_stun, 0.0)).timeout
	can_attack = true

func flash_wedge():
	wedge.color = Color(1, 1, 1, 0.9)
	var tween := create_tween()
	tween.tween_property(wedge, "color:a", 0.0, 0.15)

func take_hit(_dmg: int, _from_dir: Vector2):
	if dead:
		return
	dead = true
	print("squashed!")
	await get_tree().create_timer(0.6).timeout
	get_tree().reload_current_scene()
	
func build_frames(path: String) -> SpriteFrames:
	var sheet: Texture2D = load(path)
	var total := int(sheet.get_width() / frame_width)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	frames.set_animation_speed("fly", fly_fps)
	frames.set_animation_loop("fly", true)
	for i in maxi(total, 1):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_width, 0, frame_width, sheet.get_height())
		frames.add_frame("fly", atlas)
	return frames
