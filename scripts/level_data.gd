class_name LevelData
extends RefCounted
## JSON coordinates are [x, y]. Terrain and objects are separate layers.
const VERSION = 1
const MAX_SIZE = 32
var id: String = ""
var title: String = "未命名关卡"
var order: int = 1
var width: int = 10
var height: int = 8
var walls: Array[Vector2i] = []
var goals: Array[Vector2i] = []
var boxes: Array[Vector2i] = []
var player: Vector2i = Vector2i(-1, -1)

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height

func copy() -> LevelData:
	var result = LevelData.new()
	result.id = id
	result.title = title
	result.order = order
	result.width = width
	result.height = height
	result.walls.assign(walls)
	result.goals.assign(goals)
	result.boxes.assign(boxes)
	result.player = player
	return result

func validate() -> PackedStringArray:
	var errors = PackedStringArray()
	if title.strip_edges().is_empty(): errors.append("请填写关卡名称。")
	if width < 4 or height < 4 or width > MAX_SIZE or height > MAX_SIZE:
		errors.append("地图宽高必须在 4～32 之间。")
	if not inside(player): errors.append("请放置一个玩家出生点。")
	if goals.is_empty(): errors.append("请至少放置一个目标点。")
	if boxes.size() != goals.size(): errors.append("箱子数量必须与目标点数量一致。")
	for p in walls + goals + boxes:
		if not inside(p):
			errors.append("存在地图范围外的元素。")
			break
	if player in walls: errors.append("玩家不能位于墙内。")
	for p in boxes:
		if p in walls:
			errors.append("箱子不能位于墙内。")
			break
	for p in goals:
		if p in walls:
			errors.append("目标点不能位于墙内。")
			break
	if player in boxes: errors.append("玩家与箱子不能重叠。")
	return errors

func to_dict() -> Dictionary:
	return {"version": VERSION, "id": id, "title": title, "order": order,
		"width": width, "height": height, "walls": pairs(walls),
		"goals": pairs(goals), "boxes": pairs(boxes), "player": [player.x, player.y]}

static func pairs(items: Array[Vector2i]) -> Array:
	var result: Array = []
	for p in items: result.append([p.x, p.y])
	return result

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func coord(value: Variant) -> bool:
	return value is Array and value.size() == 2 and integer(value[0]) and integer(value[1]) and abs(value[0]) <= 1024 and abs(value[1]) <= 1024

static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary: return {"error": "关卡根节点必须为 JSON 对象。"}
	if data.get("version") != VERSION: return {"error": "不支持的关卡格式版本。"}
	for key in ["width", "height", "order"]:
		if not integer(data.get(key)): return {"error": key + " 必须为整数。"}
	if data.width < 4 or data.height < 4 or data.width > MAX_SIZE or data.height > MAX_SIZE:
		return {"error": "地图宽高必须在 4～32 之间。"}
	if not data.get("title") is String or not data.get("id") is String:
		return {"error": "关卡名称和 ID 必须为字符串。"}
	if data.title.length() > 80 or data.id.length() > 128 or data.id.is_empty():
		return {"error": "关卡名称或 ID 长度不合法。"}
	if not coord(data.get("player")): return {"error": "玩家坐标格式错误。"}
	var level = LevelData.new()
	level.id = data.id
	level.title = data.title
	level.width = int(data.width)
	level.height = int(data.height)
	level.order = clampi(int(data.order), 1, 999)
	level.player = Vector2i(int(data.player[0]), int(data.player[1]))
	for key in ["walls", "goals", "boxes"]:
		if not data.get(key) is Array or data[key].size() > MAX_SIZE * MAX_SIZE:
			return {"error": key + " 数组格式错误或过大。"}
		var points: Array[Vector2i] = []
		for value in data[key]:
			if not coord(value): return {"error": key + " 坐标格式错误。"}
			var p = Vector2i(int(value[0]), int(value[1]))
			if not level.inside(p): return {"error": "存在地图范围外的元素。"}
			if p in points: return {"error": key + " 存在重复坐标。"}
			points.append(p)
		level.set(key, points)
	return {"level": level}

static func blank(w: int = 10, h: int = 8) -> LevelData:
	var level = LevelData.new()
	level.id = "level_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(randi() % 100000)
	level.width = w
	level.height = h
	for y in h:
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1: level.walls.append(Vector2i(x, y))
	return level

func signature() -> String:
	var data = to_dict()
	data.erase("title")
	data.erase("id")
	data.erase("order")
	return JSON.stringify(data).sha256_text()