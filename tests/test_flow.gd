extends SceneTree
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func fresh(data: Dictionary) -> CampaignRun:
	var model = CampaignRun.new()
	model.start([data])
	return model

func run() -> void:
	var tube = CollectionTube.new()
	tube.set_progress(500, 1000, 600)
	check(is_equal_approx(tube.fill_ratio(), 0.5) and is_equal_approx(tube.target_ratio(), 0.6) and not tube.reached(), "tube uses one fixed scale")
	tube.set_progress(700, 1000, 600)
	check(tube.reached(), "tube crosses target")
	check(tube.current_count_color() == Color.BLACK and tube.celebration_time == 0, "goal crossing turns count black and celebrates")
	tube._process(0.3)
	tube.set_progress(701, 1000, 600)
	check(is_equal_approx(tube.celebration_time, 0.3), "extra arrivals do not restart celebration")
	tube._process(2.0)
	check(tube.celebration_time < 0, "celebration expires")
	tube.set_progress(0, 1000, 600)
	check(tube.current_count_color() == WorkshopArt.RED and not tube.celebrated, "restart restores red count and rearms celebration")
	tube.set_progress(0, 1000, 0)
	check(tube.reached() and tube.fill_ratio() == 0, "zero target and reset")
	tube.free()
	var catalog = FlowLevel.catalog()
	if not catalog.errors.is_empty(): print(catalog.errors)
	check(catalog.errors.is_empty() and catalog.levels.size() >= 3, "probability catalog")
	if catalog.levels.is_empty(): quit(1); return
	catalog.levels = []
	for file in ["001.json", "002.json", "003.json"]:
		catalog.levels.append(FlowLevel.read_file("res://flow_levels/" + file).level)
	var data: Dictionary = catalog.levels[0]
	var model = fresh(data)
	var kernel = model.kernel()
	for row in kernel:
		var total = 0.0
		for p in row.values():
			check(p >= 0, "nonnegative transitions")
			total += p
		check(absf(total - 1) < 0.00000001, "normalized transitions")
	var entry = model.index_of(model.entrance)
	var exit_index = model.index_of(model.exit_cell)
	check(is_equal_approx(kernel[entry][entry], 0.5), "blocked directions stay")
	check(kernel[exit_index] == {exit_index: 1.0}, "absorbing exit")
	var simulation = model.simulate()
	var previous = 0.0
	for frame in simulation.frames:
		var total = 0.0
		for mass in frame: total += mass
		check(absf(total - 1) < 0.00000001, "conserve probability mass")
		check(frame[exit_index] >= previous - 0.000000001, "monotonic arrivals")
		previous = frame[exit_index]
	check(model.simulate(0).rate == 0, "zero steps")
	check(model.simulate(8).rate == 0, "minimum travel distance")
	model.exit_cell = Vector2i(2, 1)
	check(is_equal_approx(model.simulate(1).rate, 0.25), "analytic one-step probability")
	check(is_equal_approx(model.simulate(2).rate, 0.375), "analytic two-step probability")
	model = fresh(data)
	model.generate_balls(12345)
	check(model.ball_paths.size() == model.balls, "one path per ball")
	var valid_paths = true
	var actual_count = 0
	var saved_paths = model.ball_paths.duplicate(true)
	for path in model.ball_paths:
		if path.size() != model.horizon + 1 or path[0] != entry: valid_paths = false
		for step in model.horizon:
			if not kernel[path[step]].has(path[step + 1]): valid_paths = false
		if path[-1] == exit_index: actual_count += 1
	check(valid_paths, "all real ball transitions obey the kernel and time budget")
	check(actual_count == roundi(simulation.expected), "arrivals equal rounded Markov expectation")
	check(actual_count == model.actual_arrivals and model.arrival_order.size() == actual_count, "arrival identity conservation")
	model.generate_balls(12345)
	check(saved_paths == model.ball_paths, "seed reproduces simulation")
	model.generate_balls(54321)
	check(model.actual_arrivals == actual_count, "changing animation seed cannot change outcome")
	var initial = model.simulate().expected
	var field_view = FlowView.new()
	field_view.configure_run(model)
	field_view.set_report(model.simulate())
	var before_field = field_view.preparation_field.duplicate()
	check(Array(before_field).max() > 0 and before_field[exit_index] == 0, "preparation field present without exit score")
	check(model.move(Vector2i.LEFT).ok and model.move(Vector2i.UP).ok, "walk to box")
	check(model.move(Vector2i.UP).pushed and model.pushes_left == data.budget - 1, "push budget")
	check(model.simulate().expected > initial and model.simulate().expected >= model.target(), "placement improves outcome")
	field_view.set_report(model.simulate())
	check(field_view.preparation_field != before_field, "pushing updates preparation field")
	field_view.free()
	check(model.undo() and model.rooms.has(Vector2i(2, 2)) and model.pushes_left == data.budget, "undo restore")
	model.pushes_left = 0
	check(not model.move(Vector2i.UP).ok, "no pushing without budget")
	check(model.move(Vector2i.DOWN).ok, "walking remains free")
	model = fresh(data)
	model.player = Vector2i(1, 2)
	model.rooms = {Vector2i(2, 2): "east", Vector2i(3, 2): "east"}
	check(not model.move(Vector2i.RIGHT).ok, "two boxes block")
	model.player = Vector2i(4, 5)
	model.rooms = {Vector2i(5, 5): "east"}
	check(not model.move(Vector2i.RIGHT).ok, "exit cannot be occupied by box")
	model = fresh(data)
	model.begin_run()
	check(not model.move(Vector2i.LEFT).ok and not model.undo(), "running locks board")
	var result = model.settle({"expected": 999999})
	check(result.arrived == model.actual_arrivals and result.arrived <= model.balls, "actual settlement authoritative")
	check(model.settle({}).is_empty(), "single settlement")
	if not result.passed: check(model.retry_level() and model.phase == "prepare", "failed level retry")
	var pass_data = data.duplicate(true)
	pass_data.target = 0
	model.start([pass_data, catalog.levels[1]])
	model.begin_run()
	model.settle({})
	check(model.continue_campaign() and model.level_index == 1, "level progression")
	check(model.width == catalog.levels[1].width and model.balls == catalog.levels[1].balls, "new map and parameters")
	test_art_projection()
	test_batches(data)
	test_tube_shape()
	test_format(data)
	await test_editor_and_ui(catalog.levels)
	print("FLOW CHECKS: %d FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_art_projection() -> void:
	var reference_size = -1.0
	for dimensions in [Vector2i(4,4), Vector2i(4,8), Vector2i(10,4), Vector2i(10,8)]:
		var definition = FlowLevel.blank()
		definition.width = dimensions.x
		definition.height = dimensions.y
		definition.walls = []
		definition.rooms = []
		definition.entrance = [1,1]
		definition.exit = [dimensions.x - 2, dimensions.y - 2]
		definition.player = [1, dimensions.y - 2]
		var view = FlowView.new()
		view.size = Vector2(650, 500)
		view.configure_run(fresh(definition))
		view.layout_board()
		if reference_size < 0:
			reference_size = view.cell_size
		check(view.cell_size == reference_size, "map resize preserves fixed 10x8 scale")
		var board_center = view.origin + Vector2(dimensions.x * view.cell_size, dimensions.y * view.cell_size * 0.78) * 0.5
		check(board_center.is_equal_approx(view.size * 0.5 + Vector2(0, view.cell_size * 0.08)), "smaller boards stay centered")
		var correct = true
		for y in dimensions.y:
			for x in dimensions.x:
				if view.cell_at(view.center(Vector2(x,y))) != Vector2i(x,y): correct = false
		check(correct, "2.5D editor hit testing " + str(dimensions))
		view.free()
	var all_frames = true
	for row in 4:
		for frame in 4:
			var texture = WorkshopArt.texture("worker_%d_%d" % [row,frame])
			if texture == null or texture.get_width() <= 0: all_frames = false
	for row in 4:
		if WorkshopArt.texture("worker_idle_%d" % row) == null: all_frames = false
	check(all_frames, "all four-direction walking and pushing frames imported")

func test_batches(data: Dictionary) -> void:
	var source = data.duplicate(true)
	source.target = source.balls
	var model = fresh(source)
	check(model.begin_run(99).is_empty() and model.remaining_balls == model.balls, "reject small batch without spending")
	check(model.begin_run(model.balls + 1).is_empty(), "reject overspending")
	model.move(Vector2i.LEFT)
	model.move(Vector2i.UP)
	model.move(Vector2i.UP)
	var budget = model.pushes_left
	var layout = model.rooms.duplicate()
	model.begin_run(100)
	check(model.remaining_balls == model.balls - 100 and model.ball_paths.size() == 100, "batch spends exactly requested balls")
	var first = model.actual_arrivals
	model.settle({})
	check(model.phase == "between" and model.collected_total == first, "batch counts retained")
	check(model.settle({}).is_empty(), "batch cannot settle twice")
	check(model.continue_batch() and model.rooms == layout and model.pushes_left == budget, "batch retains layout and push budget")
	check(not model.undo(), "undo cannot cross spent batch")
	model.begin_run(100)
	var second = model.actual_arrivals
	model.settle({})
	check(model.collected_total == first + second and model.remaining_balls == model.balls - 200, "cumulative batch accounting")
	model.continue_batch()
	model.reset_preparation()
	check(model.collected_total == 0 and model.remaining_balls == model.balls and model.pushes_left == model.base_budget, "restart clears the entire attempt")
	source.balls = 250
	source.target = 250
	source.horizon = 1
	model = fresh(source)
	for batch in [100, 100]:
		model.begin_run(batch)
		model.settle({})
		model.continue_batch()
	check(model.begin_run(49).is_empty(), "short remainder must be released together")
	check(not model.begin_run(50).is_empty() and model.ball_paths.size() == 50, "last batch may contain fewer than 100")
	model.settle({})
	check(model.phase == "result" and model.remaining_balls == 0 and not model.last_result.passed, "exhausted pool ends the attempt")

func test_tube_shape() -> void:
	var tube = CollectionTube.new()
	tube.size = Vector2(205, 578)
	tube.set_progress(1000, 1000, 260)
	var radius = tube.ball_radius()
	var area = tube.inner_rect()
	var curve_radius = area.size.x * 0.5
	var curve_center = Vector2(area.get_center().x, area.end.y - curve_radius)
	var contained = tube.slots.size() == 1000
	for position in tube.slots:
		if not tube.contains_ball(position, radius): contained = false
	check(contained, "every collected ball fits the curved tube")
	check(tube.slots[0].y > curve_center.y and absf(tube.slots[0].x - curve_center.x) < 0.1, "packing starts at the curved bottom center")
	tube.free()

func test_format(data: Dictionary) -> void:
	var oversized = data.duplicate(true)
	oversized.width = 11
	check(not FlowLevel.validate(oversized).is_empty(), "reject width above 10")
	oversized.width = 10
	oversized.height = 9
	check(not FlowLevel.validate(oversized).is_empty(), "reject height above 8")
	check(FlowLevel.validate(data).is_empty(), "valid level")
	var bad = data.duplicate(true)
	bad.room_defs.east.p = [0.2, 0.2, 0.2, 0.2]
	check(not FlowLevel.validate(bad).is_empty(), "probabilities must sum to one")
	bad = data.duplicate(true)
	bad.room_defs.east.p[0] = "invalid"
	check(not FlowLevel.validate(bad).is_empty(), "invalid probability type")
	bad = data.duplicate(true)
	bad.rooms.append(bad.rooms[0].duplicate(true))
	check(not FlowLevel.validate(bad).is_empty(), "overlap rejected")
	bad = data.duplicate(true)
	bad.entrance = [99, 99]
	check(not FlowLevel.validate(bad).is_empty(), "invalid entry rejected")
	bad = data.duplicate(true)
	bad.target = bad.balls + 1
	check(not FlowLevel.validate(bad).is_empty(), "impossible count rejected")
	bad = data.duplicate(true)
	bad.room_defs = {}
	check(not FlowLevel.validate(bad).is_empty(), "empty template collection rejected")
	bad = data.duplicate(true)
	bad.walls.append([2, 1])
	bad.walls.append([1, 2])
	check(not FlowLevel.validate(bad).is_empty(), "disconnected endpoint rejected")
	var path = "user://flow_qa_" + str(Time.get_ticks_usec()) + ".json"
	check(LevelStore.new().write_json(path, data).is_empty(), "export file")
	var loaded = FlowLevel.read_file(path)
	check(loaded.has("level") and loaded.level == data, "import round trip")
	DirAccess.remove_absolute(path)

func test_editor_and_ui(levels: Array) -> void:
	var app = load("res://scenes/editor.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.show_flow_levels()
	check(app.screen == "editor_catalog", "editor selection page")
	app.open_flow_editor(levels[0])
	await process_frame
	var editor = app.page.get_child(0)
	check(editor is FlowEditor, "editor entry")
	editor.select_brush(2)
	editor.paint(Vector2i(3, 3), false)
	editor.end_stroke()
	check([3, 3] in editor.data.walls, "wall brush")
	editor.undo()
	check([3, 3] not in editor.data.walls, "wall undo")
	editor.redo()
	check([3, 3] in editor.data.walls, "wall redo")
	editor.undo()
	editor.select_brush(6)
	editor.paint(Vector2i(1, 3), false)
	editor.end_stroke()
	check(editor.data.rooms.size() == 3, "box placement")
	editor.select_brush(0)
	editor.paint(Vector2i(1, 3), false)
	editor.name_input.text = "独立测试箱"
	var percentages = [10, 70, 15, 5]
	for i in 4: editor.probabilities[i].get_line_edit().text = str(percentages[i])
	editor.apply_box()
	var custom_kind = editor.data.rooms[2].kind
	check(custom_kind != "east" and is_equal_approx(editor.data.room_defs[custom_kind].p[1], 0.70), "individual probability edit")
	check(is_equal_approx(editor.data.room_defs.east.p[1], 0.80), "other boxes unchanged")
	editor.fields.balls.get_line_edit().text = "12500"
	editor.fields.horizon.get_line_edit().text = "60"
	editor.fields.budget.get_line_edit().text = "18"
	editor.fields.target.get_line_edit().text = "2000"
	editor.sync()
	check(editor.data.balls == 12500 and editor.data.horizon == 60 and editor.data.budget == 18, "level parameters")
	editor.fields.width.get_line_edit().text = "10"
	editor.fields.height.get_line_edit().text = "8"
	editor.resize_map()
	check(editor.data.width == 10 and editor.preview.width == 10, "resize")
	editor.undo()
	check(editor.data.width == 8, "resize undo")
	var original = editor.data.duplicate(true)
	editor.test_level()
	await process_frame
	var game = app.page.get_child(0)
	check(game is CampaignGame and game.test_mode, "editor playtest")
	check(is_instance_valid(game.rate_label) and is_instance_valid(game.count_label), "editor retains exact forecasts")
	check(game.model.balls == 12500 and game.model.horizon == 60, "playtest uses data")
	game.attempt_move(Vector2i.LEFT)
	await create_timer(0.2).timeout
	check(game.model.player == Vector2i(2, 4), "movement animation")
	game.undo()
	game.batch_amount = game.maximum_batch()
	game.start_run()
	check(game.model.phase == "running", "run")
	check(float(game.model.horizon) / game.speed + 0.85 <= 4.851, "playback duration bounded without changing steps")
	game.view.layout_board()
	var positions_valid = true
	var continuous = true
	var spread = Rect2(game.view.ball_offset(0, 0), Vector2.ZERO)
	for ball in 100:
		spread = spread.expand(game.view.ball_offset(ball, 0))
		for step in game.model.horizon:
			var left = game.view.ball_position_at(ball, float(step + 1) - 0.00001)
			var right = game.view.ball_position_at(ball, float(step + 1))
			if left.distance_to(right) > 0.01: continuous = false
			for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var position = game.view.ball_position_at(ball, step + fraction)
				for offset in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					var sample = game.view.grid_position(position + offset * game.view.ball_radius())
					if not game.model.floor_cell(Vector2i(floori(sample.x), floori(sample.y))): positions_valid = false
	check(continuous, "ball motion continuous at step boundaries")
	check(positions_valid, "ball radius remains within traversable cells")
	check(spread.size.x > 0.65 and spread.size.y > 0.65, "balls spread across tile interiors")
	game.view.frame_position = 20.5
	game.view.update_live_density()
	var counted = 0
	for count in game.view.live_counts: counted += count
	var expected_active = game.model.balls
	for path in game.model.ball_paths:
		if path[20] == game.model.index_of(game.model.exit_cell): expected_active -= 1
	check(counted == expected_active, "live heat counts only actual board balls")
	game.view.frame_position = 0
	game.finish_animation()
	check(game.model.phase == "result", "result")
	check(is_equal_approx(game.collection_tube.collected, game.model.last_result.expected), "tube matches exact settled arrivals")
	check(game.view.paths.size() == game.model.balls, "each ball rendered from actual path")
	game.leave()
	await process_frame
	editor = app.page.get_child(0)
	check(editor is FlowEditor and editor.data == original, "return preserves edited layout")
	editor.data.id = "flow_qa_" + str(Time.get_ticks_usec())
	editor.save_level(true)
	var draft = FlowLevel.DRAFTS.path_join(editor.data.id.sha256_text().substr(0, 24) + ".json")
	check(FileAccess.file_exists(draft), "draft save")
	editor.save_level(false)
	var published = FlowLevel.FOLDER.path_join(editor.data.id.sha256_text().substr(0, 24) + ".json")
	check(FileAccess.file_exists(published), "publish to selection")
	check(FlowLevel.catalog().levels.any(func(l): return l.id == editor.data.id), "published catalog entry")
	DirAccess.remove_absolute(draft)
	DirAccess.remove_absolute(published)
	var passes = levels.duplicate(true)
	passes[0].target = 0
	app.start_flow_campaign(passes)
	await process_frame
	game = app.page.get_child(0)
	game.batch_amount = game.maximum_batch()
	game.start_run()
	game.finish_animation()
	game.advance()
	check(game.model.level_index == 1 and game.model.phase == "prepare", "UI next map")
	app.show_menu()
	await process_frame
	check(app.screen == "editor_catalog", "independent editor catalog")
	app.queue_free()
	await process_frame
	var player_app = load("res://scenes/main.tscn").instantiate()
	player_app.progression_enabled = false
	root.add_child(player_app)
	player_app.start_flow_campaign(levels)
	var player_game = player_app.page.get_child(0)
	check(not is_instance_valid(player_game.rate_label) and not is_instance_valid(player_game.count_label), "player UI has no forecast controls")
	player_game.change_batch(100)
	check(player_game.requested_balls() == 200, "batch plus adds exactly 100")
	player_game.change_batch(-100)
	player_game.change_batch(-100)
	check(player_game.requested_balls() == 100, "batch minus respects minimum")
	check(player_game.batch_label.text == "100 / 1000", "batch label shows selection and remaining pool")
	player_game.start_run()
	check(player_game.batch_label.text == "100 / 900", "release updates remaining pool immediately")
	check("WASD移动角色推动箱子" in player_game.message.text, "first level keeps movement hint while running")
	check(player_game.run_button.visible and player_game.run_button.text == "开始放球", "release button stays visible and named")
	check(player_game.run_button.disabled and player_game.reset_button.disabled and player_game.increase_button.disabled and player_game.decrease_button.disabled and player_game.leave_button.disabled, "all left controls locked during release")
	player_game.toggle_play()
	player_game.reset_preparation()
	player_game.leave()
	check(player_game.model.phase == "running" and player_app.screen == "flow" and player_game.leave_button.disabled, "paused release cannot reset or leave")
	player_game.finish_animation()
	check(player_game.model.phase == "prepare" and player_game.model.remaining_balls == 900, "UI defaults to 100-ball trial")
	check(not player_game.run_button.disabled and not player_game.reset_button.disabled and not player_game.leave_button.disabled and not player_game.increase_button.disabled, "left controls unlock automatically after batch")
	var stored_count = player_game.model.collected_total
	check(player_game.model.phase == "prepare" and player_game.collection_tube.collected == stored_count, "UI retains tube while returning to placement")
	player_game.reset_preparation()
	check(player_game.collection_tube.collected == 0 and player_game.model.remaining_balls == 1000, "UI whole-level restart")
	player_game.model.remaining_balls = 250
	player_game.change_batch(100)
	player_game.change_batch(100)
	check(player_game.requested_balls() == 200, "batch stays on hundred increments below nonround remainder")
	player_game.model.remaining_balls = 50
	player_game.refresh_controls()
	check(player_game.requested_balls() == 50 and player_game.increase_button.disabled and player_game.decrease_button.disabled, "final remainder is released together")
	player_app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
