extends Node2D

@export var sheet: Texture2D
@export var frame_width := 16
@export var count := 40
@export var decor_scale := 3.0
@export var margin := 24.0
@export var clear_radius := 120.0

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -10
	if sheet == null:
		return
	var columns := maxi(int(sheet.get_width() / frame_width), 1)
	var size := get_viewport().get_visible_rect().size
	var center := size / 2.0
	for i in count:
		var pos := Vector2.ZERO
		for attempt in 10:
			pos = Vector2(randf_range(margin, size.x - margin), randf_range(margin, size.y - margin))
			if pos.distance_to(center) >= clear_radius:
				break
		var s := Sprite2D.new()
		s.texture = sheet
		s.region_enabled = true
		s.region_rect = Rect2((randi() % columns) * frame_width, 0, frame_width, sheet.get_height())
		s.scale = Vector2.ONE * decor_scale
		s.flip_h = randf() < 0.5
		s.position = pos
		add_child(s)
