extends SceneTree
func _initialize():
 for name in ["tiles_atlas", "worker_atlas", "ui_atlas"]:
  var image = Image.load_from_file("res://assets/workshop/" + name + ".png")
  print(name, " size=", image.get_size(), " alpha=", image.detect_alpha(), " corner=", image.get_pixel(0,0))
 quit()
