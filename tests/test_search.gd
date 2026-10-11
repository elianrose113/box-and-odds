extends SceneTree
func _initialize() -> void:
	for file in ["001.json", "002.json", "003.json"]:
		var data = FlowLevel.read_file("res://flow_levels/" + file).level
		var before = data.duplicate(true)
		var result = LevelDifficulty.analyze(data)
		var small = LevelDifficulty.analyze(data, 48)
		assert(result.rate + 0.000000001 >= small.rate)
		assert(result.examined <= 2000 and result.max_depth <= data.budget)
		assert(data == before)
		var run = CampaignRun.new()
		run.start([data], 0, true)
		for move in result.moves:
			var box = FlowLevel.point(move.from)
			var direction = FlowLevel.point(move.to) - box
			var standing = box - direction
			var queue: Array = [run.player]
			var paths: Dictionary = {run.player: []}
			while not paths.has(standing):
				assert(not queue.is_empty())
				var current: Vector2i = queue.pop_front()
				for d in FlowRun.DIRS:
					var next = current + d
					if run.floor_cell(next) and not run.rooms.has(next) and not paths.has(next):
						var path: Array = paths[current].duplicate()
						path.append(d)
						paths[next] = path
						queue.append(next)
			for d in paths[standing]: assert(run.move(d).ok)
			assert(run.move(direction).get("pushed", false))
		assert(is_equal_approx(run.simulate().rate, result.rate))
		assert(is_equal_approx(LevelDifficulty.exit_rate(run, run.rooms, LevelDifficulty.neighbor_table(run)), run.simulate().rate))
		assert(data.budget - run.pushes_left == result.pushes)
		print(file, " evaluated=", result.examined, " stop=", result.stop_reason, " depth=", result.max_depth, " expected=", result.expected)
	# Independent breadth-first enumeration without player-region merging.
	var tiny = FlowLevel.blank()
	tiny.width = 5
	tiny.height = 5
	tiny.entrance = [1,1]
	tiny.exit = [3,3]
	tiny.player = [1,3]
	tiny.rooms = [{"pos": [2,2], "kind": "east"}]
	tiny.walls = []
	for y in 5:
		for x in 5:
			if x == 0 or y == 0 or x == 4 or y == 4: tiny.walls.append([x,y])
	tiny.budget = 4
	var model = CampaignRun.new()
	model.start([tiny])
	var queue: Array = [{"player": model.player, "rooms": model.rooms.duplicate(), "depth": 0}]
	var seen = {}
	var layouts = {}
	var best = 0.0
	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		model.player = state.player
		model.rooms = state.rooms.duplicate()
		var cells = model.rooms.keys()
		cells.sort()
		var key = str(cells)
		if not layouts.has(key):
			layouts[key] = true
			best = maxf(best, model.simulate().rate)
		var state_key = key + str(model.player)
		if seen.has(state_key) and seen[state_key] <= state.depth: continue
		seen[state_key] = state.depth
		for direction in FlowRun.DIRS:
			model.player = state.player
			model.rooms = state.rooms.duplicate()
			model.pushes_left = tiny.budget - state.depth
			model.history.clear()
			var movement = model.move(direction)
			if movement.ok: queue.append({"player": model.player, "rooms": model.rooms.duplicate(), "depth": state.depth + (1 if movement.pushed else 0)})
	var exact = LevelDifficulty.analyze(tiny)
	assert(exact.complete and exact.examined == layouts.size())
	assert(is_equal_approx(exact.rate, best))
	var limited = LevelDifficulty.analyze(tiny, 1)
	assert(not limited.complete and limited.stop_reason == "layout_limit" and limited.examined == 1)
	print("SEARCH VALIDATION PASSED")
	quit()
