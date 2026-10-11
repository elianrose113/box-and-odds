extends Control
const MINT = Color("#b84832")
const MUTED = Color("#665044")
var difficulty_service: DifficultyService
var sounds: SoundBank
var page: VBoxContainer
var screen = ""
var progression_enabled = true
var progress = CampaignProgress.new()
var status: Label

func _ready() -> void:
	Engine.max_fps = 60
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 16000
	difficulty_service = DifficultyService.new()
	add_child(difficulty_service)
	get_window().min_size = Vector2i(960, 640)
	var background = TextureRect.new()
	background.texture = WorkshopArt.texture("warehouse_background_v2")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = make_theme()
	sounds = SoundBank.new()
	add_child(sounds)
	show_menu()

func make_theme() -> Theme:
	var t = Theme.new()
	t.default_font_size = 18
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	font.font_weight = 600
	t.default_font = font
	t.set_color("font_color", "Label", WorkshopArt.INK)
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	t.set_color("font_color", "Button", WorkshopArt.INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", WorkshopArt.INK)
	t.set_color("font_disabled_color", "Button", WorkshopArt.INK)
	t.set_stylebox("normal", "Button", style(Color("#263b49"), 10, 14, 10))
	t.set_stylebox("hover", "Button", style(Color("#395565"), 10, 14, 10))
	t.set_stylebox("pressed", "Button", style(MINT, 10, 14, 10))
	t.set_stylebox("disabled", "Button", style(Color("#1b2a34"), 10, 14, 10))
	t.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), 10, 14, 10, MINT))
	t.set_stylebox("normal", "LineEdit", style(Color("#0d1c27"), 8, 10, 10))
	t.set_stylebox("focus", "LineEdit", style(Color("#112632"), 8, 10, 10, MINT))
	t.set_color("font_color", "LineEdit", WorkshopArt.INK)
	t.set_color("font_color", "CheckBox", WorkshopArt.INK)
	t.set_stylebox("panel", "AcceptDialog", style(Color("#1b2e3b"), 16, 20, 20))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	for type in ["OptionButton", "TabContainer", "PopupMenu"]:
		t.set_color("font_color", type, WorkshopArt.INK)
		t.set_color("font_selected_color", type, WorkshopArt.INK)
		t.set_color("font_unselected_color", type, Color("#695348"))
		t.set_stylebox("panel", type, WorkshopArt.paper())
		t.set_stylebox("normal", type, WorkshopArt.paper())
	t.set_stylebox("tab_selected", "TabContainer", WorkshopArt.paper(14, 8))
	t.set_stylebox("tab_unselected", "TabContainer", WorkshopArt.paper(14, 8, false, Color("#c9b699")))
	return t


func style(color: Color, _radius: int = 12, horizontal: int = 16, vertical: int = 16, _border: Color = Color.TRANSPARENT) -> StyleBox:
	return WorkshopArt.paper(horizontal, vertical, color == MINT)


func clear_page(mode: String) -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	screen = mode
	status = null
	page = VBoxContainer.new()
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 32
	page.offset_top = 24
	page.offset_right = -32
	page.offset_bottom = -24
	page.add_theme_constant_override("separation", 18)


func label(text: String, parent: Node, font_size: int = 18, color: Color = WorkshopArt.INK) -> Label:
	var result = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result


func paragraph(text: String, parent: Node, font_size: int = 16, color: Color = MUTED) -> Label:
	var result = label(text, parent, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


func button(text: String, parent: Node, action: Callable, accent: bool = false) -> Button:
	var result = Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	result.focus_mode = Control.FOCUS_NONE
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if accent:
		result.add_theme_stylebox_override("normal", style(MINT, 10, 14, 10))
		result.add_theme_stylebox_override("hover", WorkshopArt.paper(14, 10, true, Color("#ffe8c9")))
		result.add_theme_color_override("font_color", Color("#fff3d6"))
		result.add_theme_color_override("font_hover_color", Color.WHITE)
	parent.add_child(result)
	result.pressed.connect(action)
	return result


func spacer(parent: Node, vertical: bool = false) -> Control:
	var result = Control.new()
	if vertical: result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else: result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result


func row(parent: Node) -> HBoxContainer:
	var result = HBoxContainer.new()
	parent.add_child(result)
	return result


func column(parent: Node) -> VBoxContainer:
	var result = VBoxContainer.new()
	parent.add_child(result)
	return result


func header(title: String, subtitle: String, back_action: Callable = Callable()) -> void:
	var bar = row(page)
	var titles = column(bar)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading = label(title, titles, 28)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not subtitle.is_empty(): label(subtitle, titles, 14, MUTED)
	spacer(bar)
	if back_action.is_valid(): button("返回", bar, back_action)


func make_status(text: String) -> void:
	status = label(text, page, 15, MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func notify(text: String) -> void:
	if is_instance_valid(status): status.text = text


func alert(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "知道了"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(600, 220))


func show_menu() -> void:
	clear_page("menu")
	var center = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(center)
	var menu = column(center)
	menu.custom_minimum_size.x = 320
	menu.add_theme_constant_override("separation", 24)
	var title = label("箱球", menu, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var english_title = label("Box & Odds", menu, 32)
	english_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var gap = Control.new()
	gap.custom_minimum_size.y = 24
	menu.add_child(gap)
	button("开始游戏", menu, show_flow, true)
	button("退出游戏", menu, func(): get_tree().quit())


func show_flow() -> void:
	show_flow_levels()

func show_flow_levels() -> void:
	var catalog = FlowLevel.catalog()
	clear_page("flow_levels")
	header("选择关卡", "", show_menu)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var list = column(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var unlocked = progress.first_unfinished(catalog.levels)
	for i in catalog.levels.size():
		var enter = button("关卡%d" % (i + 1), list, start_flow_campaign.bind(catalog.levels, i))
		enter.custom_minimum_size.y = 76
		enter.add_theme_font_size_override("font_size", 26)
		enter.disabled = progression_enabled and i > unlocked
		enter.add_theme_color_override("font_disabled_color", Color("#9b8c7b"))
	if not catalog.errors.is_empty(): alert("关卡读取提示", "\n".join(catalog.errors))

func record_completion(level: Dictionary) -> void:
	if progression_enabled and progress.mark_completed(level) != OK:
		alert("进度保存失败", "本次通关仍然有效，但无法保存到本机。")

func start_flow_campaign(levels: Array, index: int = 0, testing_level: bool = false, back: Callable = Callable()) -> void:
	if levels.is_empty(): return
	index = clampi(index, 0, levels.size() - 1)
	if progression_enabled and not testing_level:
		index = mini(index, progress.first_unfinished(levels))
	clear_page("flow")
	page.offset_left = 0
	page.offset_top = 0
	page.offset_right = 0
	page.offset_bottom = 0
	var game = CampaignGame.new()
	game.ui = self
	game.level_list = levels.duplicate(true)
	game.start_index = index
	game.test_mode = testing_level
	game.leave_action = back
	game.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(game)



