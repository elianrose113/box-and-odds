class_name FlowEditor
extends Control
var ui: Control
var data: Dictionary = {}
var root_box: VBoxContainer
var view: FlowView
var preview = CampaignRun.new()
var fields: Dictionary = {}
var status: Label
var brush = 1
var brush_buttons: Array[Button] = []
var edit_mode = 2
var mode_buttons: Array[Button] = []
var terrain_panel: VBoxContainer
var content_panel: VBoxContainer
var difficulty_label: Label
var calculate_button: Button
var best_button: Button
var difficulty_result: Dictionary = {}
var difficulty_source: Dictionary = {}
var result_overlay: ColorRect
var settings_panel: VBoxContainer
var box_form: VBoxContainer
var selection_hint: Label
var selected = Vector2i(-1, -1)
var name_input: LineEdit
var probabilities: Array[SpinBox] = []
var color_input: ColorPickerButton
var history: Array = []
var future: Array = []
var stroke: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if data.is_empty(): data = FlowLevel.blank()
	ui.difficulty_service.result_ready.connect(on_difficulty_ready)
	build()

func build() -> void:
	if is_instance_valid(root_box):
		remove_child(root_box)
		root_box.queue_free()
	fields.clear()
	probabilities.clear()
	brush_buttons.clear()
	mode_buttons.clear()
	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 12)
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var header = ui.row(root_box)
	ui.label("概率关卡编辑器", header, 25)
	ui.spacer(header)
	difficulty_label = ui.label("难度未计算", header, 18)
	calculate_button = ui.button("计算难度", header, update_difficulty)
	best_button = ui.button("查看最佳布局", header, show_best_layout)
	best_button.disabled = true
	var body = ui.row(root_box)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view = FlowView.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(view)
	view.cell_pressed.connect(paint)
	view.stroke_finished.connect(end_stroke)
	var sidebar = ui.column(body)
	sidebar.custom_minimum_size.x = 390
	var modes = ui.row(sidebar)
	modes.add_theme_constant_override("separation", 5)
	for i in 3:
		var mode_button = ui.button(["关卡编辑", "修改地形", "编辑箱子"][i], modes, set_mode.bind([2, 0, 1][i]))
		mode_button.toggle_mode = true
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.custom_minimum_size.y = 54
		mode_button.add_theme_font_size_override("font_size", 18)
		mode_button.add_theme_stylebox_override("pressed", ui.flat_panel(Color("#2864c5"), 10))
		mode_button.add_theme_color_override("font_pressed_color", Color.WHITE)
		mode_buttons.append(mode_button)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	var inspector = ui.column(scroll)
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_panel = ui.column(inspector)
	ui.label("地形与物品", terrain_panel, 20)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	terrain_panel.add_child(grid)
	var names = ["地板", "墙", "入口", "出口", "玩家", "箱子", "擦除"]
	for i in names.size():
		var b = ui.button(names[i], grid, select_brush.bind(i + 1))
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.add_theme_stylebox_override("pressed", ui.flat_panel(Color("#2864c5"), 10))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		brush_buttons.append(b)
	ui.paragraph("左键绘制，右键擦除。新箱子四向概率各为 25%。", terrain_panel, 13)
	content_panel = ui.column(inspector)
	ui.label("对象属性", content_panel, 20)
	selection_hint = ui.paragraph("请选择地图上的箱子。", content_panel, 14)
	box_form = ui.column(content_panel)
	name_input = text_field(box_form, "箱子名称", "")
	for direction in ["上 %", "右 %", "下 %", "左 %"]:
		probabilities.append(number(box_form, direction, 25, 0, 100))
		probabilities[-1].step = 0.01
	ui.label("箱子颜色", box_form, 14)
	color_input = ColorPickerButton.new()
	color_input.custom_minimum_size.y = 38
	color_input.edit_alpha = false
	box_form.add_child(color_input)
	ui.button("应用修改", box_form, apply_box, true)
	ui.paragraph("四向概率总和须为 100%。修改只作用于当前箱子。", box_form, 13)
	settings_panel = ui.column(inspector)
	ui.label("关卡编辑", settings_panel, 20)
	var dimensions = ui.row(settings_panel)
	fields.width = number(dimensions, "宽", data.width, 4, 10)
	fields.height = number(dimensions, "高", data.height, 4, 8)
	ui.button("应用尺寸", settings_panel, resize_map)
	fields.title = text_field(settings_panel, "关卡名称", data.title)
	for spec in [["order", "排序", 1, 999], ["balls", "初始小球", 1, 100000], ["horizon", "小球转移次数", 1, 200], ["budget", "玩家推动次数", 0, 100], ["target", "到达数量目标", 0, 100000]]:
		fields[spec[0]] = number(settings_panel, spec[1], data[spec[0]], spec[2], spec[3])
	var footer = ui.row(root_box)
	ui.button("试玩", footer, test_level, true)
	ui.button("保存", footer, save_level.bind(false), true)
	ui.button("返回", footer, ui.show_menu)
	status = ui.paragraph("", root_box, 13)
	for field in fields.values():
		if field is SpinBox: field.value_changed.connect(func(_value): invalidate_difficulty())
		elif field is LineEdit: field.text_changed.connect(func(_value): invalidate_difficulty())
	set_mode(edit_mode)
	refresh_view()

