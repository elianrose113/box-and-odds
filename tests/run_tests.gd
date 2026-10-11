extends SceneTree
var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func fixture() -> LevelData:
	var level = LevelData.blank(7, 7)
	level.title = "测试"
	level.player = Vector2i(3, 3)
	level.boxes.assign([Vector2i(3, 2)])
	level.goals.assign([Vector2i(3, 1)])
	return level

func run() -> void:
	test_rules()
	test_format()
	test_storage()
	await test_ui()
	print("CHECKS: %d  FAILURES: %d" % [checks, failures.size()])
	for failure in failures: print("FAILED: " + failure)
	quit(0 if failures.is_empty() else 1)

func test_rules() -> void:
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var level = fixture()
		level.boxes.assign([level.player + direction])
		level.goals.assign([level.player + direction * 2])
		var state = BoardState.new()
		state.setup(level)
		var result = state.move(direction)
		check(result.ok and result.pushed, "four-direction push " + str(direction))
		check(state.player == level.player + direction and state.boxes[0] == level.goals[0], "push destination")
		check(state.won() and state.steps == 1 and state.pushes == 1, "victory and counters")
		check(level.boxes[0] == level.player + direction, "source layout immutable")
		check(state.undo() and state.player == level.player and state.boxes == level.boxes and state.steps == 0 and state.pushes == 0, "undo restores whole turn")
		check(not state.undo(), "empty undo")
		level.walls.append(level.player + direction * 2)
		state.setup(level)
		check(not state.move(direction).ok and state.steps == 0 and state.history.is_empty(), "wall prevents pushing")
		level.walls.erase(level.player + direction * 2)
		level.boxes.append(level.player + direction * 2)
		state.setup(level)
		check(not state.move(direction).ok and state.boxes == level.boxes, "cannot push two boxes")
	var level = fixture()
	var state = BoardState.new()
	state.setup(level)
	check(state.move(Vector2i.LEFT).ok and state.pushes == 0, "free walking")
	check(not state.move(Vector2i(1, 1)).ok and not state.move(Vector2i.ZERO).ok, "invalid direction")
	state.player = Vector2i(1, 1)
	check(not state.move(Vector2i.UP).ok, "wall stops walking")
	level.walls.clear()
	level.player = Vector2i(0, 0)
	state.setup(level)
	check(not state.move(Vector2i.LEFT).ok, "map edge stops walking without wall")
	level.player = Vector2i(1, 2)
	level.boxes.assign([Vector2i(0, 2)])
	state.setup(level)
	check(not state.move(Vector2i.LEFT).ok, "map edge stops pushing")
	level = fixture()
	level.goals.append(Vector2i(4, 4))
	state.setup(level)
	state.move(Vector2i.UP)
	check(not state.won(), "every goal required")
	level.goals.clear()
	state.setup(level)
	check(not state.won(), "zero goals never auto-win")
	level = fixture()
	level.boxes.assign(level.goals)
	state.setup(level)
	check(state.won(), "initial completed map")
	state.move(Vector2i.LEFT)
	state.setup(fixture())
	check(state.steps == 0 and state.pushes == 0 and state.history.is_empty(), "restart resets history")

func test_format() -> void:
	var level = fixture()
	check(level.validate().is_empty(), "valid map")
	var decoded = LevelData.decode(JSON.parse_string(JSON.stringify(level.to_dict())))
	check(decoded.has("level") and decoded.level.to_dict() == level.to_dict(), "JSON round trip")
	var data = level.to_dict()
	data.width = 6.5
	check(LevelData.decode(data).has("error"), "reject fractional sizes")
	data = level.to_dict()
	data.boxes.append(data.boxes[0])
	check(LevelData.decode(data).has("error"), "reject duplicate coordinates")
	data = level.to_dict()
	data.goals = [[100, 100]]
	check(LevelData.decode(data).has("error"), "reject out of bounds")
	data = level.to_dict()
	data.player = "oops"
	check(LevelData.decode(data).has("error"), "reject invalid player")
	data = level.to_dict()
	data.version = 99
	check(LevelData.decode(data).has("error"), "reject unknown version")
	check(LevelData.decode([]).has("error"), "reject non-object")
	level.player = Vector2i(-1, -1)
	check(not level.validate().is_empty(), "require player")
	check(LevelData.decode(level.to_dict()).has("level"), "draft permits absent player")
	level = fixture()
	level.boxes.clear()
	check(not level.validate().is_empty(), "require matching crate and goal counts")
	level = fixture()
	level.walls.append(level.boxes[0])
	check(not level.validate().is_empty(), "reject wall overlap")
	level = fixture()
	level.boxes.append(level.player)
	check(not level.validate().is_empty(), "reject overlapping actor")
	level = fixture()
	level.goals.append(level.player)
	level.boxes.append(Vector2i(4, 4))
	check(level.validate().is_empty(), "player may stand on goal")

func test_storage() -> void:
	var store = LevelStore.new()
	store.ensure_dirs()
	var path = "user://qa_roundtrip_" + str(Time.get_ticks_usec()) + ".json"
	var level = fixture()
	check(store.write_json(path, level.to_dict()).is_empty(), "save JSON")
	level.title = "覆盖验证"
	check(store.write_json(path, level.to_dict()).is_empty(), "overwrite atomic save")
	check(store.read_level(path).level.title == "覆盖验证", "read overwritten save")
	check(DirAccess.remove_absolute(path) == OK, "clean test file")
	check(store.read_level(path).has("error"), "missing file feedback")
	check(not store.write_json("user://nonexistent_qa_directory/file.json", {}).is_empty(), "write error feedback")
	var levels = store.catalog()
	check(levels.size() >= 4 and store.errors.is_empty(), "bundled catalog loads")
	for sample in levels:
		if not sample.id.begins_with("00"): continue
		var solution = solve(sample)
		check(not solution.is_empty(), "sample solvable: " + sample.title)
		var state = BoardState.new()
		state.setup(sample)
		for direction in solution:
			check(state.move(direction).ok, "solver path uses legal movement")
		check(state.won(), "sample completion: " + sample.title)

func key_for(player: Vector2i, boxes: Array) -> String:
	var sorted = boxes.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i): return a.y * 32 + a.x < b.y * 32 + b.x)
	return str(player) + str(sorted)

func solve(level: LevelData) -> Array:
	var pending: Array = [{"p": level.player, "b": level.boxes.duplicate(), "path": []}]
	var visited = {key_for(level.player, level.boxes): true}
	var head = 0
	while head < pending.size() and head < 150000:
		var node = pending[head]
		head += 1
		var solved = true
		for goal in level.goals:
			if goal not in node.b: solved = false; break
		if solved: return node.path
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var target: Vector2i = node.p + direction
			if not level.inside(target) or target in level.walls: continue
			var next_boxes: Array = node.b.duplicate()
			var index = next_boxes.find(target)
			if index >= 0:
				var beyond: Vector2i = target + direction
				if not level.inside(beyond) or beyond in level.walls or beyond in next_boxes: continue
				next_boxes[index] = beyond
			var key = key_for(target, next_boxes)
			if visited.has(key): continue
			visited[key] = true
			var path: Array = node.path.duplicate()
			path.append(direction)
			pending.append({"p": target, "b": next_boxes, "path": path})
	return []

func test_ui() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.screen == "menu", "main menu starts")
	check(not app.has_method("open_flow_editor") and not app.has_method("show_levels"), "game excludes editor and classic entrypoints")
	app.show_flow_levels()
	check(app.screen == "flow_levels", "probability selection")
	app.queue_free()
	await process_frame
	await create_timer(0.3).timeout
