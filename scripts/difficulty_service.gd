class_name DifficultyService
extends Node
signal result_ready(label: Label, result: Dictionary)
var pending: Array = []
var active: Dictionary = {}
var worker: Thread
var results: Dictionary = {}
func request(data: Dictionary, label: Label) -> void:
	var key = JSON.stringify(data).sha256_text()
	label.set_meta("difficulty_key", key)
	if results.has(key):
		label.text = "难度 %d / 100" % results[key].score
		result_ready.emit(label, results[key])
		return
	label.text = "难度计算中"
	pending = pending.filter(func(job): return job.label.get_ref() != label)
	pending.append({"data": data.duplicate(true), "key": key, "label": weakref(label)})
func _process(_delta: float) -> void:
	if worker != null:
		if worker.is_alive(): return
		var value = worker.wait_to_finish()
		worker = null
		if results.size() >= 256: results.clear()
		results[active.key] = value
		deliver(active, value)
		active = {}
	while not pending.is_empty():
		active = pending.pop_front()
		var label = active.label.get_ref()
		if not is_instance_valid(label) or label.get_meta("difficulty_key", "") != active.key: continue
		if results.has(active.key):
			deliver(active, results[active.key])
			continue
		worker = Thread.new()
		var data: Dictionary = active.data
		var error = worker.start(func(): return LevelDifficulty.analyze(data), Thread.PRIORITY_LOW)
		if error != OK:
			worker = null
			label.text = "难度 — / 100"
		return
func deliver(job: Dictionary, value: Dictionary) -> void:
	var label = job.label.get_ref()
	if is_instance_valid(label) and label.get_meta("difficulty_key", "") == job.key:
		label.text = "难度 %d / 100" % value.get("score", 0)
		result_ready.emit(label, value)
func _exit_tree() -> void:
	if worker != null: worker.wait_to_finish()
