extends SceneTree
func _initialize():
 var image = Image.load_from_file("res://assets/workshop/wall_source.png")
 var low = Vector2i(image.get_width(), image.get_height())
 var high = Vector2i.ZERO
 for y in image.get_height():
  for x in image.get_width():
   if image.get_pixel(x,y).a > 0.25:
    low = low.min(Vector2i(x,y))
    high = high.max(Vector2i(x,y))
 print("used ", image.get_used_rect(), " opaque ", Rect2i(low, high-low+Vector2i.ONE))
 image.get_region(Rect2i(low, high-low+Vector2i.ONE)).save_png("res://assets/workshop/wall.png")
 quit()
