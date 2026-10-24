extends Human

@export var circle_radius := 125.0
@export var first_windup := 0.5
@export var second_windup := 0.3
@export var gap_time := 0.1
@export var spin_recover := 0.3

var fill_tween: Tween
func get_sheet_paths() -> PackedStringArray:
	return PackedStringArray(["res://art/SpinnerHuman.png"])
	
func get_telegraph_shape() -> PackedVector2Array:
	return make_circle(circle_radius)

func make_circle(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 48
	for i in steps:
		var a := TAU * i / steps
		points.append(Vector2.from_angle(a) * radius)
	return points

func player_in_attack_area() -> bool:
	var distance := player.global_position.distance_to(global_position)
	return distance - player.get_body_radius() <= circle_radius

func tick_windup(_delta: float):
	pass

func start_attack():
	state = State.WINDUP
	can_attack = false
	velocity = Vector2.ZERO
	await spin(first_windup)
	if dead:
		return
	await get_tree().create_timer(gap_time).timeout
	if dead:
		return
	await spin(second_windup)
	if dead:
		return
	state = State.RECOVER
	await get_tree().create_timer(spin_recover).timeout
	if dead:
		return
	state = State.CHASE
	await get_tree().create_timer(attack_pause).timeout
	can_attack = true

func spin(duration: float):
	telegraph.color = Color(1, 0, 0, 0.15)
	fill_tween = create_tween()
	fill_tween.tween_property(telegraph, "color:a", 0.45, duration)
	await get_tree().create_timer(duration).timeout
	if dead:
		return
	fill_tween.kill()
	telegraph.color = Color(1, 0, 0, 1)
	if player_in_attack_area():
		player.take_hit(1, (player.global_position - global_position).normalized())
	var fade := create_tween()
	fade.tween_property(telegraph, "color:a", 0.0, 0.15)

func die():
	if fill_tween:
		fill_tween.kill()
	super()
