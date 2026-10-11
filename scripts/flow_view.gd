class_name FlowView
extends BoardView
signal selected_cell(cell: Vector2i)
var run: FlowRun
var report: Dictionary = {}
var frame_position = 0.0:
	set(value):
		if frame_position != value:
			frame_position = value
			queue_redraw()
var particles_enabled = true
var selection = Vector2i(-1, -1):
	set(value):
		selection = value
		queue_redraw()
var paths: Array[PackedInt32Array] = []
var preparing = true:
	set(value):
		if preparing != value:
			preparing = value
			queue_redraw()
var cached_step = -1
var cached_size = -1.0
var cached_origin = Vector2.ZERO
var starts = PackedVector2Array()
var ends = PackedVector2Array()
var render_positions = PackedVector2Array()
var live_counts = PackedInt32Array()
var heat = PackedFloat32Array()
var heat_clock = 0.0
var preparation_field = PackedFloat32Array()

func _init() -> void:
	duration = 0.22
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func configure_run(model: FlowRun) -> void:
	run = model
	level = LevelData.new()
	level.width = model.width
	level.height = model.height
	level.walls.assign(model.walls)
	editable = false
	queue_redraw()

func set_report(value: Dictionary) -> void:
	cached_step = -1
	report = value
	paths = run.ball_paths if run is CampaignRun else []
	live_counts.resize(run.width * run.height)
	live_counts.fill(0)
	heat.resize(run.width * run.height)
	heat.fill(0)
	heat_clock = clock
	build_preparation_field()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if editable:
		var old_hover = hover
		super._gui_input(event)
		if hover != old_hover: queue_redraw()
		return
	if event is InputEventMouseMotion:
		var next_hover = cell_at(event.position)
		if hover != next_hover:
			hover = next_hover
			queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = cell_at(event.position)
		if run.floor_cell(cell):
			selection = cell
			selected_cell.emit(cell)
			accept_event()

func layout_board() -> void:
	if level == null: return
	cell_size = maxf(4, floorf(minf((size.x - 38) / 10.0, (size.y - 64) / (8.0 * 0.78))))
	origin = (size - Vector2(level.width * cell_size, level.height * cell_size * 0.78)) * 0.5 + Vector2(0, cell_size * 0.08)

func center(p: Vector2) -> Vector2:
	return origin + Vector2((p.x + 0.5) * cell_size, (p.y + 0.5) * cell_size * 0.78)

func grid_position(position: Vector2) -> Vector2:
	return (position - origin) / Vector2(cell_size, cell_size * 0.78)

func cell_at(position: Vector2) -> Vector2i:
	layout_board()
	var p = grid_position(position)
	return Vector2i(floori(p.x), floori(p.y))

func tile_rect(p: Vector2) -> Rect2:
	return Rect2(origin + Vector2(p.x * cell_size, p.y * cell_size * 0.78), Vector2(cell_size, cell_size * 0.78))

