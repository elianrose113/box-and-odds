class_name LevelDifficulty
extends RefCounted
# Bounded deterministic search: an estimate, not a proof of optimality/solvability.
static var cache: Dictionary = {}
const LIMIT = 2000
static func score(data: Dictionary) -> int:
	var key = JSON.stringify(data).sha256_text()
	if cache.has(key): return cache[key]
	var value = compute(data)
	if cache.size() >= 256: cache.clear()
	cache[key] = value
	return value

static func compute(data: Dictionary) -> int:
	return int(analyze(data).get("score", 0))

static func layout_key(rooms: Dictionary) -> String:
	var cells = rooms.keys()
	cells.sort()
	var parts: Array = []
	for cell in cells: parts.append([cell.x, cell.y, rooms[cell]])
	return JSON.stringify(parts)

static func reachable(run: FlowRun, rooms: Dictionary, player: Vector2i) -> Dictionary:
	var visited: Dictionary = {player: true}
	var queue: Array[Vector2i] = [player]
	var cursor = 0
	var anchor = run.index_of(player)
	while cursor < queue.size():
		var cell = queue[cursor]
		cursor += 1
		anchor = mini(anchor, run.index_of(cell))
		for direction in FlowRun.DIRS:
			var next = cell + direction
			if run.floor_cell(next) and not rooms.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return {"cells": visited, "anchor": anchor}

static func neighbor_table(run: FlowRun) -> PackedInt32Array:
	var table = PackedInt32Array()
	table.resize(run.width * run.height * 4)
	for index in run.width * run.height:
		var cell = Vector2i(index % run.width, index / run.width)
		for d in 4:
			var next = cell + FlowRun.DIRS[d]
			table[index * 4 + d] = run.index_of(next) if run.floor_cell(next) else index
	return table

# Score only the final absorption probability; do not allocate animation frames.
static func exit_rate(run: FlowRun, rooms: Dictionary, neighbors: PackedInt32Array) -> float:
	var count = run.width * run.height
	var weights = PackedFloat64Array()
	weights.resize(count * 4)
	weights.fill(0.25)
	for cell in rooms:
		var probabilities: Array = run.definitions[rooms[cell]].p
		for d in 4: weights[run.index_of(cell) * 4 + d] = probabilities[d]
	var current = PackedFloat64Array()
	var next = PackedFloat64Array()
	current.resize(count)
	next.resize(count)
	current[run.index_of(run.entrance)] = 1.0
	var finish = run.index_of(run.exit_cell)
	for step in run.horizon:
		next.fill(0.0)
		next[finish] = current[finish]
		for source in count:
			var mass = current[source]
			if source == finish or mass <= 0: continue
			var offset = source * 4
			for d in 4: next[neighbors[offset + d]] += mass * weights[offset + d]
		var swap = current
		current = next
		next = swap
	return current[finish]