func number(parent: Node, title: String, value: float, minimum: float, maximum: float) -> SpinBox:
	var row = ui.row(parent)
	var label = ui.label(title, row, 14)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.value = value
	spin.custom_minimum_size.x = 112
	row.add_child(spin)
	return spin

func text_field(parent: Node, title: String, value: String) -> LineEdit:
	ui.label(title, parent, 14)
	var field = LineEdit.new()
	field.text = value
	field.max_length = 40
	parent.add_child(field)
	return field

func option(parent: Node, title: String, labels: Array) -> OptionButton:
	ui.label(title, parent, 14)
	var field = OptionButton.new()
	for text in labels: field.add_item(text)
	parent.add_child(field)
	return field

func sync() -> void:
	for key in fields:
		if key in ["width", "height"]: continue
		if fields[key] is SpinBox:
			fields[key].apply()
			data[key] = int(fields[key].value)
		elif fields[key] is LineEdit: data[key] = fields[key].text.strip_edges()
		elif fields[key] is CheckBox: data[key] = fields[key].button_pressed

func remember() -> void:
	sync()
	history.append(data.duplicate(true))
	if history.size() > 100: history.pop_front()
	future.clear()

func refresh_view() -> void:
	preview.start([data], 0, true)
	view.configure_run(preview)
	view.editable = true
	view.preparing = true
	view.selection = selected
	invalidate_difficulty()

func set_mode(value: int) -> void:
	end_stroke()
	edit_mode = value
	for i in mode_buttons.size(): mode_buttons[i].set_pressed_no_signal([2, 0, 1][i] == value)
	terrain_panel.visible = value == 0
	content_panel.visible = value == 1
	settings_panel.visible = value == 2
	for i in brush_buttons.size(): brush_buttons[i].set_pressed_no_signal(i + 1 == brush)
	load_selected_box()

func select_brush(value: int) -> void:
	if value == 0:
		set_mode(1)
		return
	brush = value
	set_mode(0)

func selected_box_index() -> int:
	for i in data.rooms.size():
		if data.rooms[i].pos == FlowLevel.pair(selected): return i
	return -1

func load_selected_box() -> void:
	var index = selected_box_index()
	box_form.visible = index >= 0
	if index < 0:
		selection_hint.text = "请选择地图上的箱子。" if selected == Vector2i(-1, -1) else "该位置没有可编辑的箱子。"
		return
	selection_hint.text = "箱子 · 位置 (%d, %d)" % [selected.x + 1, selected.y + 1]
	var spec: Dictionary = data.room_defs[data.rooms[index].kind]
	name_input.text = spec.name
	for i in 4: probabilities[i].value = float(spec.p[i]) * 100
	color_input.color = Color(spec.color)

func fresh_box_key() -> String:
	var key = "box_" + str(Time.get_ticks_usec())
	while data.room_defs.has(key): key += "_"
	return key

func paint(cell: Vector2i, erase: bool) -> void:
	if edit_mode == 2: return
	var pos = FlowLevel.pair(cell)
	if edit_mode == 1:
		if erase: return
		selected = cell
		view.selection = cell
		load_selected_box()
		return
	if stroke.is_empty():
		sync()
		stroke = data.duplicate(true)
	var tool = 7 if erase else brush
	if tool in [1, 2, 6, 7] and pos in [data.entrance, data.exit, data.player]:
		status.text = "请使用入口、出口或玩家画笔移动该位置。"
		return
	var room_index = -1
	for i in data.rooms.size():
		if data.rooms[i].pos == pos: room_index = i; break
	match tool:
		1, 2, 7:
			if room_index >= 0: data.rooms.remove_at(room_index)
			data.walls.erase(pos)
			if tool == 2: data.walls.append(pos)
		3, 4, 5:
			var key = {3: "entrance", 4: "exit", 5: "player"}[tool]
			for other in ["entrance", "exit", "player"]:
				if other != key and data[other] == pos: return
			data[key] = pos
			data.walls.erase(pos)
			if room_index >= 0: data.rooms.remove_at(room_index)
		6:
			data.walls.erase(pos)
			if room_index < 0:
				var key = fresh_box_key()
				data.room_defs[key] = {"name": "箱子", "p": [0.25, 0.25, 0.25, 0.25], "color": "#bd945b"}
				data.rooms.append({"pos": pos, "kind": key})
	refresh_view()

