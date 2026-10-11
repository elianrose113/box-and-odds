class_name BoardView
extends Control
signal cell_pressed(cell: Vector2i, erase: bool)
signal stroke_finished
signal animation_finished
var level: LevelData
var state: BoardState
var editable = false
var show_grid = true
var facing = Vector2i.DOWN
var motion: Dictionary = {}
var elapsed = 0.0
var duration = 0.14
var bump = 0.0
var clock = 0.0
var hover = Vector2i(-1, -1)
var painting = false
var last_painted = Vector2i(-999, -999)
var last_erase = false
var cell_size = 48.0
var origin = Vector2.ZERO
const FLOOR_A = Color("#223340")
const FLOOR_B = Color("#263947")
const MINT = Color("#83ddc1")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func(): hover = Vector2i(-1, -1); queue_redraw())
	resized.connect(queue_redraw)

func configure(source: LevelData, board_state: BoardState = null, editing: bool = false) -> void:
	level = source
	state = board_state
	editable = editing
	motion.clear()
	facing = Vector2i.DOWN
	queue_redraw()

func busy() -> bool:
	return not motion.is_empty()

func animate(result: Dictionary, direction: Vector2i) -> void:
	facing = direction
	if not result.get("ok", false):
		bump = 0.12
	else:
		motion = result
		elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	bump = maxf(0.0, bump - delta)
	if busy():
		elapsed += delta
		if elapsed >= duration:
			motion.clear()
			animation_finished.emit()
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		painting = false
		last_painted = Vector2i(-999, -999)
		stroke_finished.emit()
	queue_redraw()

func layout_board() -> void:
	if level == null: return
	cell_size = floorf(minf((size.x - 40.0) / level.width, (size.y - 40.0) / level.height))
	cell_size = maxf(cell_size, 4.0)
	origin = (size - Vector2(level.width, level.height) * cell_size) * 0.5

func cell_at(pos: Vector2) -> Vector2i:
	layout_board()
	return Vector2i(floori((pos.x - origin.x) / cell_size), floori((pos.y - origin.y) / cell_size))

func _gui_input(event: InputEvent) -> void:
	if not editable or level == null: return
	if event is InputEventMouseMotion:
		hover = cell_at(event.position)
		if painting: paint_cell(hover, Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			painting = true
			paint_cell(cell_at(event.position), event.button_index == MOUSE_BUTTON_RIGHT)
		else:
			painting = false
			last_painted = Vector2i(-999, -999)
			stroke_finished.emit()
		accept_event()

func paint_cell(p: Vector2i, erase: bool) -> void:
	if not level.inside(p) or (p == last_painted and erase == last_erase): return
	# Interpolate between mouse samples so a fast drag leaves no holes.
	if level.inside(last_painted):
		var distance = maxi(absi(p.x - last_painted.x), absi(p.y - last_painted.y))
		for i in range(1, distance):
			var between = Vector2i(Vector2(last_painted).lerp(Vector2(p), float(i) / distance).round())
			cell_pressed.emit(between, erase)
	cell_pressed.emit(p, erase)
	last_painted = p
	last_erase = erase

func box_rect(rect: Rect2, color: Color, radius: int = 8, border: Color = Color.TRANSPARENT, width: int = 0) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	draw_style_box(style, rect)

func center(p: Vector2) -> Vector2:
	return origin + (p + Vector2(0.5, 0.5)) * cell_size

func _draw() -> void:
	box_rect(Rect2(Vector2.ZERO, size), Color("#142330"), 20)
	if level == null: return
	layout_board()
	var s = cell_size
	box_rect(Rect2(origin - Vector2(7, 7), Vector2(level.width, level.height) * s + Vector2(14, 14)), Color("#0d1922"), 12)
	for y in level.height:
		for x in level.width:
			var p = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(p) * s + Vector2.ONE, Vector2.ONE * (s - 2))
			var tile_color = FLOOR_A if (x + y) % 2 == 0 else FLOOR_B
			box_rect(rect, tile_color, maxi(1, int(s * 0.07)))
			if p in level.walls:
				box_rect(rect, Color("#0c1822"), int(s * 0.1))
				var wall = rect.grow(-s * 0.035)
				wall.position.y -= s * 0.04
				box_rect(wall, Color("#526976"), int(s * 0.09))
				draw_line(wall.position + Vector2(s * 0.1, s * 0.12), wall.position + Vector2(s * 0.8, s * 0.12), Color("#708994"), maxf(1, s * 0.04))
				draw_line(wall.position + Vector2(0, s * 0.52), wall.position + Vector2(s * 0.93, s * 0.52), Color("#3f5562"), maxf(1, s * 0.035))
			elif p in level.goals:
				var c = center(Vector2(p))
				draw_circle(c, s * 0.25, Color("#335e5d"))
				draw_arc(c, s * 0.23, 0, TAU, 32, MINT, maxf(1.5, s * 0.035))
				draw_circle(c, s * 0.075, MINT)
			if editable and show_grid:
				draw_rect(rect, Color(0.65, 0.8, 0.85, 0.08), false, 1)
	var crates: Array[Vector2i] = level.boxes if state == null else state.boxes
	var t = clampf(elapsed / duration, 0.0, 1.0)
	var eased = t * t * (3.0 - 2.0 * t)
	for p in crates:
		var visual = Vector2(p)
		if busy() and motion.pushed and p == motion.box_to:
			visual = Vector2(motion.box_from).lerp(Vector2(motion.box_to), eased)
		draw_crate(visual, p in level.goals)
	var actor = level.player if state == null else state.player
	if level.inside(actor):
		var visual = Vector2(actor)
		if busy(): visual = Vector2(motion.from).lerp(Vector2(motion.to), eased)
		if bump > 0: visual += Vector2(facing) * sin(bump / 0.12 * PI) * 0.075
		draw_actor(visual, t)
	if editable and level.inside(hover):
		var rect = Rect2(origin + Vector2(hover) * s, Vector2.ONE * s)
		draw_rect(rect.grow(-1), Color(0.5, 0.9, 0.78, 0.15))
		draw_rect(rect.grow(-2), MINT, false, 2)

