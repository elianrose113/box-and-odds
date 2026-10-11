class_name CollectionTube
extends Control
## Each dot is one ball from the actual simulation.
var total = 10000.0
var target = 2600.0
var collected = 0.0
var slots = PackedVector2Array()
var packed_radius = 2.0
var packed_size = Vector2.ZERO
var packed_total = -1.0
var celebration_time = -1.0
var celebrated = false
const CELEBRATION_DURATION = 1.15
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(celebration_time >= 0)

func set_progress(amount: float, capacity: float, goal: float, _animate: bool = false) -> void:
	if total == maxf(capacity, 1.0) and target == clampf(goal, 0.0, maxf(capacity, 1.0)) and collected == clampf(amount, 0.0, maxf(capacity, 1.0)): return
	if amount < collected or total != maxf(capacity, 1.0) or target != clampf(goal, 0.0, maxf(capacity, 1.0)):
		celebrated = false
		celebration_time = -1.0
		set_process(false)
	total = maxf(capacity, 1.0)
	target = clampf(goal, 0.0, total)
	collected = clampf(amount, 0.0, total)
	if target > 0 and reached() and not celebrated:
		celebrated = true
		celebration_time = 0.0
		set_process(true)
	queue_redraw()

func inner_rect() -> Rect2:
	var width = minf(178, size.x - 32)
	return Rect2(Vector2((size.x - width) * 0.5, 145), Vector2(width, maxf(110, size.y - 223)))

func mouth_position() -> Vector2:
	return Vector2(size.x * 0.5, inner_rect().position.y)

# A narrow neck blends into the bulb; the bottom is a semicircle.
func half_width(y: float) -> float:
	var area = inner_rect()
	var radius = area.size.x * 0.5
	var bottom_center = area.end.y - radius
	if y >= bottom_center:
		return sqrt(maxf(0.0, radius * radius - pow(y - bottom_center, 2)))
	var neck_end = area.position.y + area.size.y * 0.32
	if y <= neck_end: return radius * 0.38
	var t = clampf((y - neck_end) / maxf(1, bottom_center - neck_end), 0, 1)
	return lerpf(radius * 0.38, radius, smoothstep(0, 1, t))

func contains_ball(position: Vector2, radius: float) -> bool:
	var area = inner_rect()
	if position.y - radius < area.position.y or position.y + radius > area.end.y: return false
	for angle in 16:
		var edge = position + Vector2.from_angle(angle * TAU / 16.0) * radius
		if absf(edge.x - area.get_center().x) > half_width(edge.y): return false
	return true

func make_slots(radius: float, limit: int) -> PackedVector2Array:
	var area = inner_rect()
	var result = PackedVector2Array()
	var y = area.end.y - radius - 1.0
	# Four staggered depth planes retain one sprite/slot per actual ball.
	# Their overlap depicts a filled volume instead of shrinking 1000 balls to dots.
	while y >= area.position.y + radius and result.size() < limit:
		for depth in 4:
			var py = y - depth * radius * 0.32
			var half = minf(half_width(py - radius), half_width(py + radius)) - radius
			var count = maxi(1, floori(half * 2.0 / (radius * 2.02)) + 1)
			if result.is_empty(): count = 1
			for column in count:
				var x = area.get_center().x + (column - (count - 1) * 0.5) * radius * 2.02
				if depth % 2 == 1 and count > 1: x += radius * 0.22
				var position = Vector2(x, py)
				if py - radius >= area.position.y and py + radius <= area.end.y and absf(x - area.get_center().x) <= half:
					result.append(position)
				if result.size() >= limit: break
			if result.size() >= limit: break
		y -= radius * 1.85
	return result

func ensure_slots() -> void:
	if packed_size == size and packed_total == total: return
	var low = 0.05
	var high = minf(inner_rect().size.x, inner_rect().size.y) * 0.45
	for attempt in 18:
		var middle = (low + high) * 0.5
		if make_slots(middle, int(total)).size() >= int(total): low = middle
		else: high = middle
	packed_radius = low
	slots = make_slots(packed_radius, int(total))
	packed_size = size
	packed_total = total

func ball_radius() -> float:
	ensure_slots()
	return packed_radius

func ball_position(index: int) -> Vector2:
	ensure_slots()
	return slots[clampi(index, 0, slots.size() - 1)]

func fill_ratio() -> float:
	return collected / total

func target_ratio() -> float:
	return target / total

func reached() -> bool:
	return collected + 0.000001 >= target

func text_at(text: String, y: float, font_size: int, color: Color) -> void:
	var font = get_theme_default_font()
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func shape(rect: Rect2, color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 0) -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 5
	box.corner_radius_top_right = 5
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_color = border
	box.set_border_width_all(width)
	draw_style_box(box, rect)

func glass_outline(inset: float = 0.0) -> PackedVector2Array:
	var area = inner_rect()
	var points = PackedVector2Array()
	for i in 81:
		var y = lerpf(area.position.y, area.end.y - inset, i / 80.0)
		points.append(Vector2(area.get_center().x - maxf(0, half_width(y) - inset), y))
	for i in range(80, -1, -1):
		var y = lerpf(area.position.y, area.end.y - inset, i / 80.0)
		points.append(Vector2(area.get_center().x + maxf(0, half_width(y) - inset), y))
	return points

