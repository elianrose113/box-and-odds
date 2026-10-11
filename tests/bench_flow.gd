extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var app = load("res://scenes/main.tscn").instantiate()
 app.progression_enabled = false
 root.add_child(app)
 app.start_flow_campaign(FlowLevel.catalog().levels, 2)
 await process_frame
 var game = app.page.get_child(0)
 game.batch_amount = game.maximum_batch()
 game.start_run()
 var times: Array[float] = []
 var previous = Time.get_ticks_usec()
 for frame in 240:
  await process_frame
  var now = Time.get_ticks_usec()
  if frame > 20: times.append((now - previous) / 1000.0)
  previous = now
 times.sort()
 print("FRAME median_ms=", times[times.size()/2], " p95_ms=", times[int(times.size()*0.95)])
 app.queue_free()
 await process_frame
 quit()
