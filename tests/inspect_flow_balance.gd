extends SceneTree
func _initialize() -> void:
	var levels = FlowLevel.catalog().levels
	for data in levels:
		var model = CampaignRun.new()
		model.start([data])
		var baseline = model.simulate().expected
		var reachable: Array[Vector2i] = [model.player]
		var cursor = 0
		while cursor < reachable.size():
			var cell = reachable[cursor]
			cursor += 1
			for direction in FlowRun.DIRS:
				var next: Vector2i = cell + direction
				if model.floor_cell(next) and not model.rooms.has(next) and next not in reachable: reachable.append(next)
		var best = baseline
		for position in model.rooms.keys():
			for direction in FlowRun.DIRS:
				var behind: Vector2i = position - direction
				if behind not in reachable: continue
				var copy = CampaignRun.new()
				copy.start([data])
				copy.player = behind
				var result = copy.move(direction)
				if not result.ok: continue
				best = maxf(best, copy.simulate().expected)
		print(data.title, " baseline ", snappedf(baseline, 0.1), " best single push ", snappedf(best, 0.1), " target ", data.target)
	quit()
