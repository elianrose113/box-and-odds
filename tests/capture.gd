extends SceneTree
var app: Control
var output = ProjectSettings.globalize_path("res://../verification")

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	print("SCREENSHOT ", name, " ", result)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await shot("main_menu")
	app.show_levels()
	await shot("level_select")
	app.edit_existing(app.levels[3])
	await shot("level_editor")
	app.test_editor()
	await shot("gameplay")
	app.start_game(app.levels[0], true)
	app.try_move(Vector2i.UP)
	await create_timer(0.3).timeout
	await shot("completed")
	app.return_editor()
	root.size = Vector2i(960, 640)
	await shot("editor_small")
	root.size = Vector2i(1600, 900)
	await shot("editor_wide")
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()
