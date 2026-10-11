class_name FlowGame
extends Control
## Shared playback and movement controller for probability levels.
var ui: Control
var model: CampaignRun
var view: FlowView
var root_box: VBoxContainer
var selection_text: Label
var message: Label
var result_text: Label
var step_text: Label
var run_button: Button
var undo_button: Button
var reset_button: Button
var pause_button: Button
var finish_button: Button
var next_button: Button
var report: Dictionary = {}
var frame_time = 0.0
var playing = false
var speed = 7.0
var held = Vector2i.ZERO
var repeat_delay = 0.0
var buffered = Vector2i.ZERO
var report_dirty = false

func tell(text: String) -> void:
	message.text = text

func refresh_report(_compare: bool = true) -> void:
	report = model.simulate()
	view.set_report(report)
	view.preparing = model.phase == "prepare"
	frame_time = 0.0
	view.frame_position = 0.0
	update_frame_label()
	update_forecast()
	if view.selection != Vector2i(-1, -1): show_cell(view.selection)

func update_forecast() -> void:
	pass

func refresh_controls() -> void:
	pass

func show_cell(_cell: Vector2i) -> void:
	pass

func update_frame_label() -> void:
	pass

func settle() -> void:
	pass

func key_direction(key: int) -> Vector2i:
	match key:
		KEY_W, KEY_UP: return Vector2i.UP
		KEY_D, KEY_RIGHT: return Vector2i.RIGHT
		KEY_S, KEY_DOWN: return Vector2i.DOWN
		KEY_A, KEY_LEFT: return Vector2i.LEFT
	return Vector2i.ZERO

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_Z: undo()
	elif event.physical_keycode == KEY_R: reset_preparation()
	else:
		var direction = key_direction(event.physical_keycode)
		if direction == Vector2i.ZERO: return
		held = direction
		repeat_delay = 0.28
		attempt_move(direction)
	get_viewport().set_input_as_handled()

func is_held(direction: Vector2i) -> bool:
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		if key_direction(key) == direction and Input.is_physical_key_pressed(key): return true
	return false

func _process(delta: float) -> void:
	if view == null: return
	if playing:
		frame_time = minf(frame_time + delta * speed, model.horizon + speed * 0.85)
		view.frame_position = frame_time
		update_frame_label()
		if frame_time >= model.horizon + speed * 0.85:
			playing = false
			if model.phase == "running": settle()
			else:
				view.preparing = model.phase == "prepare"
				refresh_controls()
	elif model.phase == "prepare":
		if not get_window().has_focus(): held = Vector2i.ZERO
		if held != Vector2i.ZERO:
			if not is_held(held): held = Vector2i.ZERO
			else:
				repeat_delay -= delta
				if repeat_delay <= 0 and not view.busy():
					attempt_move(held)
					repeat_delay = 0.145

func attempt_move(direction: Vector2i) -> void:
	if model.phase != "prepare" or playing: return
	if view.busy(): buffered = direction; return
	var result = model.move(direction)
	view.animate(result, direction)
	if not result.ok:
		tell(result.error)
		ui.sounds.play_sound("blocked")
	else:
		ui.sounds.play_sound("push" if result.pushed else "walk")
		if result.pushed: report_dirty = true
		tell("")
	refresh_controls()

func on_animation_finished() -> void:
	if report_dirty:
		refresh_report()
		report_dirty = false
	refresh_controls()
	if buffered != Vector2i.ZERO:
		var direction = buffered
		buffered = Vector2i.ZERO
		attempt_move(direction)

func undo() -> void:
	if playing or not model.undo(): return
	view.motion.clear()
	buffered = Vector2i.ZERO
	held = Vector2i.ZERO
	report_dirty = false
	refresh_report()
	refresh_controls()
	tell("")
	ui.sounds.play_sound("undo")

func reset_preparation() -> void:
	if playing or not model.reset_preparation(): return
	view.motion.clear()
	buffered = Vector2i.ZERO
	held = Vector2i.ZERO
	report_dirty = false
	refresh_report(false)
	refresh_controls()
	tell("")

func requested_balls() -> int:
	return -1

func start_run() -> void:
	if model.phase != "prepare" or view.busy() or playing: return
	speed = maxf(7.0, float(model.horizon) / 4.0)
	report = model.begin_run(requested_balls())
	if report.is_empty(): return
	view.set_report(report)
	view.preparing = false
	frame_time = 0
	view.frame_position = 0
	held = Vector2i.ZERO
	buffered = Vector2i.ZERO
	playing = true
	result_text.text = ""
	refresh_controls()
	tell("")

func finish_animation() -> void:
	if model.phase != "running": return
	frame_time = model.horizon + speed * 0.85
	view.frame_position = frame_time
	playing = false
	update_frame_label()
	settle()

func toggle_play() -> void:
	if model.phase != "running": return
	playing = not playing
	held = Vector2i.ZERO
	refresh_controls()
