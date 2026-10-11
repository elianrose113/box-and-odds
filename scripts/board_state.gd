class_name BoardState
extends RefCounted
## Authoritative discrete state. Animation never decides collision or victory.
var level: LevelData
var player: Vector2i
var boxes: Array[Vector2i] = []
var steps: int = 0
var pushes: int = 0
var history: Array[Dictionary] = []

func setup(source: LevelData) -> void:
	level = source.copy()
	player = level.player
	boxes.assign(level.boxes)
	steps = 0
	pushes = 0
	history.clear()

func blocked(p: Vector2i) -> bool:
	return not level.inside(p) or p in level.walls

func move(direction: Vector2i) -> Dictionary:
	if absi(direction.x) + absi(direction.y) != 1: return {"ok": false}
	var target = player + direction
	if blocked(target): return {"ok": false}
	var index = boxes.find(target)
	var next = target + direction
	if index >= 0 and (blocked(next) or next in boxes): return {"ok": false}
	history.append({"player": player, "boxes": boxes.duplicate(), "steps": steps, "pushes": pushes})
	var result = {"ok": true, "from": player, "to": target, "pushed": index >= 0, "box_from": target, "box_to": next}
	if index >= 0:
		boxes[index] = next
		pushes += 1
	player = target
	steps += 1
	return result

func undo() -> bool:
	if history.is_empty(): return false
	var previous = history.pop_back()
	player = previous.player
	boxes.assign(previous.boxes)
	steps = previous.steps
	pushes = previous.pushes
	return true

func won() -> bool:
	if level.goals.is_empty(): return false
	for goal in level.goals:
		if goal not in boxes: return false
	return true

func occupied() -> int:
	var count = 0
	for goal in level.goals:
		if goal in boxes: count += 1
	return count
