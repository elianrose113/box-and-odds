class_name CampaignProgress
extends RefCounted
var path = "user://campaign_progress.json"
var completed: Dictionary = {}
func _init(save_path: String = "user://campaign_progress.json") -> void:
	path = save_path
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary: completed = data
func key(level: Dictionary) -> String:
	return str(level.get("id", "")) + ":" + JSON.stringify(level).sha256_text()
func first_unfinished(levels: Array) -> int:
	for index in levels.size():
		if not completed.has(key(levels[index])): return index
	return levels.size()
func mark_completed(level: Dictionary) -> Error:
	completed[key(level)] = true
	return save()
func intro_seen() -> bool:
	return completed.get("_intro_seen_v1", false) == true
func mark_intro_seen() -> Error:
	completed["_intro_seen_v1"] = true
	return save()
func save() -> Error:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(completed))
	return OK
