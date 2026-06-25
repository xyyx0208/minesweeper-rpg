extends ColorRect
## 首页菜单 — 像素地牢主题

const ArtGen = preload("res://scripts/art_generator.gd")

func _ready() -> void:
	# 生成地牢背景纹理
	var ag: Node = ArtGen.new()
	add_child(ag)
	var bg_tex = ag.dungeon_bg(600, 400)
	var bg_rect := TextureRect.new()
	bg_rect.texture = bg_tex
	bg_rect.anchor_left = 0.0
	bg_rect.anchor_top = 0.0
	bg_rect.anchor_right = 1.0
	bg_rect.anchor_bottom = 1.0
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.stretch_mode = TextureRect.STRETCH_TILE
	add_child(bg_rect)
	# 将背景移到最底层
	move_child(bg_rect, 0)

	$ClassicBtn.pressed.connect(_start_classic)
	$RpgBtn.pressed.connect(_start_rpg)
	$RogueBtn.pressed.connect(_start_rogue)

	# 按钮悬停效果
	for btn in [$ClassicBtn, $RpgBtn, $RogueBtn]:
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_leave.bind(btn))


func _on_btn_hover(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color("#ffffff"))
	btn.scale = Vector2(1.05, 1.05)


func _on_btn_leave(btn: Button) -> void:
	var orig_colors := {
		$ClassicBtn: Color("#c0c0d0"),
		$RpgBtn: Color("#66ff66"),
		$RogueBtn: Color("#ffcc00"),
	}
	btn.add_theme_color_override("font_color", orig_colors.get(btn, Color("#c0c0d0")))
	btn.scale = Vector2(1.0, 1.0)


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
