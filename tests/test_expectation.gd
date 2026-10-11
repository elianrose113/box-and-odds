extends SceneTree
func _initialize() -> void:
	var data = FlowLevel.read_file("res://flow_levels/001.json").level
	data.target = data.balls
	var single = CampaignRun.new()
	single.start([data])
	single.begin_run()
	single.settle({})
	var split = CampaignRun.new()
	split.start([data])
	while split.remaining_balls > 0:
		split.begin_run(mini(100, split.remaining_balls))
		split.settle({})
		assert(split.collected_total == roundi(split.expected_total))
		if split.remaining_balls > 0: assert(split.continue_batch())
	assert(split.collected_total == single.collected_total)
	var model = CampaignRun.new()
	model.start([data])
	model.horizon = 0
	model.generate_balls()
	assert(model.actual_arrivals == 0)
	model.horizon = 1
	model.exit_cell = model.entrance + Vector2i.RIGHT
	model.rooms[model.entrance] = "certainty"
	model.definitions["certainty"] = {"p": [0.0, 1.0, 0.0, 0.0]}
	model.generate_balls()
	assert(model.actual_arrivals == model.balls)
	print("EXPECTED OUTCOME CHECKS PASSED: ", single.collected_total)
	quit()