func _draw() -> void:
	if run == null: return
	layout_board()
	var s = cell_size
	var board = Rect2(origin, Vector2(run.width * s, run.height * s * 0.78))
	box_rect(Rect2(board.position + Vector2(3, 10), board.size + Vector2(0, 8)), Color(0.13, 0.08, 0.05, 0.5), 6)
	draw_texture_rect(WorkshopArt.texture("wood"), board.grow(7), false, Color("#9d7955"))
	if not preparing and not paths.is_empty(): update_live_density()
	for y in run.height:
		for x in run.width:
			var cell = Vector2i(x, y)
			var rect = tile_rect(Vector2(cell)).grow(-0.6)
			var color = Color("#e9dbbd") if (x + y) % 2 == 0 else Color("#d9cfb9")
			if preparing and not preparation_field.is_empty(): color = field_color(color, preparation_field[run.index_of(cell)])
			elif not preparing and not heat.is_empty(): color = density_color(color, heat[run.index_of(cell)])
			draw_texture_rect(WorkshopArt.texture("floor"), rect, false, color)
			if cell in [run.entrance, run.exit_cell]:
				var fixture = "entrance" if cell == run.entrance else "exit"
				draw_texture_rect(WorkshopArt.texture(fixture), rect.grow(-s * 0.03), false)

			elif not run.rooms.has(cell) and cell not in run.walls and hover == cell:
				draw_probabilities(Vector2(cell), [0.25, 0.25, 0.25, 0.25], Color(0.20, 0.16, 0.12, 0.55), false)
	var progress = clampf(elapsed / duration, 0, 1)
	var eased = smoothstep(0.0, 1.0, progress)
	var objects: Array[Dictionary] = []
	for cell in run.walls: objects.append({"p": Vector2(cell), "kind": "wall"})
	for cell in run.rooms:
		var position = Vector2(cell)
		if busy() and motion.pushed and cell == motion.box_to: position = Vector2(motion.box_from).lerp(Vector2(motion.box_to), eased)
		objects.append({"p": position, "kind": "crate", "room": run.rooms[cell]})
	if preparing:
		var actor = Vector2(run.player)
		if busy(): actor = Vector2(motion.from).lerp(Vector2(motion.to), eased)
		if bump > 0: actor += Vector2(facing) * sin(bump / 0.12 * PI) * 0.075
		objects.append({"p": actor, "kind": "actor"})
	objects.sort_custom(func(a, b): return a.p.y < b.p.y if not is_equal_approx(a.p.y, b.p.y) else a.p.x < b.p.x)
	for object in objects:
		if object.kind == "crate": draw_room(object.p, object.room)
		elif object.kind == "actor": draw_worker(object.p, progress)
		else:
			var rect = tile_rect(object.p)
			rect.position.y -= s * 0.19
			rect.size.y += s * 0.19
			draw_texture_rect(WorkshopArt.texture("wall"), rect, false, Color.WHITE)
	for cell in [run.entrance, run.exit_cell]:
		var tag_center = center(Vector2(cell))
		var tag = Rect2(tag_center + Vector2(-0.34, 0.09) * s, Vector2(0.68, 0.25) * s)
		draw_style_box(WorkshopArt.paper(0, 0), tag)
		cell_text(cell, "入口" if cell == run.entrance else "出口", WorkshopArt.INK, 0.37)
	if not preparing and particles_enabled and not report.is_empty():
		var current_frame = clampi(floori(frame_position), 0, int(report.steps))
		var extent = Vector2.ONE * ball_radius()
		var texture = BallVisual.get_texture()
		var exit_index = run.index_of(run.exit_cell)
		for particle in paths.size():
			if paths[particle][current_frame] == exit_index: continue
			draw_texture_rect(texture, Rect2(render_positions[particle] - extent, extent * 2), false, BallVisual.COLOR)
	if run.inside(selection): draw_rect(tile_rect(Vector2(selection)).grow(-2), Color("#7f3523"), false, 2)
	if run.inside(hover) and hover not in run.walls: draw_rect(tile_rect(Vector2(hover)).grow(-2), Color(1, 0.95, 0.78, 0.75), false, 2)

func draw_worker(p: Vector2, progress: float) -> void:
	var row = {Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3}.get(facing, 0)
	var frame = mini(1, int(progress * 2)) if busy() else 0
	if busy() and motion.get("pushed", false): frame += 2
	var texture = WorkshopArt.texture("worker_%d_%d" % [row, frame] if busy() else "worker_idle_%d" % row)
	var height = cell_size * 0.94
	var width = height * texture.get_width() / texture.get_height()
	var feet = center(p) + Vector2(0, cell_size * 0.22)
	draw_set_transform(feet + Vector2(0, 1), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, cell_size * 0.25, Color(0.16, 0.10, 0.05, 0.25))
	draw_set_transform(Vector2.ZERO)
	var bounce = 0.0
	draw_texture_rect(texture, Rect2(feet + Vector2(-width * 0.5, -height + bounce), Vector2(width, height)), false)

# Relative average occupancy during the middle and later steps. The absorbing
# exit is excluded so this conveys spatial congestion, not the success score.
func build_preparation_field() -> void:
	preparation_field.resize(run.width * run.height)
	preparation_field.fill(0)
	if report.is_empty(): return
	var first = maxi(1, int(report.steps) / 4)
	var peak = 0.0
	for step in range(first, report.frames.size()):
		for index in preparation_field.size():
			if index == run.index_of(run.exit_cell) or index == run.index_of(run.entrance): continue
			preparation_field[index] += report.frames[step][index]
	for value in preparation_field: peak = maxf(peak, value)
	if peak > 0:
		var low = peak
		for value in preparation_field:
			if value > 0: low = minf(low, value)
		for index in preparation_field.size():
			if preparation_field[index] <= 0: continue
			preparation_field[index] = 0.08 + 0.92 * (preparation_field[index] - low) / (peak - low) if peak > low else 0.5

func field_color(base: Color, intensity: float) -> Color:
	if intensity <= 0.005: return base
	var tint = Color("#247d9b").lerp(Color("#d49b45"), intensity * 2.0) if intensity < 0.5 else Color("#d49b45").lerp(Color("#e75b40"), (intensity - 0.5) * 2.0)
	return base.lerp(tint, 0.85)

func density_color(base: Color, count: float) -> Color:
	if count <= 0.01: return base
	var intensity = clampf(log(1.0 + count) / log(1.0 + maxf(run.balls * 0.08, 8.0)), 0.0, 1.0)
	var tint = Color("#337b86").lerp(Color("#a47a3d"), intensity * 2.0) if intensity < 0.5 else Color("#a47a3d").lerp(Color("#ad513e"), (intensity - 0.5) * 2.0)
	return base.lerp(tint, minf(0.85, intensity * 1.4))

