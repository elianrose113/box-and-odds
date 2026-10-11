class_name CampaignGame
extends FlowGame
var level_list: Array = []
var start_index = 0
var test_mode = false
var leave_action: Callable
var layout: HBoxContainer
var rate_label: Label
var count_label: Label
var target_label: Label
var ball_label: Label
var horizon_label: Label
var budget_label: Label
var transfer_layer: Control
var stage_label: Label
var batch_label: Label
var batch_amount = 100
var decrease_button: Button
var increase_button: Button
var batch_controls: VBoxContainer
var collection_tube: CollectionTube
var leave_button: Button
var intro_overlay: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	model = CampaignRun.new()
	model.start(level_list, start_index, test_mode)
	build_ui()
	refresh_report(false)
	refresh_controls()
	if not test_mode and ui.progression_enabled and start_index == 0 and not ui.progress.intro_seen():
		show_intro()

func build_ui() -> void:
	root_box = VBoxContainer.new()
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout = ui.row(root_box)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 16)
	var left_panel = PanelContainer.new()
	left_panel.custom_minimum_size.x = 285
	left_panel.add_theme_stylebox_override("panel", WorkshopArt.paper(18, 18, false, Color("#d2bda1")))
	layout.add_child(left_panel)
	root_box.draw.connect(func(): root_box.draw_rect(Rect2(0, 0, left_panel.size.x, root_box.size.y), Color("#b69a75")))
	var sidebar = ui.column(left_panel)
	var stats_scroll = ScrollContainer.new()
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(stats_scroll)
	var left = ui.column(stats_scroll)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	ui.label("关卡 %02d" % (model.level_index + 1), left, 19, WorkshopArt.INK)
	target_label = metric(left, "目标数量", Color("#69502c"), "0", 56)
	if test_mode:
		var forecasts = ui.row(left)
		rate_label = metric(forecasts, "预计到达率", Color("#ad404b"), "0.00%", 27)
		count_label = metric(forecasts, "预计到达数量", Color("#287aaf"), "0", 27)
	ball_label = metric(left, "剩余小球", Color("#253d4b"), "0", 25)
	horizon_label = metric(left, "小球移动轮次", Color("#253d4b"), "0", 25)
	budget_label = metric(left, "剩余推动", Color("#253d4b"), "0", 25)
	selection_text = ui.paragraph("", left, 13)
	left = ui.column(sidebar)
	batch_controls = ui.column(left)
	ui.label("本批投放", batch_controls, 14)
	var batch_row = ui.row(batch_controls)
	decrease_button = ui.button("−", batch_row, change_batch.bind(-100))
	decrease_button.custom_minimum_size.x = 48
	batch_label = ui.label("100 / 1000", batch_row, 20)
	batch_label.clip_text = true
	batch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	batch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	batch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	increase_button = ui.button("+", batch_row, change_batch.bind(100))
	increase_button.custom_minimum_size.x = 48
	run_button = ui.button("开始放球", left, primary_action, true)
	run_button.add_theme_stylebox_override("disabled", WorkshopArt.paper(14, 10, true, Color("#bb9b82")))
	run_button.add_theme_color_override("font_disabled_color", Color("#ead7b9"))
	var actions = ui.row(left)
	reset_button = ui.button("重新开始", actions, reset_preparation)
	leave_button = ui.button("返回编辑器" if test_mode else "返回选关", actions, leave)
	for action in [leave_button, reset_button]:
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.custom_minimum_size.x = 118
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	layout.add_child(margin)
	var right = ui.column(margin)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading = PanelContainer.new()
	heading.add_theme_stylebox_override("panel", WorkshopArt.paper(14, 6))
	right.add_child(heading)
	heading.custom_minimum_size.y = 56
	var header_row = ui.row(heading)
	var name = ui.label(model.definition.title, header_row, 23)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage_label = ui.label("", header_row, 15, WorkshopArt.INK)
	pause_button = ui.button("暂停", header_row, toggle_play)
	finish_button = ui.button("完成放球", header_row, finish_animation)
	var play_area = ui.row(right)
	play_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view = FlowView.new()
	view.custom_minimum_size = Vector2(400, 270)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_area.add_child(view)
	collection_tube = CollectionTube.new()
	collection_tube.custom_minimum_size.x = 225
	play_area.add_child(collection_tube)
	view.configure_run(model)
	view.tooltip_text = "每一轮小球转移时，遵循该格子上四方向的转移概率。若撞墙则此轮原地停留。"
	view.animation_finished.connect(on_animation_finished)
	view.selected_cell.connect(show_cell)
	var result_row = ui.row(right)
	result_row.custom_minimum_size.y = 44
	result_text = ui.paragraph("", result_row, 17, WorkshopArt.INK)
	result_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_text.custom_minimum_size.y = 26
	message = ui.paragraph("WASD移动角色推动箱子" if model.level_index == 0 and not test_mode else "", right, 16, Color.WHITE)
	message.custom_minimum_size.y = 26
	transfer_layer = Control.new()
	transfer_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	transfer_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transfer_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(transfer_layer)
	transfer_layer.set_as_top_level(true)
	transfer_layer.draw.connect(draw_transfers)

