extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/editor.tscn").instantiate()
	root.add_child(app)
	var data = FlowLevel.read_file("res://flow_levels/001.json").level
	app.open_flow_editor(data)
	var editor = app.page.get_child(0)
	await create_timer(0.8).timeout
	assert(app.difficulty_service.worker == null and app.difficulty_service.pending.is_empty())
	assert(editor.difficulty_label.text == "难度未计算")
	editor.update_difficulty()
	for frame in 300:
		await process_frame
		if not editor.difficulty_result.is_empty(): break
	assert(not editor.difficulty_result.is_empty())
	assert(is_instance_valid(editor.result_overlay))
	assert(editor.data == data)
	var reconstructed = data.duplicate(true)
	reconstructed.rooms = editor.difficulty_result.rooms
	reconstructed.player = editor.difficulty_result.player
	assert(FlowLevel.validate(reconstructed).is_empty())
	var model = CampaignRun.new()
	model.start([reconstructed], 0, true)
	assert(is_equal_approx(model.simulate().rate, editor.difficulty_result.rate))
	await process_frame
	editor.result_overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../verification/best_layout_preview.png")
	editor.close_best_layout()
	editor.fields.balls.value += 100
	await create_timer(0.8).timeout
	assert(editor.difficulty_result.is_empty())
	assert(app.difficulty_service.worker == null and app.difficulty_service.pending.is_empty())
	print("MANUAL DIFFICULTY AND BEST LAYOUT PASSED")
	app.queue_free()
	await process_frame
	quit()