func end_stroke() -> void:
	if not stroke.is_empty() and stroke != data:
		history.append(stroke)
		if history.size() > 100: history.pop_front()
		future.clear()
	stroke = {}

func undo() -> void:
	end_stroke()
	if history.is_empty(): return
	sync()
	future.append(data.duplicate(true))
	data = history.pop_back()
	build()

func redo() -> void:
	if future.is_empty(): return
	history.append(data.duplicate(true))
	data = future.pop_back()
	build()

func resize_map() -> void:
	fields.width.apply()
	fields.height.apply()
	var width = int(fields.width.value)
	var height = int(fields.height.value)
	for key in ["player", "entrance", "exit"]:
		if data[key][0] >= width or data[key][1] >= height:
			status.text = "请先将玩家、入口和出口移入新尺寸内。"
			return
	remember()
	data.width = width
	data.height = height
	data.walls = data.walls.filter(func(p): return p[0] < width and p[1] < height)
	data.rooms = data.rooms.filter(func(r): return r.pos[0] < width and r.pos[1] < height)
	refresh_view()

func read_spec() -> Dictionary:
	var p: Array = []
	var total = 0.0
	for field in probabilities:
		field.apply()
		total += field.value
		p.append(float(field.value) / 100.0)
	if absf(total - 100.0) > 0.0001:
		ui.alert("概率错误", "四向概率之和须为 100%，当前为 %s%%。" % total)
		return {}
	if name_input.text.strip_edges().is_empty():
		ui.alert("名称为空", "请填写箱子名称。")
		return {}
	return {"name": name_input.text.strip_edges(), "p": p, "color": "#" + color_input.color.to_html(false)}

func apply_box() -> void:
	var index = selected_box_index()
	if edit_mode != 1 or index < 0: return
	var spec = read_spec()
	if spec.is_empty(): return
	remember()
	# Existing levels can share definitions; detach only this instance on edit.
	var key = str(data.rooms[index].kind)
	var shared = data.rooms.filter(func(room): return room.kind == key).size() > 1
	if shared: key = fresh_box_key()
	data.room_defs[key] = spec
	data.rooms[index].kind = key
	refresh_view()
	status.text = "当前箱子已更新。"

func save_level(draft: bool) -> void:
	sync()
	end_stroke()
	var issues = FlowLevel.validate(data, not draft)
	if not issues.is_empty(): ui.alert("无法保存", "\n".join(issues)); return
	var issue = FlowLevel.save(data, draft)
	if not issue.is_empty(): ui.alert("保存失败", issue)
	else: status.text = "草稿已保存。" if draft else "关卡已保存，可在游戏选关中使用。"

func test_level() -> void:
	sync()
	end_stroke()
	var issues = FlowLevel.validate(data)
	if not issues.is_empty(): ui.alert("无法试玩", "\n".join(issues)); return
	var original = data.duplicate(true)
	var app = ui
	app.start_flow_campaign([data.duplicate(true)], 0, true, func(): app.open_flow_editor(original))

func new_level() -> void:
	data = FlowLevel.blank()
	history.clear()
	future.clear()
	selected = Vector2i(-1, -1)
	build()

func duplicate_level() -> void:
	sync()
	data.id = FlowLevel.blank().id
	data.title = (data.title + " 副本").left(40)
	history.clear()
	future.clear()
	build()
	save_level(true)

func open_file() -> void:
	DirAccess.make_dir_recursive_absolute(FlowLevel.DRAFTS)
	var dialog = ui.make_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "打开概率关卡")
	dialog.current_dir = ProjectSettings.globalize_path(FlowLevel.DRAFTS)
	dialog.file_selected.connect(func(path: String):
		var loaded = FlowLevel.read_file(path)
		if loaded.has("error"): ui.alert("打开失败", loaded.error)
		else:
			data = loaded.level
			history.clear()
			future.clear()
			selected = Vector2i(-1, -1)
			build()
		dialog.queue_free())
	dialog.popup_centered()