func metric(parent: Node, title: String, color: Color, value: String, value_size: int = 30) -> Label:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.style(color, 10, 12, 11))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box = ui.column(panel)
	box.add_theme_constant_override("separation", 0)
	ui.label(title, box, 14, WorkshopArt.INK)
	return ui.label(value, box, value_size, WorkshopArt.RED if title == "目标数量" else WorkshopArt.INK)

func update_forecast() -> void:
	if not test_mode: return
	rate_label.text = "%.2f%%" % (report.rate * 100)
	count_label.text = "%.1f" % report.expected

func refresh_controls() -> void:
	if not is_instance_valid(view): return
	var preparing = model.phase == "prepare"
	var moving = view.busy()
	target_label.text = "%d" % model.target()
	ball_label.text = "%d / %d" % [model.remaining_balls, model.balls]
	batch_controls.visible = true
	if preparing: batch_amount = clampi(batch_amount, mini(100, model.remaining_balls), maximum_batch())
	batch_label.text = "%d / %d" % [batch_amount, model.remaining_balls]
	batch_label.add_theme_font_size_override("font_size", 15 if batch_label.text.length() > 11 else 20)
	decrease_button.disabled = not preparing or batch_amount <= mini(100, model.remaining_balls)
	increase_button.disabled = not preparing or batch_amount >= maximum_batch()
	leave_button.disabled = model.phase == "running"
	horizon_label.text = str(model.horizon)
	budget_label.text = "%d / %d" % [model.pushes_left, model.base_budget]
	stage_label.text = {"prepare": "准备", "running": "投放中", "between": "本批结束", "result": "达标" if model.last_result.get("passed", false) else "未达标", "finished": "完成"}.get(model.phase, "")
	run_button.visible = true
	var passed = model.phase == "result" and model.last_result.get("passed", false)
	run_button.text = ("下一关" if model.has_next() else "完成") if passed else "开始放球"
	run_button.disabled = (not preparing and not passed) or moving
	reset_button.visible = true
	reset_button.text = "重新开始"
	reset_button.disabled = model.phase == "running"
	finish_button.visible = model.phase == "running"
	pause_button.visible = model.phase == "running"
	pause_button.text = "暂停" if playing else "继续放球"
	pause_button.disabled = moving

func probability_text(kind: String) -> String:
	var spec = model.room_spec(kind)
	var text = "上 %s  右 %s\n下 %s  左 %s" % [FlowLevel.percent(spec.p[0]), FlowLevel.percent(spec.p[1]), FlowLevel.percent(spec.p[2]), FlowLevel.percent(spec.p[3])]
	return text

func show_cell(cell: Vector2i) -> void:
	view.selection = cell
	if model.rooms.has(cell):
		selection_text.text = model.room_spec(model.rooms[cell]).name + "\n" + probability_text(model.rooms[cell])
	elif cell == model.exit_cell: selection_text.text = "出口 · 停留 100%"
	else: selection_text.text = "普通格 · 四向各 25%"

func update_frame_label() -> void:
	if report.is_empty(): return
	var arrived = 0
	for arrival in model.arrival_steps:
		if arrival >= 0 and frame_time / speed >= float(arrival) / speed + 0.8: arrived += 1
	var total_arrived = model.batch_start_collected + arrived if model.phase == "running" else model.collected_total
	collection_tube.set_progress(total_arrived, model.balls, model.target())
	transfer_layer.queue_redraw()

func draw_transfers() -> void:
	var texture = BallVisual.get_texture()
	var rank = 0
	for ball in model.arrival_order:
		var arrival: int = model.arrival_steps[ball]
		if arrival < 0: continue
		var t = (frame_time - arrival) / speed / 0.8
		if t >= 0 and t < 1:
			var start = view.global_position + view.ball_position_at(ball, float(arrival))
			var end = collection_tube.global_position + collection_tube.ball_position(model.batch_start_collected + rank)
			var mouth = collection_tube.global_position + collection_tube.mouth_position()
			var position: Vector2
			if t < 0.5:
				var u = t * 2
				position = start.lerp(mouth, u) + Vector2(0, -sin(u * PI) * 80)
			else:
				var u = (t - 0.5) * 2
				position = mouth.lerp(end, u * u)
			var radius = lerpf(view.ball_radius(), collection_tube.ball_radius(), clampf(t * 2 - 1, 0, 1))
			var extent = Vector2.ONE * radius
			transfer_layer.draw_texture_rect(texture, Rect2(position - extent, extent * 2), false, BallVisual.COLOR)
		rank += 1