func update_live_density() -> void:
	var step = clampi(floori(frame_position), 0, int(report.steps))
	cache_positions(step)
	var fraction = clampf(frame_position - step, 0.0, 1.0)
	render_positions.resize(paths.size())
	live_counts.fill(0)
	var exit_index = run.index_of(run.exit_cell)
	for ball in paths.size():
		var position = starts[ball].lerp(ends[ball], fraction)
		render_positions[ball] = position
		if paths[ball][step] == exit_index: continue
		var grid = grid_position(position)
		var cell = Vector2i(floori(grid.x), floori(grid.y))
		if run.inside(cell): live_counts[run.index_of(cell)] += 1
	var blend = 1.0 - exp(-maxf(clock - heat_clock, 0.0) * 12.0)
	for index in heat.size(): heat[index] = lerpf(heat[index], float(live_counts[index]), blend)
	heat_clock = clock

func cache_positions(step: int) -> void:
	if cached_step == step and cached_size == cell_size and cached_origin == origin: return
	starts.resize(paths.size())
	ends.resize(paths.size())
	for ball in paths.size():
		starts[ball] = ball_position_at(ball, float(step))
		ends[ball] = ball_position_at(ball, float(step + 1))
	cached_step = step
	cached_size = cell_size
	cached_origin = origin

func ball_radius() -> float:
	return clampf(cell_size * 0.085, 3.8, 7.0)

# Stable per-step waypoints spread over the tile. Interpolation stays inside
# the union of the two adjacent floor cells, including the ball's radius.
func ball_offset(ball: int, step: int) -> Vector2:
	var key = float(ball + 1) * 12.9898 + float(step) * 78.233
	var x = fposmod(sin(key) * 43758.5453, 1.0)
	var y = fposmod(sin(key + 39.425) * 19642.349, 1.0)
	var span = Vector2.ONE * 0.5 - Vector2.ONE * (ball_radius() + 2.0) / Vector2(cell_size, cell_size * 0.78)
	return (Vector2(x, y) * 2.0 - Vector2.ONE) * span.clamp(Vector2.ZERO, Vector2.ONE)

func ball_position_at(ball: int, time: float) -> Vector2:
	var path = paths[ball]
	var step = clampi(floori(time), 0, path.size() - 1)
	var next = mini(step + 1, path.size() - 1)
	var from = Vector2(path[step] % run.width, path[step] / run.width) + ball_offset(ball, step)
	var to = Vector2(path[next] % run.width, path[next] / run.width) + ball_offset(ball, next)
	var fraction = clampf(time - step, 0.0, 1.0)
	return center(from.lerp(to, fraction))

func cell_text(cell: Vector2i, text: String, color: Color, vertical: float) -> void:
	var font = get_theme_default_font()
	var font_size = maxi(10, int(cell_size * 0.19))
	var width_text = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos = center(Vector2(cell)) + Vector2(-width_text * 0.5, cell_size * vertical * 0.78)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_room(p: Vector2, kind: String) -> void:
	var spec: Dictionary = run.room_spec(kind)
	var rect = tile_rect(p).grow(-cell_size * 0.03)
	rect.position.y -= cell_size * 0.19
	rect.size.y += cell_size * 0.19
	draw_texture_rect(WorkshopArt.texture("crate"), rect, false)
	var stripe = Rect2(Vector2(rect.position.x + cell_size * 0.18, rect.end.y - cell_size * 0.095), Vector2(cell_size * 0.58, cell_size * 0.035))
	draw_rect(stripe, Color(spec.color).darkened(0.1))
	draw_probabilities(p, spec.p, WorkshopArt.INK)

func draw_probabilities(p: Vector2, probabilities: Array, color: Color, raised: bool = true) -> void:
	var s = cell_size
	var c = center(p) - Vector2(0, s * 0.19 if raised else 0)
	var font = get_theme_default_font()
	var fs = maxi(8, int(s * 0.16))
	var offsets = [Vector2(0, -0.15), Vector2(0.24, 0.055), Vector2(0, 0.25), Vector2(-0.24, 0.055)]
	for i in 4:
		var text = FlowLevel.percent(float(probabilities[i]))
		var text_size = fs
		while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x > s * 0.43 and text_size > 6: text_size -= 1
		var tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(font, c + offsets[i] * s - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, color)
func _process(delta: float) -> void:
	clock += delta
	var animating = busy() or bump > 0
	bump = maxf(0, bump - delta)
	if busy():
		elapsed += delta
		if elapsed >= duration:
			motion.clear()
			animation_finished.emit()
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		painting = false
		last_painted = Vector2i(-999, -999)
		stroke_finished.emit()
	if animating: queue_redraw()
