extends Node

@export var human_scene: PackedScene
@export var spinner_scene: PackedScene
@export var smart_scene: PackedScene
@export var max_enemies := 10
@export var max_alive_at_once := 4
@export var difficulty_cap := 8
@export var spinner_unlock_wave := 2
@export var smart_unlock_wave := 4
@export var spinner_guaranteed_wave := 3
@export var smart_guaranteed_wave := 5
@export var wave_delay := 1.5
@export var spawn_interval_min := 2.5
@export var spawn_interval_max := 4.5
@export var spawn_margin := 60.0
@export var min_player_distance := 300.0
@export var speed_per_level := 0.03
@export var health_per_level := 0.25

var wave := 0
var alive := 0
var spawning_done := false

func get_sheet_paths() -> PackedStringArray:
	return PackedStringArray(["res://art/SmartHuman.png"])
	
func _ready():
	start_wave.call_deferred()

func start_wave():
	wave += 1
	var level := mini(1 + int(wave * 0.5), difficulty_cap)
	var count := mini(1 + int(wave * 0.6), max_enemies)
	print("wave ", wave, " enemies ", count, " level ", level)
	spawning_done = false
	run_wave(count, level)

func build_queue(count: int) -> Array[PackedScene]:
	var queue: Array[PackedScene] = []
	if wave == spinner_guaranteed_wave:
		queue.append(spinner_scene)
	if wave == smart_guaranteed_wave:
		queue.append(smart_scene)
	while queue.size() < count:
		queue.append(pick_scene())
	queue.shuffle()
	return queue

func run_wave(count: int, level: int):
	var queue := build_queue(count)
	for i in queue.size():
		while alive >= max_alive_at_once:
			if not is_inside_tree():
				return
			await get_tree().process_frame
			if not is_inside_tree():
				return
		if not is_inside_tree():
			return
		spawn_enemy(queue[i], level)
		alive += 1
		if i < queue.size() - 1:
			var wait := randf_range(spawn_interval_min, spawn_interval_max)
			while wait > 0.0 and alive > 0:
				await get_tree().process_frame
				if not is_inside_tree():
					return
				wait -= get_process_delta_time()
	spawning_done = true

func pick_scene() -> PackedScene:
	var spinner_weight := 0.0
	if wave >= spinner_unlock_wave:
		spinner_weight = clampf(2.0 + (wave - spinner_unlock_wave) * 1.5, 0.0, 10.0)
	var smart_weight := 0.0
	if wave >= smart_unlock_wave:
		smart_weight = clampf(2.0 + (wave - smart_unlock_wave) * 1.5, 0.0, 10.0)
	var roll := randf() * (10.0 + spinner_weight + smart_weight)
	roll -= 10.0
	if roll <= 0.0:
		return human_scene
	roll -= spinner_weight
	if roll <= 0.0:
		return spinner_scene
	return smart_scene

func spawn_enemy(scene: PackedScene, level: int):
	var enemy: Human = scene.instantiate()
	enemy.speed *= 1.0 + speed_per_level * (level - 1)
	enemy.health += health_per_level * (level - 1)
	enemy.position = pick_spawn_position()
	enemy.died.connect(on_enemy_died)
	get_parent().add_child(enemy)

func pick_spawn_position() -> Vector2:
	var size := get_viewport().get_visible_rect().size
	var player := get_tree().get_first_node_in_group("player")
	var pos := Vector2.ZERO
	for attempt in 10:
		match randi() % 4:
			0:
				pos = Vector2(randf_range(0.0, size.x), -spawn_margin)
			1:
				pos = Vector2(randf_range(0.0, size.x), size.y + spawn_margin)
			2:
				pos = Vector2(-spawn_margin, randf_range(0.0, size.y))
			_:
				pos = Vector2(size.x + spawn_margin, randf_range(0.0, size.y))
		if player == null or pos.distance_to(player.global_position) >= min_player_distance:
			break
	return pos

func on_enemy_died(points: int):
	Game.add_score(points)
	alive -= 1
	if alive <= 0 and spawning_done:
		await get_tree().create_timer(wave_delay).timeout
		if not is_inside_tree():
			return
		start_wave()
