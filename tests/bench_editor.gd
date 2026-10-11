extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://scenes/editor.tscn").instantiate()
	root.add_child(app)
	var data = FlowLevel.read_file("res://flow_levels/001.json").level
	app.open_flow_editor(data)
	await process_frame
	var editor = app.page.get_child(0)
	var draws = [0]
	editor.view.draw.connect(func(): draws[0] += 1)
	var intervals: Array[float] = []
	var last = Time.get_ticks_usec()
	for frame in 120:
		await process_frame
		var now = Time.get_ticks_usec()
		if frame > 10: intervals.append((now - last) / 1000.0)
		last = now
	intervals.sort()
	print("EDITOR p95_ms=", intervals[int(intervals.size()*0.95)], " max_ms=", intervals[-1], " static_board_draws=", draws[0], " difficulty=", editor.difficulty_label.text)
	assert(draws[0] < 8)
	assert(editor.difficulty_label.text == "难度未计算")
	assert(app.difficulty_service.worker == null)
	app.queue_free()
	await process_frame
	quit()
