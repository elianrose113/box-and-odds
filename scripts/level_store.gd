class_name LevelStore
extends RefCounted
const CUSTOM = "user://levels"
const DRAFTS = "user://drafts"
const PROGRESS = "user://progress.json"
var errors: PackedStringArray = []

func ensure_dirs() -> void:
	for path in [CUSTOM, DRAFTS]:
		var result = DirAccess.make_dir_recursive_absolute(path)
		if result != OK: errors.append("无法创建存储目录：" + path)

func read_level(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "无法读取：" + path}
	if file.get_length() > 1024 * 1024: return {"error": "关卡文件超过 1 MB。"}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {"error": "JSON 第 %d 行：%s" % [json.get_error_line(), json.get_error_message()]}
	return LevelData.decode(json.data)

func catalog() -> Array[LevelData]:
	var result: Array[LevelData] = []
	var seen: Dictionary = {}
	errors.clear()
	ensure_dirs()
	for folder in ["res://levels", CUSTOM]:
		for name in DirAccess.get_files_at(folder):
			if not name.ends_with(".json"): continue
			var loaded = read_level(folder.path_join(name))
			if loaded.has("error"):
				errors.append(name + "：" + loaded.error)
				continue
			var level: LevelData = loaded.level
			var problems = level.validate()
			if not problems.is_empty():
				errors.append(name + "：" + " ".join(problems))
				continue
			if seen.has(level.id):
				result[seen[level.id]] = level
			else:
				seen[level.id] = result.size()
				result.append(level)
	result.sort_custom(func(a: LevelData, b: LevelData): return a.order < b.order if a.order != b.order else a.title.naturalnocasecmp_to(b.title) < 0)
	return result

func write_json(path: String, data: Dictionary) -> String:
	# Write to a sibling temporary file, then rename; failed writes keep the old file.
	var temporary = path + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "无法写入文件，请检查目录权限：" + path
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return "文件写入失败：" + error_string(error)
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK: return "文件保存失败：" + error_string(error)
	return ""

func save_level(level: LevelData, draft: bool) -> String:
	ensure_dirs()
	var folder = DRAFTS if draft else CUSTOM
	# Hash the ID so imported data can never inject paths.
	return write_json(folder.path_join(level.id.sha256_text().substr(0, 24) + ".json"), level.to_dict())

func load_progress() -> Dictionary:
	if not FileAccess.file_exists(PROGRESS): return {}
	var file = FileAccess.open(PROGRESS, FileAccess.READ)
	if file == null:
		errors.append("无法读取通关记录。")
		return {}
	if file.get_length() > 1024 * 1024:
		errors.append("通关记录过大，当前使用空记录。")
		return {}
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		errors.append("通关记录损坏，当前使用空记录。")
		return {}
	var clean: Dictionary = {}
	for key in data:
		var record = data[key]
		if not record is Dictionary or not record.get("completed") is bool or not record.get("layout") is String:
			errors.append("已跳过格式错误的通关记录。")
			continue
		if not LevelData.integer(record.get("best_steps")) or not LevelData.integer(record.get("best_pushes")):
			errors.append("已跳过格式错误的步数记录。")
			continue
		if record.best_steps < 0 or record.best_pushes < 0: continue
		clean[key] = record
	return clean
