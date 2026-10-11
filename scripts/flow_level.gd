class_name FlowLevel
extends RefCounted
const FOLDER = "user://flow_levels"
const DRAFTS = "user://flow_drafts"

static func blank() -> Dictionary:
	var walls: Array = []
	for y in 7:
		for x in 8:
			if x == 0 or y == 0 or x == 7 or y == 6: walls.append([x, y])
	return {"version": 2, "type": "flow", "id": "flow_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(randi() % 100000), "title": "新概率关卡", "order": 1,
		"width": 8, "height": 7, "walls": walls, "entrance": [1, 1], "exit": [6, 5], "player": [3, 4],
		"balls": 1000, "horizon": 48, "budget": 12, "target": 260, "rooms": [],
		"room_defs": FlowRun.ROOM_TYPES.duplicate(true)}

static func point(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func pair(p: Vector2i) -> Array:
	return [p.x, p.y]

static func valid_point(value: Variant, data: Dictionary) -> bool:
	return LevelData.coord(value) and value[0] >= 0 and value[1] >= 0 and value[0] < data.width and value[1] < data.height

static func validate(data: Variant, playable: bool = true) -> PackedStringArray:
	var errors = PackedStringArray()
	if not data is Dictionary: return ["关卡必须是 JSON 对象。"]
	if data.get("version") != 2 or data.get("type") != "flow": return ["不是支持的概率关卡文件。"]
	for key in ["id", "title"]:
		if not data.get(key) is String or data[key].is_empty() or data[key].length() > 80: errors.append(key + " 不能为空或超过 80 字。")
	for key in ["width", "height"]:
		if not LevelData.integer(data.get(key)) or data[key] < 4 or data[key] > (10 if key == "width" else 8): errors.append("地图宽度须为 4～10，高度须为 4～8 的整数。")
	if not errors.is_empty(): return errors
	var limits = {"order": [1, 999], "balls": [1, 100000], "horizon": [1, 200], "budget": [0, 100], "target": [0, 100000]}
	for key in limits:
		if not LevelData.integer(data.get(key)) or data[key] < limits[key][0] or data[key] > limits[key][1]: errors.append(key + " 数值超出范围。")
	for key in ["walls", "rooms"]:
		if not data.get(key) is Array or data[key].size() > 256: errors.append(key + " 必须为不超过 256 项的数组。")
	if not data.get("room_defs") is Dictionary or data.room_defs.is_empty() or data.room_defs.size() > 128: errors.append("箱子模板须为 1～128 个。")
	if not errors.is_empty(): return errors
	var wall_seen: Array = []
	for p in data.walls:
		if not valid_point(p, data): errors.append("墙体坐标越界。")
		elif p in wall_seen: errors.append("墙体坐标重复。")
		wall_seen.append(p)
	for key in ["entrance", "exit", "player"]:
		if not valid_point(data.get(key), data): errors.append(key + " 坐标无效。")
		elif data[key] in data.walls: errors.append(key + " 不能位于墙中。")
	for kind in data.room_defs:
		var spec = data.room_defs[kind]
		if not kind is String or kind.length() > 80 or not spec is Dictionary: errors.append("箱子模板格式错误。"); continue
		if not spec.get("name") is String or spec.name.is_empty() or spec.name.length() > 40: errors.append("箱子名称应为 1～40 字。")
		if not spec.get("color") is String or not Color.html_is_valid(spec.color): errors.append("箱子颜色格式错误。")
		if not spec.get("p") is Array or spec.p.size() != 4: errors.append("箱子需要上、右、下、左四个概率。"); continue
		var total = 0.0
		for probability in spec.p:
			if not (probability is float or probability is int) or not is_finite(float(probability)) or probability < 0 or probability > 1: errors.append("概率必须为 0～1。")
			else: total += probability
		if absf(total - 1.0) > 0.000001: errors.append("箱子四向概率之和必须为 100%。")
	if not errors.is_empty(): return errors
	var occupied: Array = []
	for room in data.rooms:
		if not room is Dictionary or not valid_point(room.get("pos"), data) or not data.room_defs.has(room.get("kind")): errors.append("箱子位置或模板无效。"); continue
		if room.pos in occupied or room.pos in data.walls or room.pos in [data.player, data.entrance, data.exit]: errors.append("箱子不能重叠或覆盖玩家、墙、入口、出口。")
		occupied.append(room.pos)
	if data.entrance == data.exit: errors.append("入口与出口必须不同。")
	if data.rooms.size() * 2 > data.width * data.height - data.walls.size(): errors.append("至少保留一半可行走空格。")
	if playable and data.rooms.is_empty(): errors.append("请至少放置一个箱子。")
	if playable and data.target > data.balls: errors.append("通关目标不能超过初始球数。")
	if playable:
		var visited: Array = [data.entrance]
		var cursor = 0
		while cursor < visited.size():
			var p = point(visited[cursor])
			cursor += 1
			for direction in FlowRun.DIRS:
				var next = pair(p + direction)
				if valid_point(next, data) and next not in data.walls and next not in visited: visited.append(next)
		if data.exit not in visited: errors.append("墙体完全隔断了入口和出口。")
	return errors

static func read_file(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024: return {"error": "无法读取关卡，或文件超过 1 MB。"}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"error": "JSON 格式错误，第 %d 行。" % parser.get_error_line()}
	var decoded = normalize(parser.data)
	var errors = validate(decoded, false)
	if not errors.is_empty(): return {"error": "\n".join(errors)}
	return {"level": decoded}

static func catalog() -> Dictionary:
	var levels: Array = []
	var errors: Array[String] = []
	var ids: Dictionary = {}
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for folder in ["res://flow_levels", FOLDER]:
		for filename in DirAccess.get_files_at(folder):
			if not filename.ends_with(".json"): continue
			var loaded = read_file(folder.path_join(filename))
			if loaded.has("error"): errors.append(filename + "：" + loaded.error); continue
			var issues = validate(loaded.level)
			if not issues.is_empty(): errors.append(filename + "：" + "\n".join(issues)); continue
			var id: String = loaded.level.id
			if ids.has(id): levels[ids[id]] = loaded.level
			else:
				ids[id] = levels.size()
				levels.append(loaded.level)
	levels.sort_custom(func(a: Dictionary, b: Dictionary): return a.order < b.order if a.order != b.order else a.title.naturalnocasecmp_to(b.title) < 0)
	return {"levels": levels, "errors": errors}

static func save(data: Dictionary, draft: bool) -> String:
	var folder = DRAFTS if draft else FOLDER
	DirAccess.make_dir_recursive_absolute(folder)
	return LevelStore.new().write_json(folder.path_join(str(data.id).sha256_text().substr(0, 24) + ".json"), data)

static func normalize(value: Variant) -> Variant:
	if not value is Dictionary: return value
	for key in ["entrance", "exit", "player"]:
		if LevelData.coord(value.get(key)): value[key] = pair(point(value[key]))
	if value.get("walls") is Array:
		for i in value.walls.size():
			if LevelData.coord(value.walls[i]): value.walls[i] = pair(point(value.walls[i]))
	if value.get("rooms") is Array:
		for room in value.rooms:
			if room is Dictionary and LevelData.coord(room.get("pos")): room.pos = pair(point(room.pos))
	for key in ["width", "height", "order", "balls", "horizon", "budget", "target", "version"]:
		if LevelData.integer(value.get(key)) and absf(float(value[key])) < 10000000: value[key] = int(value[key])
	return value
static func percent(probability: float) -> String:
	var text = "%.2f" % (probability * 100.0)
	while text.ends_with("0"): text = text.left(-1)
	if text.ends_with("."): text = text.left(-1)
	return text + "%"