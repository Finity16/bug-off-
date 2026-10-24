extends Human

@export var kite_distance := 300.0
@export var kite_margin := 40.0
@export var retreat_speed := 200.0
@export var lunge_speed := 220.0
@export var strafe_speed := 90.0
@export var patience := 1.2

var strafe_sign := 1.0
var waiting_time := 0.0

func _ready():
	super()
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	
func get_sheet_paths() -> PackedStringArray:
	return PackedStringArray(["res://art/SmartHuman.png"])

func chase(delta: float):
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var toward := to_player.normalized()
	var away := -toward
	var side := toward.rotated(PI / 2.0) * strafe_sign

	if not can_attack:
		waiting_time = 0.0
		if distance < kite_distance:
			velocity = away * retreat_speed
		else:
			velocity = side * strafe_speed
		return

	waiting_time += delta
	var opening: bool = not player.can_attack or waiting_time >= patience
	if opening:
		if distance < attack_range:
			start_attack()
		else:
			velocity = toward * lunge_speed
		return

	if distance < kite_distance - kite_margin:
		velocity = away * retreat_speed
	elif distance > kite_distance + kite_margin:
		velocity = toward * speed
	else:
		velocity = side * strafe_speed
