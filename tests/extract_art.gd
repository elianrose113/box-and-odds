extends SceneTree
func _initialize():
 var base = "res://assets/workshop/"
 var tiles = Image.load_from_file(base + "tiles_atlas.png")
 var regions = {"wall": Rect2i(77,80,388,390), "crate": Rect2i(582,80,378,391), "floor": Rect2i(1076,82,381,376), "entrance": Rect2i(93,581,353,342), "exit": Rect2i(590,582,365,343), "wood": Rect2i(1078,567,380,362)}
 for name in regions: tiles.get_region(regions[name]).save_png(base + name + ".png")
 var ui = Image.load_from_file(base + "ui_atlas.png")
 for pair in [["paper", Rect2i(91,9,1800,250)], ["button_red", Rect2i(72,281,1838,227)], ["frame",Rect2i(33,522,1915,259)]]:
  ui.get_region(pair[1]).save_png(base + pair[0] + ".png")
 var worker = Image.load_from_file(base + "worker_atlas.png")
 for row in 4:
  for column in 4:
   var region = Rect2i(column * worker.get_width() / 4, row * worker.get_height() / 4, worker.get_width() / 4, worker.get_height() / 4)
   var cell = worker.get_region(region)
   var used = cell.get_used_rect()
   cell.get_region(used).save_png(base + "worker_%d_%d.png" % [row, column])
 print("ATLAS EXTRACTION COMPLETE")
 quit()