func paper_card(rect: Rect2) -> void:
	draw_style_box(WorkshopArt.paper(0, 0, false, Color("#735139")), Rect2(rect.position + Vector2(3, 5), rect.size))
	draw_style_box(WorkshopArt.paper(0, 0), rect)
	# Small metal fasteners and a shaded cardboard edge.
	for x in [rect.position.x + 13, rect.end.x - 13]:
		draw_circle(Vector2(x, rect.position.y + 12), 2, Color("#8e7257"))

func _draw() -> void:
	var area = inner_rect()
	var outline = glass_outline()
	var center_x = area.get_center().x
	for side in [-1, 1]:
		var x = center_x + side * (area.size.x * 0.5 + 5) - 7
		draw_texture_rect(WorkshopArt.texture("wood"), Rect2(x, area.position.y + area.size.y * 0.42, 14, area.size.y * 0.58 + 12), false, Color("#9e7652"))
	draw_texture_rect(WorkshopArt.texture("wood"), Rect2(area.position.x - 12, area.end.y + 5, area.size.x + 24, 18), false)
	draw_colored_polygon(outline, Color(0.20, 0.27, 0.30, 0.48))
	draw_polyline(outline, Color("#382d28"), 9, true)
	draw_polyline(outline, Color("#c2c5bd"), 5, true)
	draw_polyline(glass_outline(3), Color(0.95, 0.98, 1, 0.55), 2, true)
	var radius = ball_radius()
	var extent = Vector2.ONE * radius
	var texture = BallVisual.get_texture()
	for ball in int(collected):
		var position = slots[ball]
		draw_texture_rect(texture, Rect2(position - extent, extent * 2), false, BallVisual.COLOR)
	# Reflection follows the curved surface and stays narrow so the balls remain visible.
	for side in [-1, 1]:
		var reflection = PackedVector2Array()
		for i in 45:
			var y = lerpf(area.position.y + 17, area.end.y - 22, i / 44.0)
			reflection.append(Vector2(center_x + side * maxf(0, half_width(y) - 10), y))
		draw_polyline(reflection, Color(0.94, 0.97, 1, 0.32), 8 if side == -1 else 4, true)
		draw_polyline(reflection, Color(1, 1, 0.96, 0.78), 2, true)
	draw_set_transform(mouth_position(), 0, Vector2(1, 0.28))
	var mouth_radius = half_width(area.position.y)
	draw_circle(Vector2.ZERO, mouth_radius + 5, Color("#434950"))
	draw_arc(Vector2.ZERO, mouth_radius + 5, 0, TAU, 64, Color("#eee7d8"), 5, true)
	draw_arc(Vector2.ZERO, mouth_radius, 0, PI, 32, Color("#aebdc6"), 3, true)
	draw_set_transform(Vector2.ZERO)
	var goal_y = ball_position(int(target) - 1).y - radius if target > 0 else area.end.y
	var marker = Color("#bb5534")
	draw_line(Vector2(center_x - half_width(goal_y) - 6, goal_y), Vector2(center_x + half_width(goal_y) + 6, goal_y), marker, 2)
	paper_card(Rect2(7, 5, size.x - 14, 114))
	text_at("已收集", 30, 17, WorkshopArt.INK)
	text_at("%d" % int(collected), 73, 42, current_count_color())
	text_at("/ %d" % int(target), 101, 22, WorkshopArt.INK)
	paper_card(Rect2(8, size.y - 49, size.x - 16, 45))
	text_at("目标 %d" % int(target), size.y - 19, 19, marker)

	draw_celebration()

func current_count_color() -> Color:
	return Color.BLACK if reached() else WorkshopArt.RED

func _process(delta: float) -> void:
	if celebration_time < 0: return
	celebration_time += delta
	if celebration_time >= CELEBRATION_DURATION:
		celebration_time = -1.0
		set_process(false)
	queue_redraw()

func draw_celebration() -> void:
	if celebration_time < 0: return
	var t = celebration_time
	var fade = 1.0 - smoothstep(0.5, CELEBRATION_DURATION, t)
	var origin = Vector2(size.x * 0.5, 60)
	var colors = [Color("#e6ae37"), Color("#bc513b"), Color("#438c9b"), Color("#ffe1a0")]
	if t < 0.45:
		draw_arc(origin, 30 + t * 100, 0, TAU, 48, Color(1, 0.76, 0.28, (1.0 - t / 0.45) * 0.8), 2, true)
	for i in 28:
		var angle = i * 2.399963
		var direction = Vector2.from_angle(angle)
		var speed = 38.0 + (i % 5) * 10.0
		var point = origin + direction * (34 + speed * t) + Vector2(0, -38 * t + 65 * t * t)
		var color: Color = colors[i % colors.size()]
		color.a = fade
		var axis = Vector2.from_angle(angle + t * (3 + i % 4)) * 3.5
		draw_line(point - axis, point + axis, color, 2.5, true)
		if i % 4 == 0:
			var cross_axis = axis.orthogonal() * 0.7
			draw_line(point - cross_axis, point + cross_axis, color, 1.5, true)
