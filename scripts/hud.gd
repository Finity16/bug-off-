extends CanvasLayer

var score_label: Label
var panel: Control
var final_label: Label
var best_label: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Game.reset()
	score_label = Label.new()
	score_label.position = Vector2(24, 16)
	score_label.add_theme_font_size_override("font_size", 36)
	add_child(score_label)
	Game.score_changed.connect(on_score_changed)
	Game.game_over.connect(show_game_over)
	on_score_changed(0)
	build_game_over()

func build_game_over():
	panel = Control.new()
	panel.visible = false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	box.add_child(make_label("GAME OVER", 72))
	final_label = make_label("", 40)
	box.add_child(final_label)
	best_label = make_label("", 28)
	box.add_child(best_label)
	box.add_child(make_button("Restart", on_restart))
	box.add_child(make_button("Main Menu", on_menu))

func make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label

func make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 56)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(callback)
	return button

func on_score_changed(value: int):
	score_label.text = "Score: %d" % value

func show_game_over():
	final_label.text = "Score: %d" % Game.score
	best_label.text = "Best: %d" % Game.best
	panel.visible = true
	get_tree().paused = true

func on_restart():
	get_tree().paused = false
	get_tree().reload_current_scene()

func on_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