func requested_balls() -> int:
	return batch_amount

func primary_action() -> void:
	if model.phase == "result" and model.last_result.get("passed", false): advance()
	else: start_run()

func start_run() -> void:
	super.start_run()
	tell("")

func settle() -> void:
	var result = model.settle(report)
	if result.is_empty(): return
	result_text.text = "本批 %d / %d    累计 %d / %d%s" % [result.batch_arrived, result.batch_size, result.arrived, result.target, "  达标" if result.passed else ""]
	view.preparing = false
	if model.continue_batch():
		refresh_report(false)
	refresh_controls()
	tell("")
	if result.passed:
		if not test_mode: ui.record_completion(model.definition)
		ui.sounds.play_sound("win")
	elif model.phase == "result": ui.sounds.play_sound("blocked")

func reset_preparation() -> void:
	if model.phase == "running": return
	if model.phase == "result":
		if model.retry_level(): refresh_report(false); refresh_controls(); result_text.text = ""
		return
	super.reset_preparation()
	result_text.text = ""
	tell("")

func advance() -> void:
	if model.phase != "result" or not model.last_result.get("passed", false): return
	if test_mode: leave(); return
	playing = false
	next_level()

func next_level() -> void:
	if not model.continue_campaign(): ui.show_flow_levels(); return
	rebuild_game()

func rebuild_game() -> void:
	playing = false
	held = Vector2i.ZERO
	buffered = Vector2i.ZERO
	report_dirty = false
	var old = root_box
	remove_child(old)
	old.queue_free()
	build_ui()
	refresh_report(false)
	refresh_controls()
	tell("")

func leave() -> void:
	if model.phase == "running": return
	if leave_action.is_valid(): leave_action.call()
	else: ui.show_flow_levels()

func maximum_batch() -> int:
	var remaining = int(model.remaining_balls)
	return remaining if remaining < 100 else (remaining / 100) * 100

func change_batch(delta: int) -> void:
	if model.phase != "prepare" or delta not in [-100, 100]: return
	batch_amount = clampi(batch_amount + delta, mini(100, model.remaining_balls), maximum_batch())
	refresh_controls()

func show_intro() -> void:
	set_process(false)
	set_process_unhandled_key_input(false)
	root_box.process_mode = Node.PROCESS_MODE_DISABLED
	intro_overlay = ColorRect.new()
	intro_overlay.color = Color(0.08, 0.06, 0.04, 0.70)
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_overlay)
	intro_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 640
	panel.add_theme_stylebox_override("panel", WorkshopArt.paper(30, 26))
	center.add_child(panel)
	var content = ui.column(panel)
	content.add_theme_constant_override("separation", 18)
	var title = ui.label("玩法说明", content, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var description = ui.paragraph("欢迎来到箱球，这是一个非传统的推箱子游戏。你的终极目标不再是把箱子推到固定的地点，而是“你认为合适的地点”。\n\n在地图的【入口】会蹦出非常多的小球，而小球到达每个格子之后，会遵循4个方向的概率选择方向前进，在进行了固定轮次后，你需要保证更多的小球能够最终达到【出口】。\n\n普通地板的4向概率是平分的，而箱子的概率则有偏向，合理运用箱子的位置，让更多的小球落入【出口】吧！", content, 18, WorkshopArt.INK)
	description.custom_minimum_size.x = 580
	var start = ui.button("开始", content, dismiss_intro, true)
	start.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	start.focus_mode = Control.FOCUS_ALL
	start.grab_focus()

func dismiss_intro() -> void:
	if not is_instance_valid(intro_overlay): return
	remove_child(intro_overlay)
	intro_overlay.queue_free()
	intro_overlay = null
	ui.progress.mark_intro_seen()
	root_box.process_mode = Node.PROCESS_MODE_INHERIT
	held = Vector2i.ZERO
	buffered = Vector2i.ZERO
	set_process(true)
	set_process_unhandled_key_input(true)

func tell(text: String) -> void:
	if model.level_index == 0 and not test_mode:
		message.text = "WASD移动角色推动箱子" + ("  ·  " + text if not text.is_empty() else "")
	else:
		message.text = text
