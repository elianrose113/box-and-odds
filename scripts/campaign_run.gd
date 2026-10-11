class_name CampaignRun
extends FlowRun
var campaign: Array = []
var level_index = 0
var definition: Dictionary = {}
var tested = false
var remaining_balls = 0
var collected_total = 0
var batch_start_collected = 0
var batch_size = 0
var ball_paths: Array[PackedInt32Array] = []
var arrival_steps = PackedInt32Array()
var actual_arrivals = 0
var arrival_order: Array[int] = []
var expected_total = 0.0
var batch_expected = 0.0

func start(levels: Array, index: int = 0, test_mode: bool = false) -> void:
	campaign = levels.duplicate(true)
	level_index = index
	tested = test_mode
	load_level()

func load_level() -> void:
	definition = campaign[level_index].duplicate(true)
	width = int(definition.width)
	height = int(definition.height)
	entrance = FlowLevel.point(definition.entrance)
	exit_cell = FlowLevel.point(definition.exit)
	player = FlowLevel.point(definition.player)
	walls.clear()
	for p in definition.walls: walls.append(FlowLevel.point(p))
	definitions = definition.room_defs.duplicate(true)
	rooms.clear()
	for room in definition.rooms: rooms[FlowLevel.point(room.pos)] = room.kind
	balls = int(definition.balls)
	remaining_balls = balls
	collected_total = 0
	expected_total = 0.0
	batch_expected = 0.0
	batch_start_collected = 0
	batch_size = 0
	horizon = int(definition.horizon)
	base_budget = int(definition.budget)
	pushes_left = base_budget
	phase = "prepare"
	ball_paths.clear()
	arrival_steps.clear()
	actual_arrivals = 0
	arrival_order.clear()
	last_result = {}
	history.clear()
	round_start = snapshot()

func target() -> float:
	return float(definition.get("target", 0))

func begin_run(amount: int = -1) -> Dictionary:
	if phase != "prepare": return {}
	var count = remaining_balls if amount < 0 else amount
	if count < mini(100, remaining_balls) or count > remaining_balls or count <= 0: return {}
	batch_size = count
	batch_start_collected = collected_total
	remaining_balls -= count
	history.clear()
	phase = "running"
	var forecast = simulate()
	generate_balls()
	return forecast

func generate_balls(seed_value: int = -1) -> void:
	ball_paths.clear()
	arrival_steps.clear()
	actual_arrivals = 0
	arrival_order.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 74291 if seed_value < 0 else seed_value
	var transitions = kernel()
	var finish = index_of(exit_cell)
	var entry = index_of(entrance)
	var count = batch_size if batch_size > 0 else balls
	# Backward probabilities condition visual paths on arriving or not arriving.
	# Separate failure probabilities avoid cancellation when success is near 1.
	var success: Array[PackedFloat64Array] = []
	var failure: Array[PackedFloat64Array] = []
	var hit = PackedFloat64Array()
	var miss = PackedFloat64Array()
	hit.resize(width * height)
	miss.resize(width * height)
	miss.fill(1.0)
	hit[finish] = 1.0
	miss[finish] = 0.0
	success.append(hit)
	failure.append(miss)
	for step in horizon:
		hit = PackedFloat64Array()
		miss = PackedFloat64Array()
		hit.resize(width * height)
		miss.resize(width * height)
		for source in width * height:
			for destination in transitions[source]:
				var weight: float = transitions[source][destination]
				hit[source] += weight * success[step][destination]
				miss[source] += weight * failure[step][destination]
		success.append(hit)
		failure.append(miss)
	batch_expected = clampf(success[horizon][entry], 0, 1) * count
	# Round cumulative expectation, so splitting into batches cannot farm rounding.
	var quota = clampi(roundi(expected_total + batch_expected) - roundi(expected_total), 0, count)
	for ball in count:
		var must_arrive = ((ball + 1) * quota / count) > (ball * quota / count)
		var conditional = success if must_arrive else failure
		var source = entry
		var path = PackedInt32Array([source])
		var arrival = -1
		for step in horizon:
			if source != finish:
				var remaining = horizon - step - 1
				var weights: Dictionary = {}
				var total = 0.0
				for destination in transitions[source]:
					var weight = transitions[source][destination] * conditional[remaining][destination]
					if weight > 0:
						weights[destination] = weight
						total += weight
				var choice = rng.randf() * total
				var sum = 0.0
				var selected = source
				for destination in weights:
					selected = destination
					sum += weights[destination]
					if choice < sum: break
				source = selected
			path.append(source)
			if source == finish and arrival < 0: arrival = step + 1
		ball_paths.append(path)
		arrival_steps.append(arrival)
		if arrival >= 0:
			actual_arrivals += 1
			arrival_order.append(ball)
	arrival_order.sort_custom(func(a, b): return arrival_steps[a] < arrival_steps[b] if arrival_steps[a] != arrival_steps[b] else a < b)

func settle(_report: Dictionary) -> Dictionary:
	if phase != "running": return {}
	expected_total += batch_expected
	collected_total += actual_arrivals
	var passed = collected_total >= target()
	last_result = {"expected": collected_total, "arrived": collected_total, "batch_arrived": actual_arrivals, "batch_size": batch_size, "rate": float(actual_arrivals) / batch_size, "passed": passed, "target": target()}
	phase = "result" if passed or remaining_balls == 0 else "between"
	return last_result

func continue_batch() -> bool:
	if phase != "between": return false
	phase = "prepare"
	ball_paths.clear()
	arrival_steps.clear()
	arrival_order.clear()
	history.clear()
	actual_arrivals = 0
	batch_size = 0
	batch_start_collected = collected_total
	return true

func reset_preparation() -> bool:
	if phase not in ["prepare", "between"]: return false
	load_level()
	return true

func has_next() -> bool:
	return level_index + 1 < campaign.size() and not tested

func continue_campaign() -> bool:
	if phase != "result" or not last_result.get("passed", false): return false
	if not has_next():
		phase = "finished"
		return false
	level_index += 1
	load_level()
	return true

func retry_level() -> bool:
	if phase != "result": return false
	load_level()
	return true