static func analyze(data: Dictionary, limit: int = LIMIT) -> Dictionary:
	if not FlowLevel.validate(data).is_empty(): return {}
	limit = maxi(1, limit)
	var run = CampaignRun.new()
	run.start([data], 0, true)
	var neighbors = neighbor_table(run)
	var initial = exit_rate(run, run.rooms, neighbors)
	var best = initial
	var best_rooms = run.rooms.duplicate()
	var best_player = run.player
	var best_moves: Array = []
	var goal = float(data.target) / maxf(1, data.balls)
	var initial_key = layout_key(run.rooms)
	var reach = reachable(run, run.rooms, run.player)
	var initial_state_key = initial_key + ":" + str(reach.anchor)
	var frontier: Array = [{"rooms": run.rooms.duplicate(), "player": run.player, "depth": 0, "rate": initial, "key": initial_state_key, "reach": reach.cells, "moves": []}]
	# A shorter route to the same layout AND player region must be reopened.
	var seen: Dictionary = {initial_state_key: 0}
	var rates: Dictionary = {initial_key: initial}
	var examined = 1
	var expanded = 0
	var max_depth = 0
	var limited = false
	var bad_moves = 0
	var total_moves = 0
	var required = 0 if initial >= goal else int(data.budget) + 1
	var best_depth = 0
	var dependencies = 0
	while not frontier.is_empty() and not limited:
		# Retain every branch. Every fourth expansion favors shallow states,
		# including initially worse layouts; other expansions favor higher rates.
		var choose = 0
		var breadth_turn = expanded % 4 == 3
		for i in range(1, frontier.size()):
			var candidate: Dictionary = frontier[i]
			var incumbent: Dictionary = frontier[choose]
			if breadth_turn:
				if candidate.depth < incumbent.depth: choose = i
			elif candidate.rate > incumbent.rate or (candidate.rate == incumbent.rate and candidate.depth < incumbent.depth): choose = i
		var state: Dictionary = frontier[choose]
		frontier.remove_at(choose)
		if state.depth > seen[state.key] or state.depth >= int(data.budget): continue
		expanded += 1
		for box in state.rooms:
			for direction in FlowRun.DIRS:
				var destination: Vector2i = box + direction
				if not state.reach.has(box - direction) or not run.floor_cell(destination) or state.rooms.has(destination) or destination in [run.entrance, run.exit_cell]: continue
				var rooms: Dictionary = state.rooms.duplicate()
				rooms[destination] = rooms[box]
				rooms.erase(box)
				var key = layout_key(rooms)
				var region = reachable(run, rooms, box)
				var state_key = key + ":" + str(region.anchor)
				var depth: int = state.depth + 1
				if seen.has(state_key) and int(seen[state_key]) <= depth: continue
				if not rates.has(key):
					if examined >= limit:
						limited = true
						break
					rates[key] = exit_rate(run, rooms, neighbors)
					examined += 1
				var rate: float = rates[key]
				seen[state_key] = depth
				max_depth = maxi(max_depth, depth)
				var moves: Array = state.moves.duplicate()
				moves.append({"from": FlowLevel.pair(box), "to": FlowLevel.pair(destination)})
				total_moves += 1
				if rate < state.rate - 0.002: bad_moves += 1
				if rate > best or (rate == best and depth < best_depth):
					best = rate
					best_depth = depth
					best_rooms = rooms.duplicate()
					best_player = box
					best_moves = moves
				if rate >= goal: required = mini(required, depth)
				if state.rooms.has(destination + direction) or state.rooms.has(box - direction * 2): dependencies += 1
				if depth < int(data.budget):
					frontier.append({"rooms": rooms, "player": box, "depth": depth, "rate": rate, "key": state_key, "reach": region.cells, "moves": moves})
			if limited: break
	var effort = clampf(float(required) / maxf(1, data.budget), 0, 1) * 0.65 + clampf(required / 12.0, 0, 1) * 0.35
	var pressure = clampf(goal / maxf(best, 0.00001), 0, 1)
	var tolerance = float(bad_moves) / maxf(1, total_moves)
	var planning = clampf(best_depth / 12.0 * 0.6 + float(dependencies) / maxf(1, total_moves) * 0.4, 0, 1)
	var surplus_balls = maxf(0, data.balls - float(data.target) / maxf(best, 0.00001))
	var testing = 1.0 / (1.0 + surplus_balls / 100.0)
	# When the initial layout already suffices, arranging boxes is optional.
	if initial >= goal: effort = 0; tolerance *= 0.25; planning *= 0.25
	var value = clampi(roundi(25 * effort + 25 * pressure + 20 * tolerance + 20 * planning + 10 * testing), 0, 100)
	if data.target == 0: value = 0
	var layout: Array = []
	for cell in best_rooms: layout.append({"pos": FlowLevel.pair(cell), "kind": best_rooms[cell]})
	return {"score": value, "rate": best, "expected": best * data.balls, "rooms": layout, "player": FlowLevel.pair(best_player), "pushes": best_depth, "examined": examined, "expanded": expanded, "max_depth": max_depth, "stop_reason": "layout_limit" if limited else "exhausted", "complete": not limited, "limit": limit, "moves": best_moves}

