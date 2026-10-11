extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 800)
	var app = load("res://scenes/main.tscn").instantiate()
	app.progression_enabled = false
	root.add_child(app)
	var data = FlowLevel.read_file("res://flow_levels/001.json").level
	app.start_flow_campaign([data])
	await process_frame
	var game = app.page.get_child(0)
	game.collection_tube.set_progress(data.target - 1, data.balls, data.target)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../verification/collection_red.png")
	game.collection_tube.set_progress(data.target, data.balls, data.target)
	await create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../verification/collection_celebration.png")
	app.queue_free()
	await process_frame
	quit()
