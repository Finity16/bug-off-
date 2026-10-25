class_name Human
extends CharacterBody2D

signal died(points: int)

enum State { CHASE, WINDUP, RECOVER, HURT }

@export var speed := 140.0
@export var health := 4.0
@export var attack_range := 170.0
@export var hit_range := 120.0
@export var attack_arc := 90.0
@export var windup_time := 0.5
@export var recover_time := 0.9
@export var attack_pause := 0.7
@export var close_distance := 80.0
@export var rush_multiplier := 3.0
@export var frame_width := 32
@export var walk_fps := 8.0
@export var pixel_size := 4.0
@export var death_fps := 10.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D

var state := State.CHASE
var player: Node2D
var can_attack := true
var dead := false
var aim_angle := 0.0
var windup_progress := 0.0
var telegraph: Polygon2D
var flash_material: ShaderMaterial
var cue_color := Color.html("f26b6b")
var hit_color := Color.html("e03a3a")
var entered := false

func _ready():
	collision_layer = 2
	collision_mask = 1
	var paths := get_sheet_paths()
	sprite.sprite_frames = build_frames(paths[randi() % paths.size()])
	sprite.play("walk")
	add_to_group("humans")
	telegraph = Polygon2D.new()
	var cells := int(ceil(get_telegraph_radius() / pixel_size)) * 2
	var extent := cells * pixel_size / 2.0
	telegraph.polygon = PackedVector2Array([Vector2(-extent, -extent), Vector2(extent, -extent), Vector2(extent, extent), Vector2(-extent, extent)])
	telegraph.uv = PackedVector2Array([Vector2(0, 0), Vector2(cells, 0), Vector2(cells, cells), Vector2(0, cells)])
	telegraph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	telegraph.color = Color(cue_color, 0.0)
	add_child(telegraph)
	draw_telegraph(0.0)
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
	keep_on_screen()

	if absf(player.global_position.x - global_position.x) > 4.0:
		sprite.flip_h = player.global_position.x < global_position.x
	if velocity.length() > 10.0:
		sprite.play("walk")
	else:
		sprite.play("idle")

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
	draw_telegraph(aim_angle)
	telegraph.color = Color(cue_color, 0.15)

func tick_windup(delta: float):
	var distance := player.global_position.distance_to(global_position)
	var closeness := clampf(inverse_lerp(attack_range, close_distance, distance), 0.0, 1.0)
	windup_progress += delta * lerpf(1.0, rush_multiplier, closeness)
	telegraph.color.a = lerpf(0.15, 0.45, minf(windup_progress / windup_time, 1.0))
	if windup_progress >= windup_time:
		land_attack()

func land_attack():
	state = State.RECOVER
	telegraph.color = Color(hit_color, 1.0)
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
	Game.add_score(10)
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
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.15).timeout
	queue_free()
	
func get_sheet_paths() -> PackedStringArray:
	return PackedStringArray(["res://art/Human1.png", "res://art/Human2.png"])

func build_frames(path: String) -> SpriteFrames:
	var sheet: Texture2D = load(path)
	var total := int(sheet.get_width() / frame_width)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("walk")
	frames.set_animation_speed("walk", walk_fps)
	frames.set_animation_loop("walk", true)
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", true)
	for i in maxi(total - 1, 1):
		frames.add_frame("walk", make_frame(sheet, i))
	frames.add_frame("idle", make_frame(sheet, total - 1))
	var death_path := path.replace(".png", "Death.png")
	if ResourceLoader.exists(death_path):
		var death_sheet: Texture2D = load(death_path)
		var death_total := int(death_sheet.get_width() / frame_width)
		frames.add_animation("death")
		frames.set_animation_speed("death", death_fps)
		frames.set_animation_loop("death", false)
		for i in maxi(death_total, 1):
			frames.add_frame("death", make_frame(death_sheet, i))
	return frames

func make_frame(sheet: Texture2D, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(index * frame_width, 0, frame_width, sheet.get_height())
	return atlas
	
func get_telegraph_radius() -> float:
	return hit_range

func in_telegraph(p: Vector2, angle: float) -> bool:
	if p.length() > hit_range:
		return false
	return absf(angle_difference(angle, p.angle())) <= deg_to_rad(attack_arc / 2.0)

func draw_telegraph(angle: float):
	var cells := int(ceil(get_telegraph_radius() / pixel_size)) * 2
	var half := cells / 2.0
	var img := Image.create(cells, cells, false, Image.FORMAT_RGBA8)
	for y in cells:
		for x in cells:
			var p := (Vector2(x + 0.5, y + 0.5) - Vector2(half, half)) * pixel_size
			if in_telegraph(p, angle):
				img.set_pixel(x, y, Color.WHITE)
	telegraph.texture = ImageTexture.create_from_image(img)

func keep_on_screen():
	var size := get_viewport().get_visible_rect().size
	var rect := Rect2(Vector2.ZERO, size).grow(-get_body_radius())
	if not entered:
		entered = rect.has_point(global_position)
		return
	global_position = global_position.clamp(rect.position, rect.end)
