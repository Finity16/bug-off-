extends Control

func _ready():
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.html("6ea16e")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	box.add_child(make_label("BUG OFF!", 96))
	if Game.best > 0:
		box.add_child(make_label("Best: %d" % Game.best, 28))
	var play := Button.new()
	play.text = "Play"
	play.custom_minimum_size = Vector2(260, 64)
	play.add_theme_font_size_override("font_size", 32)
	play.pressed.connect(on_play)
	box.add_child(play)
	play.grab_focus()

func make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label

func on_play():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
