extends SceneTree
func crop_alpha(source: Image) -> Image:
	var bounds = Rect2i()
	var found = false
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x,y).a > 0.25:
				if not found: bounds = Rect2i(x,y,1,1); found = true
				else: bounds = bounds.merge(Rect2i(x,y,1,1))
	return source.get_region(bounds)
func _initialize() -> void:
	var root_path = 'res://assets/workshop/'
	var walk = Image.load_from_file(root_path + 'worker_atlas.png')
	for row in 4:
		for col in 4:
			var frame = walk.get_region(Rect2i(col * walk.get_width() / 4, row * walk.get_height() / 4, walk.get_width() / 4, walk.get_height() / 4))
			crop_alpha(frame).save_png(root_path + 'worker_%d_%d.png' % [row,col])
	var idle = Image.load_from_file(root_path + 'worker_idle_atlas.png')
	for i in 4:
		var frame = idle.get_region(Rect2i((i % 2) * idle.get_width() / 2, (i / 2) * idle.get_height() / 2, idle.get_width() / 2, idle.get_height() / 2))
		crop_alpha(frame).save_png(root_path + 'worker_idle_%d.png' % i)
	print(ThemeDB.get_default_theme().get_icon_list('SpinBox'))
	quit()
