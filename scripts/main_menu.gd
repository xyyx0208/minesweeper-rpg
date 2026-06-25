extends ColorRect
## 首页菜单

func _ready() -> void:
	$ClassicBtn.pressed.connect(_start_classic)
	$RpgBtn.pressed.connect(_start_rpg)
	$RogueBtn.pressed.connect(_start_rogue)


func _start_classic() -> void:
	game_state.rogue_mode = false
	game_state.rpg_mode = false
	get_tree().change_scene_to_file("res://scenes/minesweeper_game.tscn")


func _start_rpg() -> void:
	game_state.rogue_mode = false
	game_state.rpg_mode = true
	get_tree().change_scene_to_file("res://scenes/minesweeper_game.tscn")


func _start_rogue() -> void:
	game_state.rpg_mode = false
	game_state.rogue_mode = true
	get_tree().change_scene_to_file("res://scenes/minesweeper_game.tscn")
