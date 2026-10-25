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
@export var death_fps := 10.0
@export var pixel_size := 4.0
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
	wedge = Polygon2D.new()
	var cells := int(ceil(attack_radius / pixel_size)) * 2
	var extent := cells * pixel_size / 2.0
	wedge.polygon = PackedVector2Array([Vector2(-extent, -extent), Vector2(extent, -extent), Vector2(extent, extent), Vector2(-extent, extent)])
	wedge.uv = PackedVector2Array([Vector2(0, 0), Vector2(cells, 0), Vector2(cells, cells), Vector2(0, cells)])
	wedge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wedge.color = Color(1, 1, 1, 0)
	add_child(wedge)
	sprite.sprite_frames = build_frames("res://art/Bug.png")
	sprite.play("fly")

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
		keep_on_screen()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	keep_on_screen()

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

func draw_wedge(angle: float):
	var cells := int(ceil(attack_radius / pixel_size)) * 2
	var half := cells / 2.0
	var img := Image.create(cells, cells, false, Image.FORMAT_RGBA8)
	for y in cells:
		for x in cells:
			var p := (Vector2(x + 0.5, y + 0.5) - Vector2(half, half)) * pixel_size
			if p.length() <= attack_radius and absf(angle_difference(angle, p.angle())) <= deg_to_rad(attack_arc / 2.0):
				img.set_pixel(x, y, Color.WHITE)
	wedge.texture = ImageTexture.create_from_image(img)

func flash_wedge():
	draw_wedge(facing.angle())
	wedge.color = Color(1, 1, 1, 0.9)
	var tween := create_tween()
	tween.tween_property(wedge, "color:a", 0.0, 0.15)

func take_hit(_dmg: int, _from_dir: Vector2):
	if dead:
		return
	dead = true
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	await get_tree().create_timer(0.3).timeout
	Game.game_over.emit()
	
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
	var death_path := path.replace(".png", "Death.png")
	if ResourceLoader.exists(death_path):
		var death_sheet: Texture2D = load(death_path)
		var death_total: int = int(death_sheet.get_width() / frame_width)
		frames.add_animation("death")
		frames.set_animation_speed("death", death_fps)
		frames.set_animation_loop("death", false)
		for i in maxi(death_total, 1):
			var atlas := AtlasTexture.new()
			atlas.atlas = death_sheet
			atlas.region = Rect2(i * frame_width, 0, frame_width, death_sheet.get_height())
			frames.add_frame("death", atlas)
	return frames
	
func keep_on_screen():
	var size := get_viewport().get_visible_rect().size
	var r := get_body_radius()
	global_position = global_position.clamp(Vector2(r, r), size - Vector2(r, r))
