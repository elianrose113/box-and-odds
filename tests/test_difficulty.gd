extends SceneTree
func _initialize() -> void:
	var levels = FlowLevel.catalog().levels
	for level in levels:
		var before = level.duplicate(true)
		var value = LevelDifficulty.score(level)
		assert(value >= 0 and value <= 100)
		assert(value == LevelDifficulty.score(level))
		assert(level == before)
		print(level.title, " difficulty=", value)
	var easy = levels[0].duplicate(true)
	easy.target = 0
	assert(LevelDifficulty.score(easy) == 0)
	var strict = levels[0].duplicate(true)
	strict.target = strict.balls
	assert(LevelDifficulty.score(strict) >= LevelDifficulty.score(levels[0]))
	print("DIFFICULTY CHECKS PASSED")
	quit()