func export_file() -> void:
	sync()
	var issues = FlowLevel.validate(data, false)
	if not issues.is_empty(): ui.alert("无法导出", "\n".join(issues)); return
	var dialog = ui.make_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "导出概率关卡")
	dialog.current_file = "flow_level.json"
	dialog.file_selected.connect(func(path: String):
		if not path.ends_with(".json"): path += ".json"
		var issue = LevelStore.new().write_json(path, data)
		if issue.is_empty(): status.text = "已导出：" + path
		else: ui.alert("导出失败", issue)
		dialog.queue_free())
	dialog.popup_centered()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.ctrl_pressed and event.physical_keycode == KEY_Z: undo()
	elif event.ctrl_pressed and event.physical_keycode == KEY_Y: redo()
	elif event.ctrl_pressed and event.physical_keycode == KEY_S: save_level(false)
	elif event.physical_keycode == KEY_F5: test_level()

func invalidate_difficulty() -> void:
	difficulty_result = {}
	if not is_instance_valid(difficulty_label): return
	difficulty_label.set_meta("difficulty_key", "")
	difficulty_label.text = "难度未计算"
	calculate_button.disabled = false
	best_button.disabled = true

func update_difficulty() -> void:
	sync()
	end_stroke()
	var issues = FlowLevel.validate(data)
	if not issues.is_empty():
		ui.alert("无法计算", "\n".join(issues))
		return
	difficulty_source = data.duplicate(true)
	calculate_button.disabled = true
	best_button.disabled = true
	ui.difficulty_service.request(difficulty_source, difficulty_label)

func on_difficulty_ready(label: Label, result: Dictionary) -> void:
	if label != difficulty_label: return
	sync()
	if data != difficulty_source:
		invalidate_difficulty()
		return
	difficulty_result = result.duplicate(true)
	calculate_button.disabled = false
	best_button.disabled = result.is_empty()
	if not result.is_empty(): show_best_layout()

func show_best_layout() -> void:
	if difficulty_result.is_empty() or is_instance_valid(result_overlay): return
	root_box.process_mode = Node.PROCESS_MODE_DISABLED
	set_process_unhandled_key_input(false)
	result_overlay = ColorRect.new()
	result_overlay.color = Color(0, 0, 0, 0.6)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_overlay)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.flat_panel(Color("#eef1f5"), 20))
	result_overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_right = -24
	panel.offset_bottom = -24
	var content = ui.column(panel)
	var heading = ui.row(content)
	ui.label("最佳已找到布局", heading, 24)
	ui.spacer(heading)
	ui.button("关闭", heading, close_best_layout)
	ui.label("难度 %d / 100    预计到达 %.1f 颗    使用 %d 次推动" % [difficulty_result.score, difficulty_result.expected, difficulty_result.pushes], content, 17)
	var reason = "已达到布局计算上限" if difficulty_result.stop_reason == "layout_limit" else "已搜完推动预算内可达布局"
	ui.label("已计算 %d / %d 个布局 · 搜索至 %d 次推动 · %s" % [difficulty_result.examined, difficulty_result.limit, difficulty_result.max_depth, reason], content, 14)
	var body = ui.row(content)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var board = FlowView.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(360, 260)
	body.add_child(board)
	var layout = difficulty_source.duplicate(true)
	layout.rooms = difficulty_result.rooms.duplicate(true)
	layout.player = difficulty_result.player.duplicate()
	var model = CampaignRun.new()
	model.start([layout], 0, true)
	board.configure_run(model)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 240
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var positions = ui.column(scroll)
	ui.label("箱子位置（列，行）", positions, 17)
	for room in layout.rooms:
		ui.label("%s  (%d, %d)" % [layout.room_defs[room.kind].name, room.pos[0] + 1, room.pos[1] + 1], positions, 15)
	ui.paragraph("坐标从左上角 (1, 1) 开始。" + ("已验证为推动预算内到达概率最高的布局。" if difficulty_result.complete else "当前找到的最佳布局，尚未证明全局最优。") + "此预览不会修改关卡。", content, 14)

func close_best_layout() -> void:
	if is_instance_valid(result_overlay):
		remove_child(result_overlay)
		result_overlay.queue_free()
	result_overlay = null
	root_box.process_mode = Node.PROCESS_MODE_INHERIT
	set_process_unhandled_key_input(true)
