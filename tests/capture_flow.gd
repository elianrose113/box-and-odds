extends SceneTree
var app: Control
var output = ProjectSettings.globalize_path("res://../verification")

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print(name, ": ", root.get_texture().get_image().save_png(output.path_join(name + ".png")))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	app = load("res://scenes/main.tscn").instantiate()
	app.progression_enabled = false
	root.add_child(app)
	await process_frame
	await shot("main_menu")
	var levels = FlowLevel.catalog().levels
	app.start_flow_campaign(levels)
	app.page.get_child(0).show_intro()
	await shot("first_level_intro")
	app.show_flow_levels()
	await shot("flow_level_select")
	app.start_flow_campaign(levels)
	await process_frame
	var game = app.page.get_child(0)
	await shot("flow_level_game")
	print("BOARD prepare ", game.view.size, " tile ", game.view.cell_size)
	for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.UP]:
		game.attempt_move(direction)
		await create_timer(0.27).timeout
	await shot("flow_level_improved")
	game.start_run()
	game.frame_time = 24
	game.view.frame_position = 24
	game.update_frame_label()
	game.playing = false
	await shot("flow_level_running")
	print("BOARD running ", game.view.size, " tile ", game.view.cell_size)
	game.finish_animation()
	await shot("flow_level_passed")
	print("BOARD result ", game.view.size, " tile ", game.view.cell_size)
	await shot("flow_batch_continue")
	app.start_flow_campaign(levels, 1)
	root.size = Vector2i(960, 640)
	await shot("flow_level_small")
	root.size = Vector2i(1280, 800)
	app.queue_free()
	await process_frame
	app = load("res://scenes/editor.tscn").instantiate()
	app.progression_enabled = false
	root.add_child(app)
	await shot("editor_catalog")
	app.open_flow_editor(levels[0])
	await process_frame
	var editor = app.page.get_child(0)
	await shot("flow_editor_map")
	editor.set_mode(2)
	await shot("flow_editor_parameters")
	editor.set_mode(1)
	editor.paint(Vector2i(2, 2), false)
	await shot("flow_editor_probabilities")
	root.size = Vector2i(960, 640)
	await shot("flow_editor_small")
	editor.test_level()
	await process_frame
	var test_game = app.page.get_child(0)
	test_game.show_cell(Vector2i(2,2))
	await shot("workshop_editor_playtest_small")
	test_game.leave()
	await process_frame
	var wide = levels[0].duplicate(true)
	wide.width = 10
	wide.height = 8
	wide.walls = []
	for y in 8:
		for x in 10:
			if x == 0 or y == 0 or x == 9 or y == 7: wide.walls.append([x,y])
	wide.exit = [8,6]
	app.open_flow_editor(wide)
	await shot("workshop_editor_10x8")
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()
