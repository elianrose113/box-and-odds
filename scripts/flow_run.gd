class_name FlowRun
extends RefCounted
const DIRS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const ROOM_TYPES = {
	"east": {"name": "右向箱子", "p": [0.05, 0.80, 0.10, 0.05], "color": "#e6b575"},
	"south": {"name": "下向箱子", "p": [0.05, 0.10, 0.80, 0.05], "color": "#82c8e5"},
	"split": {"name": "右下分流", "p": [0.05, 0.45, 0.45, 0.05], "color": "#94d8af"},
	"west": {"name": "左向箱子", "p": [0.05, 0.05, 0.10, 0.80], "color": "#dba1cb"},
	"north": {"name": "上向箱子", "p": [0.80, 0.10, 0.05, 0.05], "color": "#a9a0e4"}
}
var width = 8
var height = 7
var entrance = Vector2i(1, 1)
var exit_cell = Vector2i(6, 5)
var walls: Array[Vector2i] = []
var rooms: Dictionary = {}
var definitions: Dictionary = {}
var player = Vector2i(3, 4)
var phase = "prepare"
var balls = 10000
var horizon = 48
var base_budget = 12
var pushes_left = 12
var last_result: Dictionary = {}
var history: Array[Dictionary] = []
var round_start: Dictionary = {}

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height

func floor_cell(p: Vector2i) -> bool:
	return inside(p) and p not in walls

func index_of(p: Vector2i) -> int:
	return p.y * width + p.x

func room_spec(kind: String) -> Dictionary:
	return definitions[kind]

func snapshot() -> Dictionary:
	return {"player": player, "rooms": rooms.duplicate(), "remaining": pushes_left}

func restore(data: Dictionary) -> void:
	player = data.player
	rooms = data.rooms.duplicate()
	pushes_left = data.remaining

func undo() -> bool:
	if phase != "prepare" or history.is_empty(): return false
	restore(history.pop_back())
	return true

func reset_preparation() -> bool:
	if phase != "prepare": return false
	restore(round_start)
	history.clear()
	return true

func move(direction: Vector2i) -> Dictionary:
	if phase != "prepare" or direction not in DIRS: return {"ok": false, "error": ""}
	var destination = player + direction
	if not floor_cell(destination): return {"ok": false, "error": ""}
	var pushed = rooms.has(destination)
	var beyond = destination + direction
	if pushed:
		if pushes_left <= 0: return {"ok": false, "error": "推动次数已用完。"}
		if not floor_cell(beyond) or rooms.has(beyond): return {"ok": false, "error": ""}
		if beyond in [entrance, exit_cell]: return {"ok": false, "error": "入口与出口不能放置箱子。"}
	history.append(snapshot())
	if history.size() > 2000: history.pop_front()
	var result = {"ok": true, "pushed": pushed, "from": player, "to": destination, "box_from": destination, "box_to": beyond}
	if pushed:
		rooms[beyond] = rooms[destination]
		rooms.erase(destination)
		pushes_left -= 1
	player = destination
	return result

func kernel() -> Array:
	var result: Array = []
	for i in width * height:
		var p = Vector2i(i % width, i / width)
		var transitions: Dictionary = {}
		if p == exit_cell or not floor_cell(p):
			transitions[i] = 1.0
		else:
			var probabilities: Array = room_spec(rooms[p]).p if rooms.has(p) else [0.25, 0.25, 0.25, 0.25]
			for d in 4:
				var next: Vector2i = p + DIRS[d]
				if not floor_cell(next): next = p
				var target_index = index_of(next)
				transitions[target_index] = transitions.get(target_index, 0.0) + probabilities[d]
		result.append(transitions)
	return result

func simulate(step_count: int = -1) -> Dictionary:
	var count = horizon if step_count < 0 else step_count
	var transitions = kernel()
	var distribution = PackedFloat64Array()
	distribution.resize(width * height)
	distribution[index_of(entrance)] = 1.0
	var frames: Array[PackedFloat64Array] = [distribution.duplicate()]
	for step in count:
		var next = PackedFloat64Array()
		next.resize(width * height)
		for source in distribution.size():
			if distribution[source] <= 0.0: continue
			for destination in transitions[source]:
				next[destination] += distribution[source] * transitions[source][destination]
		distribution = next
		frames.append(distribution.duplicate())
	var rate = distribution[index_of(exit_cell)]
	return {"frames": frames, "rate": rate, "expected": rate * balls, "steps": count, "balls": balls, "kernel": transitions}

func begin_run() -> Dictionary:
	if phase != "prepare": return {}
	phase = "running"
	return simulate()
