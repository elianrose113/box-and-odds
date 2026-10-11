extends SceneTree
func _initialize() -> void:
	for data in FlowLevel.catalog().levels:
		var result = LevelDifficulty.analyze(data)
		print(data.title, " evaluated=", result.examined, " best_expected=", result.expected, " pushes=", result.pushes, " budget=", data.budget)
	quit()
