extends SceneTree
func _initialize():
 for spec in [["paper",512,96],["button_red",512,96],["frame",512,128]]:
  var path = "res://assets/workshop/" + spec[0] + ".png"
  var image = Image.load_from_file(path)
  image.resize(spec[1], spec[2], Image.INTERPOLATE_LANCZOS)
  image.save_png(path)
 quit()
