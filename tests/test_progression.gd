extends SceneTree
var errors = 0
func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var save_path = "user://progress_test_%d.json" % Time.get_ticks_usec()
	var app = load("res://scenes/main.tscn").instantiate()
	app.progress = CampaignProgress.new(save_path)
	root.add_child(app)
	var levels = FlowLevel.catalog().levels.duplicate(true)
	levels[0].target = 0
	levels[1].target = 0
	app.start_flow_campaign(levels, 2)
	await process_frame
	var game = app.page.get_child(0)
	check(is_instance_valid(game.intro_overlay) and not game.is_processing_unhandled_key_input(), "first-level intro blocks gameplay input")
	game.dismiss_intro()
	check(CampaignProgress.new(save_path).intro_seen() and game.is_processing_unhandled_key_input(), "intro acknowledgement persists and restores input")
	check(game.model.level_index == 0, "locked level cannot be entered directly")
	check(game.leave_button.text == "返回选关" and not is_instance_valid(game.undo_button), "formal game has restart and level selection only")
	check(absf(game.leave_button.size.x - game.reset_button.size.x) <= 1.0, "action buttons have equal width")
	var button_rect = game.run_button.get_global_rect()
	game.advance()
	check(game.model.level_index == 0, "advance before passing cannot skip level")
	game.primary_action()
	game.finish_animation()
	await process_frame
	check(game.run_button.text == "下一关" and not game.run_button.disabled, "passed level switches primary button")
	check(game.run_button.get_global_rect() == button_rect, "primary button retains position and size")
	check(CampaignProgress.new(save_path).first_unfinished(levels) == 1, "pass persists and unlocks exactly one level")
	game.primary_action()
	check(game.model.level_index == 1, "primary button enters next unlocked level")
	game.primary_action()
	game.finish_animation()
	check(CampaignProgress.new(save_path).first_unfinished(levels) == 2, "second pass unlocks third level")
	game.reset_preparation()
	check(game.run_button.text == "开始放球", "restart restores release button")
	game.leave()
	check(app.screen == "flow_levels", "return button opens level selection")
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	DirAccess.remove_absolute(save_path)
	print("PROGRESSION FAILURES: ", errors)
	quit(0 if errors == 0 else 1)
