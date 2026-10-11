extends "res://scripts/main.gd"

func _ready() -> void:
	progression_enabled = false
	super._ready()
	var background = ColorRect.new()
	background.color = Color("#eef1f5")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		if child is TextureRect: child.visible = false

func clear_page(mode: String) -> void:
	super.clear_page(mode)
	for child in get_children():
		if child is TextureRect: child.visible = mode == "flow"
	theme = super.make_theme() if mode == "flow" else editor_theme()

func flat_panel(color: Color, padding: int = 16) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("#d4dbe5")
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

func editor_theme() -> Theme:
	var result = super.make_theme()
	for kind in ["Button", "LineEdit", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			result.set_stylebox(state, kind, flat_panel(Color("#e4ecf7") if state == "hover" else Color.WHITE, 10))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, kind, Color("#233249"))
		result.set_color("font_disabled_color", kind, Color("#8a96a6"))
	result.set_color("font_placeholder_color", "LineEdit", Color("#6b7b90"))
	result.set_color("caret_color", "LineEdit", Color("#2864c5"))
	for kind in ["TabContainer", "PopupMenu", "AcceptDialog"]:
		result.set_stylebox("panel", kind, flat_panel(Color.WHITE))
	result.set_stylebox("tab_selected", "TabContainer", flat_panel(Color.WHITE, 12))
	result.set_stylebox("tab_unselected", "TabContainer", flat_panel(Color("#dfe5ed"), 12))
	return result

func button(text: String, parent: Node, action: Callable, accent: bool = false) -> Button:
	var control = super.button(text, parent, action, accent)
	if screen != "flow" and accent:
		control.add_theme_stylebox_override("normal", flat_panel(Color("#2864c5"), 12))
		control.add_theme_stylebox_override("hover", flat_panel(Color("#3477dd"), 12))
		control.add_theme_stylebox_override("pressed", flat_panel(Color("#2055aa"), 12))
		control.add_theme_color_override("font_pressed_color", Color.WHITE)
	return control

func show_menu() -> void:
	var catalog = FlowLevel.catalog()
	clear_page("editor_catalog")
	var toolbar = row(page)
	label("关卡编辑器", toolbar, 28, Color("#1d2939"))
	spacer(toolbar)
	button("新建关卡", toolbar, open_flow_editor, true)
	button("退出编辑器", toolbar, func(): get_tree().quit())
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", flat_panel(Color.WHITE, 20))
	page.add_child(panel)
	var content = column(panel)
	var top = row(content)
	label("关卡列表", top, 20, Color("#233249"))
	spacer(top)
	label("%d 个关卡" % catalog.levels.size(), top, 15, Color("#66758a"))
	var search = LineEdit.new()
	search.placeholder_text = "搜索关卡名称"
	search.custom_minimum_size.y = 42
	content.add_child(search)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var list = column(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries: Array = []
	for data in catalog.levels:
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", flat_panel(Color("#f7f9fc"), 18))
		list.add_child(card)
		var line = row(card)
		var details = column(line)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title = label(data.title, details, 20, Color("#233249"))
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label("%d × %d 格   ·   %d 个箱子   ·   %d 颗小球" % [data.width, data.height, data.rooms.size(), data.balls], details, 14, Color("#54647a"))
		label("转移 %d 次   ·   推动 %d 次   ·   目标 %d 颗" % [data.horizon, data.budget, data.target], details, 14, Color("#54647a"))
		var edit = button("编辑关卡", line, open_flow_editor.bind(data), true)
		edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entries.append({"node": card, "title": str(data.title).to_lower()})
	var empty = label("没有匹配的关卡", list, 16, Color("#66758a"))
	empty.visible = catalog.levels.is_empty()
	search.text_changed.connect(func(query: String):
		var count = 0
		for entry in entries:
			entry.node.visible = query.strip_edges().to_lower() in entry.title
			if entry.node.visible: count += 1
		empty.visible = count == 0
	)
	if not catalog.errors.is_empty(): alert("关卡读取提示", "\n".join(catalog.errors))

func show_flow_levels() -> void:
	show_menu()

func open_flow_editor(source: Dictionary = {}) -> void:
	clear_page("flow_editor")
	var editor = FlowEditor.new()
	editor.ui = self
	editor.data = source.duplicate(true) if not source.is_empty() else FlowLevel.blank()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(editor)


func make_file_dialog(mode: FileDialog.FileMode, title: String) -> FileDialog:
	var dialog = FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; 推箱子关卡"])
	dialog.title = title
	dialog.use_native_dialog = false
	dialog.size = Vector2i(850, 560)
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	return dialog