func draw_crate(p: Vector2, on_goal: bool) -> void:
	var s = cell_size
	var rect = Rect2(origin + p * s + Vector2.ONE * s * 0.12, Vector2.ONE * s * 0.76)
	box_rect(Rect2(rect.position + Vector2(0, s * 0.065), rect.size), Color("#122029"), int(s * 0.09))
	var wood = Color("#91dbc0") if on_goal else Color("#e5b275")
	var ink = Color("#387e6d") if on_goal else Color("#9c693c")
	box_rect(rect, wood, int(s * 0.09))
	draw_rect(rect.grow(-s * 0.11), ink, false, maxf(1, s * 0.055))
	draw_line(rect.position + Vector2.ONE * s * 0.12, rect.end - Vector2.ONE * s * 0.12, ink, maxf(1, s * 0.055))
	draw_line(rect.position + Vector2(s * 0.64, s * 0.12), rect.position + Vector2(s * 0.12, s * 0.64), ink, maxf(1, s * 0.055))
	if on_goal:
		var c = rect.get_center()
		draw_circle(c, s * 0.16, Color("#24564e"))
		draw_polyline(PackedVector2Array([c + Vector2(-0.085, 0) * s, c + Vector2(-0.015, 0.065) * s, c + Vector2(0.10, -0.075) * s]), Color("#b9ffe6"), maxf(1.5, s * 0.035), true)

func draw_actor(p: Vector2, t: float) -> void:
	var s = cell_size
	var c = center(p)
	var forward = Vector2(facing)
	var side = Vector2(-forward.y, forward.x)
	var walking = busy()
	var pushing = walking and motion.get("pushed", false)
	var stride = sin(t * TAU) * s * (0.085 if pushing else 0.13) if walking else 0.0
	var bounce = -absf(sin(t * TAU)) * s * 0.025 if walking else sin(clock * 2.0) * s * 0.008
	draw_set_transform(c + Vector2(0, s * 0.24), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, s * 0.29, Color(0.025, 0.04, 0.055, 0.5))
	draw_set_transform(Vector2.ZERO)
	var body = c + Vector2(0, bounce)
	if pushing: body += forward * s * 0.065
	for sign_value in [-1, 1]:
		var foot = c + side * s * 0.13 * sign_value + forward * stride * sign_value + Vector2(0, s * 0.23)
		box_rect(Rect2(foot - Vector2(s * 0.075, s * 0.05), Vector2(s * 0.15, s * 0.13)), Color("#172938"), int(s * 0.04))
	box_rect(Rect2(body + Vector2(-0.23, -0.06) * s, Vector2(0.46, 0.39) * s), Color("#f1c35a"), int(s * 0.12))
	# Four-direction pushing: both arms extend along facing; walking swings opposite arms.
	for sign_value in [-1, 1]:
		var shoulder = body + side * s * 0.20 * sign_value + Vector2(0, s * 0.07)
		var hand = shoulder + forward * (s * 0.24 if pushing else stride * -sign_value) + Vector2(0, s * 0.04)
		draw_line(shoulder, hand, Color("#e5a545"), s * 0.13, true)
		draw_circle(hand, s * 0.068, Color("#ffe1bc"))
	var head = body + Vector2(0, -s * 0.19) + forward * s * 0.025
	draw_circle(head, s * 0.225, Color("#ffd9af"))
	draw_arc(head, s * 0.225, PI, TAU, 20, Color("#284758"), s * 0.12, true)
	if facing == Vector2i.UP:
		draw_circle(head + Vector2(0, -s * 0.02), s * 0.205, Color("#345467"))
	else:
		var gaze = Vector2(facing.x, 0) * s * 0.07
		for sign_value in [-1, 1]:
			if facing.x != 0 and sign_value == -facing.x: continue
			draw_circle(head + gaze + Vector2(sign_value * s * 0.07, s * 0.035), s * 0.025, Color("#233444"))
		draw_line(head + gaze + Vector2(-s * 0.03, s * 0.11), head + gaze + Vector2(s * 0.035, s * 0.11), Color("#b97e64"), maxf(1, s * 0.025))
	box_rect(Rect2(head + Vector2(-s * 0.235, -s * 0.18), Vector2(s * 0.47, s * 0.09)), Color("#77cfbe"), int(s * 0.03))
