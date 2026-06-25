extends Node
## 扫雷游戏核心管理器
## 负责：布雷、揭开/标记、胜负判定、计时、UI 布局
## Android: 新增触摸输入（长按旗帜）
## Roguelike: 爬塔模式集成
## RPG: 翻格遇敌模式集成

# ─── 信号 ───────────────────────────────────────────
signal game_started()
signal game_ended(won: bool)
signal flag_count_changed(count: int)
signal time_changed(seconds: int)
signal difficulty_changed(diff: int)
signal rogue_floor_cleared()  # 爬塔模式每层通关

# ─── 难度系统 ────────────────────────────────────────
enum Difficulty { BEGINNER, INTERMEDIATE, EXPERT, CUSTOM }

const DIFFICULTY_CONFIG := {
	Difficulty.BEGINNER:     { cols = 9,  rows = 9,  mines = 10, cell = 48, label = "初级" },
	Difficulty.INTERMEDIATE: { cols = 16, rows = 16, mines = 40, cell = 36, label = "中级" },
	Difficulty.EXPERT:       { cols = 30, rows = 16, mines = 99, cell = 28, label = "高级" },
	Difficulty.CUSTOM:       { cols = 9,  rows = 9,  mines = 10, cell = 36, label = "自定义" },
}

enum CellType { HIDDEN, REVEALED, FLAGGED, QUESTION }

# ─── 当前难度参数 ────────────────────────────────────
var current_difficulty := Difficulty.BEGINNER
var grid_cols := 9
var grid_rows := 9
var mine_total := 10
var cell_size := 48

# ─── 自定义开局参数 ──────────────────────────────────
var custom_cols := 9
var custom_rows := 9
var custom_mines := 10
const CUSTOM_MIN_COLS := 5
const CUSTOM_MAX_COLS := 50
const CUSTOM_MIN_ROWS := 5
const CUSTOM_MAX_ROWS := 50
const CUSTOM_CELL := 36

# ─── 状态变量 ───────────────────────────────────────
var grid_mine: Array[bool]
var grid_state: Array[int]
var grid_adjacent: Array[int]
var grid_cells: Array[Node]

var first_click := true
var game_active := false
var game_won := false
var cells_revealed := 0
var flag_count := 0
var elapsed := 0
var exploded_idx := -1

# ─── 节点引用 ───────────────────────────────────────
var board_wrapper: CenterContainer
var board: Container
var mine_label: Label
var timer_label: Label
var restart_btn: Button
var result_overlay: ColorRect
var result_label: Label
var play_again_btn: Button
var timer_node: Timer
var diff_btns: Array[Button]
var hud: HBoxContainer

# ─── 自定义对话框节点 ────────────────────────────────
var custom_dialog: ColorRect
var custom_cols_input: SpinBox
var custom_rows_input: SpinBox
var custom_mines_input: SpinBox
var custom_error_label: Label

# ─── 音效管理器 ──────────────────────────────────────────
var audio: Node

# ─── 排行榜 ────────────────────────────────────────────────
var leaderboard: Node
var leaderboard_panel: ColorRect
var leaderboard_list: VBoxContainer

# ─── 触摸输入（移动端）──────────────────────────
var is_mobile := false
var _touch_index := -1
var _touch_cell: Control = null
var _touch_hold_time: float = 0.0
const LONG_PRESS_THRESHOLD := 0.3

# ─── 爬塔模式（Roguelike）───────────────────────────
var rogue_mode := false
var rogue_manager_ref = null
var rogue_hud: ColorRect
var rogue_floor_label: Label
var relic_selection_dialog: ColorRect
var floor_transition_overlay: ColorRect
var _rogue_tutorial_shown := false

# ─── RPG 模式 ──────────────────────────────────────
var rpg_mode := false
var rpg_manager_ref = null
var rpg_hud: ColorRect
var rpg_stats_label: Label
var rpg_battle_dialog: ColorRect
var _rpg_chain_count := 0

# ─── 主题系统 ───────────────────────────────────────
enum GameTheme { DARK, LIGHT, CLASSIC, NEON }

const THEMES := {
	GameTheme.DARK: {
		hidden = Color("#3a3a4a"), hidden_hover = Color("#4e4e5e"),
		revealed = Color("#6a6a7a"), flagged = Color("#3a3a4a"),
		question = Color("#3a3a4a"), mine_bg = Color("#cc3333"),
		exploded_bg = Color("#ff2222"),
		diff_btn = Color("#2a2a3a"), diff_btn_active = Color("#4a6a8a"),
		number = { 1:Color("#4a8cff"),2:Color("#4acf4a"),3:Color("#ff4a4a"),
			4:Color("#2a2a8a"),5:Color("#8a2a2a"),6:Color("#2a8a8a"),
			7:Color("#1a1a1a"),8:Color("#6a6a6a") },
	},
	GameTheme.LIGHT: {
		hidden = Color("#c0c0c0"), hidden_hover = Color("#d4d4d4"),
		revealed = Color("#e8e8e8"), flagged = Color("#c0c0c0"),
		question = Color("#c0c0c0"), mine_bg = Color("#cc3333"),
		exploded_bg = Color("#ff4444"),
		diff_btn = Color("#a0a0b0"), diff_btn_active = Color("#6a8aba"),
		number = { 1:Color("#0000ff"),2:Color("#008000"),3:Color("#ff0000"),
			4:Color("#000080"),5:Color("#800000"),6:Color("#008080"),
			7:Color("#000000"),8:Color("#808080") },
	},
	GameTheme.CLASSIC: {
		hidden = Color("#808080"), hidden_hover = Color("#969696"),
		revealed = Color("#c0c0c0"), flagged = Color("#808080"),
		question = Color("#808080"), mine_bg = Color("#cc0000"),
		exploded_bg = Color("#ff0000"),
		diff_btn = Color("#707070"), diff_btn_active = Color("#008080"),
		number = { 1:Color("#0000ff"),2:Color("#008000"),3:Color("#ff0000"),
			4:Color("#000080"),5:Color("#800000"),6:Color("#008080"),
			7:Color("#000000"),8:Color("#808080") },
	},
	GameTheme.NEON: {
		hidden = Color("#1a0033"), hidden_hover = Color("#2a004d"),
		revealed = Color("#0d001a"), flagged = Color("#1a0033"),
		question = Color("#1a0033"), mine_bg = Color("#ff0066"),
		exploded_bg = Color("#ff0044"),
		diff_btn = Color("#1a0033"), diff_btn_active = Color("#660099"),
		number = { 1:Color("#00ffff"),2:Color("#00ff88"),3:Color("#ff0066"),
			4:Color("#ff00ff"),5:Color("#ff8800"),6:Color("#ffcc00"),
			7:Color("#ffffff"),8:Color("#8866aa") },
	},
}

var current_theme := GameTheme.DARK
var palette := {}


# ═══════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════

func _ready() -> void:
	rpg_mode = game_state.rpg_mode
	rogue_mode = game_state.rogue_mode

	_apply_difficulty_params()
	palette = THEMES[current_theme].duplicate(true)
	_build_hud()
	_build_board()
	_build_result_dialog()
	_build_timer()
	_build_custom_dialog()
	_build_leaderboard_dialog()
	leaderboard_init()
	_build_rogue_hud()
	_build_relic_selection_dialog()
	_build_floor_transition()

	# RPG 模式初始化
	if rpg_mode:
		_build_rpg_hud()
		_build_rpg_battle_dialog()
		_init_rpg_mode()

	_update_window_size()
	_build_audio()
	reset_game()
	_apply_theme()

	# 爬塔模式初始化
	if rogue_mode:
		_init_rogue_mode()


# ═══════════════════════════════════════════════════
#  难度参数
# ═══════════════════════════════════════════════════

func _apply_difficulty_params() -> void:
	if current_difficulty == Difficulty.CUSTOM:
		grid_cols = custom_cols
		grid_rows = custom_rows
		mine_total = custom_mines
		cell_size = CUSTOM_CELL
		var max_dim: int = max(custom_cols, custom_rows)
		if max_dim > 30:
			cell_size = 24
		if max_dim > 40:
			cell_size = 18
		return
	var cfg = DIFFICULTY_CONFIG[current_difficulty]
	grid_cols = cfg.cols
	grid_rows = cfg.rows
	mine_total = cfg.mines
	cell_size = cfg.cell


# ═══════════════════════════════════════════════════
#  UI 构建
# ═══════════════════════════════════════════════════

func _build_hud() -> void:
	hud = HBoxContainer.new()
	hud.name = "HUD"
	hud.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hud.anchor_left = 0.0
	hud.anchor_top = 0.0
	hud.anchor_right = 1.0
	hud.offset_bottom = 40.0
	add_child(hud)

	for d in [Difficulty.BEGINNER, Difficulty.INTERMEDIATE, Difficulty.EXPERT, Difficulty.CUSTOM]:
		var btn = Button.new()
		btn.text = DIFFICULTY_CONFIG[d].label
		btn.custom_minimum_size = Vector2(48, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color("#c0c0d0"))
		btn.pressed.connect(_on_difficulty_pressed.bind(d))
		diff_btns.append(btn)
		hud.add_child(btn)

	var mine_icon = Label.new()
	mine_icon.text = " 💣"
	mine_icon.add_theme_font_size_override("font_size", 18)
	hud.add_child(mine_icon)

	mine_label = Label.new()
	mine_label.add_theme_font_size_override("font_size", 22)
	mine_label.add_theme_color_override("font_color", Color("#ff6666"))
	mine_label.size_flags_horizontal = Control.SIZE_EXPAND
	hud.add_child(mine_label)

	restart_btn = Button.new()
	restart_btn.text = "😊"
	restart_btn.custom_minimum_size = Vector2(36, 32)
	restart_btn.add_theme_font_size_override("font_size", 20)
	restart_btn.pressed.connect(reset_game)
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND
	restart_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(restart_btn)

	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color("#ff6666"))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size_flags_horizontal = Control.SIZE_EXPAND
	hud.add_child(timer_label)

	var timer_icon = Label.new()
	timer_icon.text = "⏱ "
	timer_icon.add_theme_font_size_override("font_size", 18)
	hud.add_child(timer_icon)

	var lb_btn = Button.new()
	lb_btn.text = "🏆"
	lb_btn.custom_minimum_size = Vector2(32, 28)
	lb_btn.add_theme_font_size_override("font_size", 14)
	lb_btn.pressed.connect(_show_leaderboard)
	hud.add_child(lb_btn)

	var theme_btn = Button.new()
	theme_btn.text = "🎨"
	theme_btn.custom_minimum_size = Vector2(32, 28)
	theme_btn.add_theme_font_size_override("font_size", 14)
	theme_btn.pressed.connect(_cycle_theme)
	hud.add_child(theme_btn)

	_update_diff_buttons()


func _update_diff_buttons() -> void:
	for i in range(diff_btns.size()):
		var d = [Difficulty.BEGINNER, Difficulty.INTERMEDIATE, Difficulty.EXPERT, Difficulty.CUSTOM][i]
		var btn = diff_btns[i]
		if d == current_difficulty:
			btn.add_theme_stylebox_override("normal", _make_stylebox(palette.diff_btn_active))
		else:
			btn.add_theme_stylebox_override("normal", _make_stylebox(palette.diff_btn))


func _make_stylebox(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_border_width_all(1)
	sb.border_color = Color("#4a4a5a")
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _build_board() -> void:
	board_wrapper = CenterContainer.new()
	board_wrapper.name = "BoardWrapper"
	board_wrapper.anchor_left = 0.0
	board_wrapper.anchor_top = 0.0
	board_wrapper.anchor_right = 1.0
	board_wrapper.anchor_bottom = 1.0
	board_wrapper.offset_top = 45.0
	board_wrapper.offset_bottom = -80.0
	add_child(board_wrapper)

	board = GridContainer.new()
	board.name = "Board"
	board.columns = grid_cols
	board_wrapper.add_child(board)

	for row in range(grid_rows):
		for col in range(grid_cols):
			var cell = _make_cell(col, row)
			board.add_child(cell)
			grid_cells.append(cell)


func _rebuild_board() -> void:
	for cell in grid_cells:
		if is_instance_valid(cell):
			cell.queue_free()
	grid_cells.clear()

	if is_instance_valid(board):
		board.queue_free()

	board = GridContainer.new()
	board.name = "Board"
	board.columns = grid_cols
	board_wrapper.add_child(board)

	var total = grid_cols * grid_rows
	grid_mine.resize(total)
	grid_state.resize(total)
	grid_adjacent.resize(total)

	for row in range(grid_rows):
		for col in range(grid_cols):
			var cell = _make_cell(col, row)
			board.add_child(cell)
			grid_cells.append(cell)


func _make_cell(col: int, row: int) -> Control:
	var cell = ColorRect.new()
	cell.custom_minimum_size = Vector2(cell_size, cell_size)
	cell.size = Vector2(cell_size, cell_size)
	cell.color = palette.hidden
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_entered.connect(_on_cell_hover.bind(cell))
	cell.mouse_exited.connect(_on_cell_hover_end.bind(cell))

	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND
	label.size_flags_vertical = Control.SIZE_EXPAND
	label.add_theme_font_size_override("font_size", max(12, cell_size / 2))
	label.add_theme_color_override("font_color", Color.WHITE)
	cell.add_child(label)

	cell.set_meta("grid_col", col)
	cell.set_meta("grid_row", row)
	cell.gui_input.connect(_on_cell_gui_input.bind(cell))

	return cell


func _build_result_dialog() -> void:
	result_overlay = ColorRect.new()
	result_overlay.name = "ResultDialog"
	result_overlay.color = Color(0, 0, 0, 0.65)
	result_overlay.anchor_left = 0.0
	result_overlay.anchor_top = 0.0
	result_overlay.anchor_right = 1.0
	result_overlay.anchor_bottom = 1.0
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.hide()
	add_child(result_overlay)

	var panel = ColorRect.new()
	panel.color = Color("#2a2a3a")
	panel.custom_minimum_size = Vector2(280, 160)
	panel.size = Vector2(280, 160)
	panel.position = Vector2(140, 180)
	result_overlay.add_child(panel)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.position = Vector2(0, 20)
	result_label.size = Vector2(280, 60)
	result_label.add_theme_font_size_override("font_size", 32)
	panel.add_child(result_label)

	play_again_btn = Button.new()
	play_again_btn.text = "再来一局"
	play_again_btn.position = Vector2(70, 100)
	play_again_btn.custom_minimum_size = Vector2(140, 40)
	play_again_btn.add_theme_font_size_override("font_size", 18)
	play_again_btn.pressed.connect(_on_play_again)
	panel.add_child(play_again_btn)


func _build_timer() -> void:
	timer_node = Timer.new()
	timer_node.name = "GameTimer"
	timer_node.one_shot = false
	timer_node.wait_time = 1.0
	timer_node.timeout.connect(_on_timer_tick)
	add_child(timer_node)


func _update_window_size() -> void:
	var pad := 40
	var w := cell_size * grid_cols + pad * 2
	var h := cell_size * grid_rows + 45 + 80 + pad
	# RPG 模式 HUD 更高
	if rpg_mode:
		h += 40
	get_window().size = Vector2i(max(400, w), max(400, h))


func _apply_theme() -> void:
	palette = THEMES[current_theme].duplicate(true)
	if grid_cells.is_empty():
		return
	_update_all_cells()
	_update_diff_buttons()


func _cycle_theme() -> void:
	var n = GameTheme.size()
	current_theme = (current_theme + 1) % n
	_apply_theme()


# ═══════════════════════════════════════════════════
#  UI 动效
# ═══════════════════════════════════════════════════

func _animate_cell_pop(cell: Control) -> void:
	if not is_instance_valid(cell):
		return
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cell, "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(cell, "scale", Vector2(1.0, 1.0), 0.12)


func _animate_boom() -> void:
	if not is_instance_valid(board_wrapper):
		return
	var orig := board_wrapper.position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for i in range(3):
		tween.tween_property(board_wrapper, "position", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.03)
	tween.tween_property(board_wrapper, "position", orig, 0.05)


func _animate_result_dialog() -> void:
	if not is_instance_valid(result_overlay):
		return
	var panel = result_overlay.get_child(0) if result_overlay.get_child_count() > 0 else null
	if panel and panel.has_method("set_scale"):
		panel.scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3)


func _build_audio() -> void:
	var AudioManager = load("res://scripts/audio_manager.gd")
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	audio_connect_signals()


func audio_connect_signals() -> void:
	game_started.connect(func(): audio.play("start"))
	game_ended.connect(func(won: bool):
		audio.play("win" if won else "lose")
	)


func leaderboard_init() -> void:
	var LB = load("res://scripts/leaderboard.gd")
	leaderboard = LB.new()
	leaderboard.name = "Leaderboard"
	add_child(leaderboard)
	game_ended.connect(_on_game_ended_save)


func _on_game_ended_save(won: bool) -> void:
	if not won:
		return
	var diff_name: String = DIFFICULTY_CONFIG.get(current_difficulty, {}).get("label", "自定义")
	leaderboard.add_record(diff_name, grid_cols, grid_rows, mine_total, elapsed, won)


# ═══════════════════════════════════════════════════
#  自定义开局对话框
# ═══════════════════════════════════════════════════

func _build_custom_dialog() -> void:
	custom_dialog = ColorRect.new()
	custom_dialog.name = "CustomDialog"
	custom_dialog.color = Color(0, 0, 0, 0.75)
	custom_dialog.anchor_left = 0.0
	custom_dialog.anchor_top = 0.0
	custom_dialog.anchor_right = 1.0
	custom_dialog.anchor_bottom = 1.0
	custom_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	custom_dialog.hide()
	add_child(custom_dialog)

	var panel = ColorRect.new()
	panel.color = Color("#2a2a3a")
	panel.custom_minimum_size = Vector2(300, 260)
	panel.size = Vector2(300, 260)
	panel.position = Vector2(130, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	custom_dialog.add_child(panel)

	var title = Label.new()
	title.text = "自定义开局"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 16)
	title.size = Vector2(300, 30)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#e0e0f0"))
	panel.add_child(title)

	var cl = Label.new()
	cl.text = "列数 (5-50):"
	cl.position = Vector2(20, 60)
	cl.size = Vector2(140, 24)
	cl.add_theme_font_size_override("font_size", 14)
	panel.add_child(cl)

	custom_cols_input = SpinBox.new()
	custom_cols_input.position = Vector2(170, 56)
	custom_cols_input.size = Vector2(100, 28)
	custom_cols_input.min_value = CUSTOM_MIN_COLS
	custom_cols_input.max_value = CUSTOM_MAX_COLS
	custom_cols_input.value = custom_cols
	custom_cols_input.step = 1
	custom_cols_input.rounded = true
	custom_cols_input.value_changed.connect(_on_custom_param_changed)
	panel.add_child(custom_cols_input)

	var rl = Label.new()
	rl.text = "行数 (5-50):"
	rl.position = Vector2(20, 96)
	rl.size = Vector2(140, 24)
	rl.add_theme_font_size_override("font_size", 14)
	panel.add_child(rl)

	custom_rows_input = SpinBox.new()
	custom_rows_input.position = Vector2(170, 92)
	custom_rows_input.size = Vector2(100, 28)
	custom_rows_input.min_value = CUSTOM_MIN_ROWS
	custom_rows_input.max_value = CUSTOM_MAX_ROWS
	custom_rows_input.value = custom_rows
	custom_rows_input.step = 1
	custom_rows_input.rounded = true
	custom_rows_input.value_changed.connect(_on_custom_param_changed)
	panel.add_child(custom_rows_input)

	var ml = Label.new()
	ml.text = "雷数:"
	ml.position = Vector2(20, 132)
	ml.size = Vector2(140, 24)
	ml.add_theme_font_size_override("font_size", 14)
	panel.add_child(ml)

	custom_mines_input = SpinBox.new()
	custom_mines_input.position = Vector2(170, 128)
	custom_mines_input.size = Vector2(100, 28)
	custom_mines_input.min_value = 1
	custom_mines_input.max_value = 999
	custom_mines_input.value = custom_mines
	custom_mines_input.step = 1
	custom_mines_input.rounded = true
	custom_mines_input.value_changed.connect(_on_custom_param_changed)
	panel.add_child(custom_mines_input)

	custom_error_label = Label.new()
	custom_error_label.position = Vector2(20, 164)
	custom_error_label.size = Vector2(260, 24)
	custom_error_label.add_theme_font_size_override("font_size", 12)
	custom_error_label.add_theme_color_override("font_color", Color("#ff6666"))
	panel.add_child(custom_error_label)

	var confirm_btn = Button.new()
	confirm_btn.text = "开始"
	confirm_btn.position = Vector2(40, 200)
	confirm_btn.custom_minimum_size = Vector2(100, 36)
	confirm_btn.add_theme_font_size_override("font_size", 16)
	confirm_btn.pressed.connect(_on_custom_confirm)
	panel.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(160, 200)
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(_on_custom_cancel)
	panel.add_child(cancel_btn)


func _show_custom_dialog() -> void:
	custom_cols_input.value = custom_cols
	custom_rows_input.value = custom_rows
	custom_mines_input.value = custom_mines
	_validate_custom_params()
	custom_dialog.show()


func _validate_custom_params() -> bool:
	var c := int(custom_cols_input.value)
	var r := int(custom_rows_input.value)
	var m := int(custom_mines_input.value)
	var max_mines := c * r - 9
	if m <= 0:
		custom_error_label.text = "雷数必须大于 0"
		return false
	elif m >= c * r:
		custom_error_label.text = "雷数不能超过总格数"
		return false
	elif m > max_mines:
		custom_error_label.text = "雷数过多，请至少留 9 格安全区"
		return false
	else:
		custom_error_label.text = ""
		return true


func _on_custom_param_changed(_val: float) -> void:
	_validate_custom_params()


func _on_custom_confirm() -> void:
	if not _validate_custom_params():
		return
	custom_cols = int(custom_cols_input.value)
	custom_rows = int(custom_rows_input.value)
	custom_mines = int(custom_mines_input.value)

	current_difficulty = Difficulty.CUSTOM
	_apply_difficulty_params()
	_update_diff_buttons()
	_rebuild_board()
	_update_window_size()
	reset_game()
	custom_dialog.hide()
	difficulty_changed.emit(Difficulty.CUSTOM)


func _on_custom_cancel() -> void:
	custom_dialog.hide()
	_update_diff_buttons()


# ═══════════════════════════════════════════════════
#  排行榜对话框
# ═══════════════════════════════════════════════════

func _build_leaderboard_dialog() -> void:
	leaderboard_panel = ColorRect.new()
	leaderboard_panel.name = "LeaderboardDialog"
	leaderboard_panel.color = Color(0, 0, 0, 0.75)
	leaderboard_panel.anchor_left = 0.0
	leaderboard_panel.anchor_top = 0.0
	leaderboard_panel.anchor_right = 1.0
	leaderboard_panel.anchor_bottom = 1.0
	leaderboard_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	leaderboard_panel.hide()
	add_child(leaderboard_panel)

	var panel = ColorRect.new()
	panel.color = Color("#2a2a3a")
	panel.custom_minimum_size = Vector2(360, 320)
	panel.size = Vector2(360, 320)
	panel.position = Vector2(100, 120)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	leaderboard_panel.add_child(panel)

	var title = Label.new()
	title.text = "🏆 排行榜"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 16)
	title.size = Vector2(360, 30)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#e0e0f0"))
	panel.add_child(title)

	var header = HBoxContainer.new()
	header.position = Vector2(12, 50)
	header.size = Vector2(336, 24)
	_add_lb_header(header, "#", 30)
	_add_lb_header(header, "难度", 48)
	_add_lb_header(header, "网格", 48)
	_add_lb_header(header, "雷", 30)
	_add_lb_header(header, "用时", 60)
	_add_lb_header(header, "日期", 100)
	panel.add_child(header)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(12, 76)
	scroll.size = Vector2(336, 200)
	panel.add_child(scroll)

	leaderboard_list = VBoxContainer.new()
	leaderboard_list.size_flags_horizontal = Control.SIZE_EXPAND
	scroll.add_child(leaderboard_list)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(130, 284)
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func(): leaderboard_panel.hide())
	panel.add_child(close_btn)

	var clear_btn = Button.new()
	clear_btn.text = "清空"
	clear_btn.position = Vector2(16, 284)
	clear_btn.custom_minimum_size = Vector2(60, 28)
	clear_btn.add_theme_font_size_override("font_size", 12)
	clear_btn.pressed.connect(_clear_leaderboard)
	panel.add_child(clear_btn)


func _add_lb_header(parent: HBoxContainer, text: String, w: int) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(w, 22)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color("#8888aa"))
	parent.add_child(lbl)


func _show_leaderboard() -> void:
	_refresh_leaderboard()
	leaderboard_panel.show()


func _refresh_leaderboard() -> void:
	for child in leaderboard_list.get_children():
		child.queue_free()

	var top = leaderboard.get_top(15)
	if top.is_empty():
		var empty = Label.new()
		empty.text = "  暂无记录"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color("#666688"))
		leaderboard_list.add_child(empty)
		return

	for i in range(top.size()):
		var r = top[i]
		var row = HBoxContainer.new()
		_add_lb_cell(row, str(i + 1), 30)
		_add_lb_cell(row, r.difficulty, 48)
		_add_lb_cell(row, str(r.cols) + "x" + str(r.rows), 48)
		_add_lb_cell(row, str(r.mines), 30)
		_add_lb_cell(row, leaderboard.format_time(r.time), 60)
		_add_lb_cell(row, r.date.substr(0, 10), 100)
		leaderboard_list.add_child(row)


func _add_lb_cell(parent: HBoxContainer, text: String, w: int) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(w, 20)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#c0c0d0"))
	parent.add_child(lbl)


func _clear_leaderboard() -> void:
	leaderboard.clear_all()
	_refresh_leaderboard()


# ═══════════════════════════════════════════════════
#  爬塔 UI（Roguelike HUD）
# ═══════════════════════════════════════════════════

const ROGUE_RARITY_COLORS := {
	"common": Color("#a0a0c0"),
	"rare": Color("#4a8cff"),
	"legendary": Color("#ffaa00"),
	"???": Color("#ff44ff"),
}


func _build_rogue_hud() -> void:
	rogue_hud = ColorRect.new()
	rogue_hud.name = "RogueHUD"
	rogue_hud.color = Color("#1a1a2e")
	rogue_hud.anchor_left = 0.0
	rogue_hud.anchor_top = 0.0
	rogue_hud.anchor_right = 1.0
	rogue_hud.offset_top = 42
	rogue_hud.offset_bottom = 70
	rogue_hud.mouse_filter = Control.MOUSE_FILTER_PASS
	rogue_hud.hide()
	add_child(rogue_hud)

	rogue_floor_label = Label.new()
	rogue_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rogue_floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rogue_floor_label.add_theme_font_size_override("font_size", 13)
	rogue_floor_label.add_theme_color_override("font_color", Color("#e0e0f0"))
	rogue_floor_label.anchor_left = 0.0
	rogue_floor_label.anchor_top = 0.0
	rogue_floor_label.anchor_right = 1.0
	rogue_floor_label.anchor_bottom = 1.0
	rogue_hud.add_child(rogue_floor_label)


func _update_rogue_hud() -> void:
	if not is_instance_valid(rogue_manager_ref):
		if is_instance_valid(rogue_hud):
			rogue_hud.hide()
		return
	var floor: int = rogue_manager_ref.current_floor
	var hp: int = rogue_manager_ref.hp
	var max_hp: int = rogue_manager_ref.max_hp
	var hearts := ""
	for i in range(max_hp):
		hearts += "❤️" if i < hp else "🖤"
	var relic_text := ""
	for rid in rogue_manager_ref.get_relic_list():
		var def = rogue_manager_ref.relics_node.get_def(rid)
		if def:
			relic_text += def.icon + " "
	rogue_floor_label.text = "🏰 第%d层 | %s | %s" % [floor, hearts, relic_text]


# ═══════════════════════════════════════════════════
#  遗物选择对话框
# ═══════════════════════════════════════════════════

func _build_relic_selection_dialog() -> void:
	relic_selection_dialog = ColorRect.new()
	relic_selection_dialog.name = "RelicSelection"
	relic_selection_dialog.color = Color(0, 0, 0, 0.75)
	relic_selection_dialog.anchor_left = 0.0
	relic_selection_dialog.anchor_top = 0.0
	relic_selection_dialog.anchor_right = 1.0
	relic_selection_dialog.anchor_bottom = 1.0
	relic_selection_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	relic_selection_dialog.hide()
	add_child(relic_selection_dialog)


func _show_relic_selection() -> void:
	# 清除旧内容
	for child in relic_selection_dialog.get_children():
		child.queue_free()
	await get_tree().process_frame

	# 获取3个候选遗物
	var candidates: Array = rogue_manager_ref.draw_relic_candidates(3)

	var panel := ColorRect.new()
	panel.color = Color("#1a1a2e")
	panel.custom_minimum_size = Vector2(400, 320)
	panel.size = Vector2(400, 320)
	panel.position = Vector2(80, 120)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	relic_selection_dialog.add_child(panel)

	var title := Label.new()
	title.text = "✨ 选择遗物"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(400, 32)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ffcc00"))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "通关第 " + str(rogue_manager_ref.current_floor) + " 层！选择一个遗物强化"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 44)
	subtitle.size = Vector2(400, 20)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#8888aa"))
	panel.add_child(subtitle)

	# 3个遗物卡片
	var card_start_x := 20
	var card_width := 112
	var card_gap := 12
	var card_y := 80
	var card_h := 180

	for i in range(candidates.size()):
		var rid = candidates[i] as int
		var def = rogue_manager_ref.relics_node.get_def(rid)
		if not def:
			continue
		var cx := card_start_x + i * (card_width + card_gap)

		# 稀有度边框
		var border_color: Color = ROGUE_RARITY_COLORS.get(def.rarity, Color("#a0a0c0"))
		var border_rect := ColorRect.new()
		border_rect.position = Vector2(cx - 1, card_y - 1)
		border_rect.size = Vector2(card_width + 2, card_h + 2)
		border_rect.color = border_color
		border_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.add_child(border_rect)

		# 卡片底色
		var card := ColorRect.new()
		card.position = Vector2(cx, card_y)
		card.size = Vector2(card_width, card_h)
		card.color = Color("#2a2a3a")
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_child(card)

		# 图标
		var icon := Label.new()
		icon.text = def.icon
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.position = Vector2(cx, card_y + 16)
		icon.size = Vector2(card_width, 36)
		icon.add_theme_font_size_override("font_size", 30)
		panel.add_child(icon)

		# 名称
		var name_lbl := Label.new()
		name_lbl.text = def.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(cx, card_y + 58)
		name_lbl.size = Vector2(card_width, 24)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", border_color)
		panel.add_child(name_lbl)

		# 描述
		var desc := Label.new()
		desc.text = def.desc
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc.position = Vector2(cx + 4, card_y + 84)
		desc.size = Vector2(card_width - 8, 60)
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color("#c0c0d0"))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(desc)

		# 稀有度标签
		var rarity_lbl := Label.new()
		var rarity_name := {"common": "普通", "rare": "稀有", "legendary": "传说", "???": "???"}
		rarity_lbl.text = rarity_name.get(def.rarity, def.rarity)
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.position = Vector2(cx, card_y + card_h - 26)
		rarity_lbl.size = Vector2(card_width, 20)
		rarity_lbl.add_theme_font_size_override("font_size", 10)
		rarity_lbl.add_theme_color_override("font_color", border_color)
		panel.add_child(rarity_lbl)

		# 点击卡片选择遗物
		card.gui_input.connect(_on_relic_card_click.bind(rid))

	var skip_btn := Button.new()
	skip_btn.text = "跳过（不要遗物）"
	skip_btn.position = Vector2(140, 280)
	skip_btn.size = Vector2(120, 28)
	skip_btn.add_theme_font_size_override("font_size", 11)
	skip_btn.pressed.connect(_on_relic_skipped)
	panel.add_child(skip_btn)

	relic_selection_dialog.show()


func _on_relic_card_click(event: InputEvent, rid: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	rogue_manager_ref.add_relic(rid)
	relic_selection_dialog.hide()
	_update_rogue_hud()
	_proceed_to_next_floor()


func _on_relic_skipped() -> void:
	relic_selection_dialog.hide()
	_proceed_to_next_floor()


func _proceed_to_next_floor() -> void:
	if not is_instance_valid(rogue_manager_ref):
		return
	rogue_manager_ref.next_floor()
	if not rogue_manager_ref.active:
		return  # game_over 信号会处理

	var cfg = rogue_manager_ref.get_floor_config()
	grid_cols = cfg.cols
	grid_rows = cfg.rows
	mine_total = cfg.mines
	cell_size = 36
	_update_window_size()
	_rebuild_board()
	reset_game()
	_update_rogue_hud()
	_show_floor_transition()


# ═══════════════════════════════════════════════════
#  层数过渡提示
# ═══════════════════════════════════════════════════

func _build_floor_transition() -> void:
	floor_transition_overlay = ColorRect.new()
	floor_transition_overlay.name = "FloorTransition"
	floor_transition_overlay.color = Color(0, 0, 0, 0.6)
	floor_transition_overlay.anchor_left = 0.0
	floor_transition_overlay.anchor_top = 0.0
	floor_transition_overlay.anchor_right = 1.0
	floor_transition_overlay.anchor_bottom = 1.0
	floor_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	floor_transition_overlay.hide()
	add_child(floor_transition_overlay)


func _show_floor_transition() -> void:
	for child in floor_transition_overlay.get_children():
		child.queue_free()
	await get_tree().process_frame

	if not is_instance_valid(rogue_manager_ref):
		return

	var cfg = rogue_manager_ref.get_floor_config()
	var floor: int = rogue_manager_ref.current_floor

	var color_icons := ["", "", "🟢", "🟢", "🟡", "🟡", "🟠", "🟠", "🔴", "🔴", "👑"]
	var ci := mini(floor, 10)
	var label_txt := "%s 第%d层" % [color_icons[ci], floor]
	var info_txt := "%d×%d 网格 · %d颗雷" % [cfg.cols, cfg.rows, cfg.mines]

	var label := Label.new()
	label.text = label_txt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 200)
	label.size = Vector2(get_window().size.x if get_window() else 600, 60)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color("#ffffff"))
	floor_transition_overlay.add_child(label)

	var info := Label.new()
	info.text = info_txt
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.position = Vector2(0, 260)
	info.size = Vector2(get_window().size.x if get_window() else 600, 30)
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color("#c0c0d0"))
	floor_transition_overlay.add_child(info)

	floor_transition_overlay.show()

	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(floor_transition_overlay):
		floor_transition_overlay.hide()


# ═══════════════════════════════════════════════════
#  爬塔引导说明
# ═══════════════════════════════════════════════════

func _show_rogue_tutorial() -> void:
	if _rogue_tutorial_shown:
		return
	_rogue_tutorial_shown = true

	var overlay := ColorRect.new()
	overlay.name = "RogueTutorial"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := ColorRect.new()
	panel.color = Color("#1a1a2e")
	panel.custom_minimum_size = Vector2(360, 280)
	panel.size = Vector2(360, 280)
	panel.position = Vector2(100, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var title := Label.new()
	title.text = "🏰 爬塔模式说明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 16)
	title.size = Vector2(360, 30)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#ffcc00"))
	panel.add_child(title)

	var text := Label.new()
	text.text = "• 共 10 层地牢，每层递进难度\n• 你有 3 条命（❤️❤️❤️），踩雷扣血\n• 每通关一层可从 3 个遗物中选 1 个\n• 遗物持续生效直到通关或阵亡\n• 每层开始时 HP 回满\n\n💡 踩雷不会立即死亡，但会暴露雷位\n💡 多利用遗物组合效果"
	text.position = Vector2(20, 56)
	text.size = Vector2(320, 170)
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_color", Color("#c0c0d0"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)

	var ok_btn := Button.new()
	ok_btn.text = "开始挑战！"
	ok_btn.position = Vector2(120, 240)
	ok_btn.custom_minimum_size = Vector2(120, 32)
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(func():
		overlay.queue_free()
		panel.queue_free()
	)
	panel.add_child(ok_btn)


# ═══════════════════════════════════════════════════
#  RPG UI
# ═══════════════════════════════════════════════════

func _build_rpg_hud() -> void:
	rpg_hud = ColorRect.new()
	rpg_hud.name = "RpgHUD"
	rpg_hud.color = Color("#0d1a0d")
	rpg_hud.anchor_left = 0.0
	rpg_hud.anchor_top = 0.0
	rpg_hud.anchor_right = 1.0
	rpg_hud.offset_top = 42
	rpg_hud.offset_bottom = 72
	rpg_hud.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(rpg_hud)

	rpg_stats_label = Label.new()
	rpg_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rpg_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rpg_stats_label.add_theme_font_size_override("font_size", 12)
	rpg_stats_label.add_theme_color_override("font_color", Color("#c0e0c0"))
	rpg_stats_label.anchor_left = 0.0
	rpg_stats_label.anchor_top = 0.0
	rpg_stats_label.anchor_right = 1.0
	rpg_stats_label.anchor_bottom = 1.0
	rpg_hud.add_child(rpg_stats_label)


func _update_rpg_hud() -> void:
	if not is_instance_valid(rpg_manager_ref):
		return
	var s = rpg_manager_ref.stats
	var hp_bar := ""
	for i in range(s.max_hp / 5):
		hp_bar += "❤️" if i * 5 < s.hp else "🖤"
	var xp_total := rpg_manager_ref._xp_for_level(s.level)
	var combo_text := ""
	if _rpg_chain_count > 0:
		combo_text = " | 🔗 Combo x%d" % _rpg_chain_count
	rpg_stats_label.text = "%s | Lv.%d | ⚔️ATK:%d | 🛡️DEF:%d | 💰%d | XP:%d/%d%s" % \
		[hp_bar, s.level, s.atk, s.defense, s.gold, s.xp, xp_total, combo_text]


func _build_rpg_battle_dialog() -> void:
	rpg_battle_dialog = ColorRect.new()
	rpg_battle_dialog.name = "RpgBattleDialog"
	rpg_battle_dialog.color = Color(0, 0, 0, 0.7)
	rpg_battle_dialog.anchor_left = 0.0
	rpg_battle_dialog.anchor_top = 0.0
	rpg_battle_dialog.anchor_right = 1.0
	rpg_battle_dialog.anchor_bottom = 1.0
	rpg_battle_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	rpg_battle_dialog.hide()
	add_child(rpg_battle_dialog)


func _show_rpg_battle_result(result: Dictionary) -> void:
	# 清除旧内容
	for child in rpg_battle_dialog.get_children():
		child.queue_free()
	await get_tree().process_frame

	var monster = result.get("monster")
	var monster_name = result.get("monster_name", monster.name if monster else "???")
	var monster_icon = monster.icon if monster else "👑"
	var is_boss = result.get("is_boss", false)

	var panel := ColorRect.new()
	panel.color = Color("#1a1a1a")
	panel.custom_minimum_size = Vector2(300, 240)
	panel.size = Vector2(300, 240)
	panel.position = Vector2(110, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	rpg_battle_dialog.add_child(panel)

	if result.result == "win":
		var title_text := "%s 击败 %s！" % [monster_icon, monster_name]
		if is_boss:
			title_text = "👑 击败 Boss %s！" % monster_name

		var title := Label.new()
		title.text = title_text
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.position = Vector2(0, 16)
		title.size = Vector2(300, 32)
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color("#4acf4a") if not is_boss else Color("#ffcc00"))
		panel.add_child(title)

		var damage_text := "受到 %d 点伤害" % result.damage_taken
		var dmg_label := Label.new()
		dmg_label.text = damage_text
		dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dmg_label.position = Vector2(0, 56)
		dmg_label.size = Vector2(300, 24)
		dmg_label.add_theme_font_size_override("font_size", 14)
		dmg_label.add_theme_color_override("font_color", Color("#ff8844"))
		panel.add_child(dmg_label)

		var rewards_text := "+%d XP · +%d Gold" % [result.xp, result.gold]
		var rwd_label := Label.new()
		rwd_label.text = rewards_text
		rwd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rwd_label.position = Vector2(0, 84)
		rwd_label.size = Vector2(300, 24)
		rwd_label.add_theme_font_size_override("font_size", 16)
		rwd_label.add_theme_color_override("font_color", Color("#ffcc00"))
		panel.add_child(rwd_label)

		if result.get("leveled_up", false):
			var lv_label := Label.new()
			lv_label.text = "⬆️ 升级！Lv.%d" % rpg_manager_ref.stats.level
			lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lv_label.position = Vector2(0, 112)
			lv_label.size = Vector2(300, 24)
			lv_label.add_theme_font_size_override("font_size", 16)
			lv_label.add_theme_color_override("font_color", Color("#4acf4a"))
			panel.add_child(lv_label)
	else:
		# flee
		var title := Label.new()
		title.text = "⚔️ 不敌 %s！" % monster_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.position = Vector2(0, 16)
		title.size = Vector2(300, 32)
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color("#ff6666"))
		panel.add_child(title)

		var dmg_text := "损失 %d 点生命，撤退" % result.damage_taken
		var dmg_label := Label.new()
		dmg_label.text = dmg_text
		dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dmg_label.position = Vector2(0, 56)
		dmg_label.size = Vector2(300, 24)
		dmg_label.add_theme_font_size_override("font_size", 14)
		dmg_label.add_theme_color_override("font_color", Color("#ff8844"))
		panel.add_child(dmg_label)

		var hint_label := Label.new()
		hint_label.text = "先升级再来挑战！"
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.position = Vector2(0, 88)
		hint_label.size = Vector2(300, 24)
		hint_label.add_theme_font_size_override("font_size", 13)
		hint_label.add_theme_color_override("font_color", Color("#888888"))
		panel.add_child(hint_label)

	var ok_btn := Button.new()
	ok_btn.text = "继续" if result.result == "win" else "撤退"
	ok_btn.position = Vector2(90, 160)
	ok_btn.custom_minimum_size = Vector2(120, 36)
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(func():
		rpg_battle_dialog.hide()
		if is_boss and result.result == "dead":
			_show_result(false)
	)
	panel.add_child(ok_btn)

	rpg_battle_dialog.show()


func _show_rpg_game_over() -> void:
	result_label.text = "💀 RPG 败北！Boss 太强了…"
	result_label.add_theme_color_override("font_color", Color("#ff4a4a"))
	result_overlay.show()
	_animate_result_dialog()


# ═══════════════════════════════════════════════════
#  难度切换
# ═══════════════════════════════════════════════════

func _on_difficulty_pressed(diff: int) -> void:
	if rogue_mode:
		return  # 爬塔模式不能切换难度
	if rpg_mode:
		return  # RPG 模式不能切换难度

	if diff == current_difficulty:
		return

	if diff == Difficulty.CUSTOM:
		_show_custom_dialog()
		return

	current_difficulty = diff
	_apply_difficulty_params()
	_update_diff_buttons()
	_rebuild_board()
	_update_window_size()
	reset_game()
	difficulty_changed.emit(diff)


# ═══════════════════════════════════════════════════
#  核心逻辑
# ═══════════════════════════════════════════════════

func _init_rogue_mode() -> void:
	# 防止重复连接（重启爬塔时）
	if rogue_floor_cleared.is_connected(_on_rogue_floor_cleared):
		rogue_floor_cleared.disconnect(_on_rogue_floor_cleared)
	var RM = load("res://scripts/rogue_manager.gd")
	rogue_manager_ref = RM.new()
	rogue_manager_ref.name = "RogueManager"
	add_child(rogue_manager_ref)
	rogue_floor_cleared.connect(_on_rogue_floor_cleared)
	rogue_manager_ref.game_over.connect(_on_rogue_game_over)
	rogue_manager_ref.start_run()
	# 根据爬塔层数配置更新棋盘
	var cfg = rogue_manager_ref.get_floor_config()
	grid_cols = cfg.cols
	grid_rows = cfg.rows
	mine_total = cfg.mines
	cell_size = 36
	_update_window_size()
	_rebuild_board()
	reset_game()
	# 爬塔 UI
	if is_instance_valid(rogue_hud):
		rogue_hud.show()
	_update_rogue_hud()
	_show_rogue_tutorial()


func _on_rogue_floor_cleared() -> void:
	if not is_instance_valid(rogue_manager_ref):
		return
	_update_rogue_hud()
	# 最后一层 → 直接胜利
	if rogue_manager_ref.current_floor >= rogue_manager_ref.MAX_FLOOR:
		rogue_manager_ref.next_floor()  # 触发 game_over(true)
		return
	# 非最后一层 → 遗物选择
	_show_relic_selection()


func _on_rogue_game_over(won: bool, floor: int) -> void:
	if is_instance_valid(rogue_hud):
		rogue_hud.hide()
	if won:
		_show_result(true)
	else:
		_show_result(false)


func start_rogue_run(rm: Node) -> void:
	rogue_mode = true
	rogue_manager_ref = rm
	var cfg = rm.get_floor_config()
	grid_cols = cfg.cols
	grid_rows = cfg.rows
	mine_total = cfg.mines
	cell_size = 36
	_update_window_size()
	if is_instance_valid(board_wrapper):
		_rebuild_board()
	reset_game()
	if is_instance_valid(rogue_hud):
		rogue_hud.show()
	_update_rogue_hud()


func _rogue_long_press_threshold() -> float:
	if rogue_mode and is_instance_valid(rogue_manager_ref):
		# 调用 rogue_manager 的 LongPressThreshold() 方法
		var threshold = rogue_manager_ref.get_long_press_threshold()
		if threshold < 1.0:
			return threshold
	return LONG_PRESS_THRESHOLD


# ─── RPG 模式 ─────────────────────────────────────

func _init_rpg_mode() -> void:
	var RM = load("res://scripts/rpg_manager.gd")
	rpg_manager_ref = RM.new()
	rpg_manager_ref.name = "RpgManager"
	add_child(rpg_manager_ref)
	rpg_manager_ref.player_died.connect(_on_rpg_player_died)

	# 用初级难度开始
	current_difficulty = Difficulty.BEGINNER
	_apply_difficulty_params()
	cell_size = 36  # 小格子腾出 RPG HUD 空间
	_update_window_size()
	_rebuild_board()
	reset_game()

	if is_instance_valid(rpg_hud):
		rpg_hud.show()
	_update_rpg_hud()
	_show_rpg_tutorial()


func _show_rpg_tutorial() -> void:
	var overlay := ColorRect.new()
	overlay.name = "RpgTutorial"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := ColorRect.new()
	panel.color = Color("#0d1a0d")
	panel.custom_minimum_size = Vector2(360, 280)
	panel.size = Vector2(360, 280)
	panel.position = Vector2(100, 140)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var title := Label.new()
	title.text = "⚔️ RPG 模式说明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 16)
	title.size = Vector2(360, 30)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#4acf4a"))
	panel.add_child(title)

	var text := Label.new()
	text.text = "• 翻数字格 → 遇怪战斗（数字=怪物强度）\n• 踩雷 → Boss 战（失败则游戏结束）\n• 连消 Flood-Fill → Combo 倍率提升\n• 击败怪物获得 XP + Gold\n• 升级提升 HP/ATK/DEF\n• 清空全部格子 → 通关！\n\n💡 先翻数字小的格子练级\n💡 Combo 越高奖励越丰厚"
	text.position = Vector2(20, 56)
	text.size = Vector2(320, 170)
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_color", Color("#c0d0c0"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)

	var ok_btn := Button.new()
	ok_btn.text = "开始冒险！"
	ok_btn.position = Vector2(120, 240)
	ok_btn.custom_minimum_size = Vector2(120, 32)
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(func():
		overlay.queue_free()
		panel.queue_free()
	)
	panel.add_child(ok_btn)


func _trigger_rpg_battle(number: int, combo: int) -> void:
	if not is_instance_valid(rpg_manager_ref):
		return
	var result = rpg_manager_ref.encounter_monster(number, combo)
	_update_rpg_hud()
	if result.result == "win":
		audio.play("win")
	else:
		audio.play("lose")
	_show_rpg_battle_result(result)


func _trigger_boss_battle() -> void:
	if not is_instance_valid(rpg_manager_ref):
		_reveal_all_mines()
		return

	# Boss 战前先揭示雷区
	_reveal_all_mines()

	var result = rpg_manager_ref.encounter_boss(_rpg_chain_count)
	result.is_boss = true
	_update_rpg_hud()

	if result.result == "win":
		audio.play("win")
		_show_rpg_battle_result(result)
		# Boss 战后继续游戏
		return
	else:
		# 死亡
		game_active = false
		game_won = false
		timer_node.stop()
		restart_btn.text = "💀"
		game_ended.emit(false)
		_show_rpg_battle_result(result)


func _on_rpg_player_died() -> void:
	pass  # 由 _trigger_boss_battle 处理


func _on_play_again() -> void:
	# 爬塔模式结束后：重启新的一轮
	if rogue_mode and is_instance_valid(rogue_manager_ref) and not rogue_manager_ref.active:
		rogue_manager_ref.queue_free()
		rogue_manager_ref = null
		_init_rogue_mode()
		return
	# RPG 模式结束后：重新开始
	if rpg_mode:
		rpg_manager_ref.queue_free()
		rpg_manager_ref = null
		_init_rpg_mode()
		return
	reset_game()


func reset_game() -> void:
	var total = grid_cols * grid_rows

	grid_mine.resize(total)
	grid_state.resize(total)
	grid_adjacent.resize(total)
	grid_mine.fill(false)
	grid_state.fill(CellType.HIDDEN)
	grid_adjacent.fill(0)

	first_click = true
	game_active = false
	game_won = false
	cells_revealed = 0
	flag_count = 0
	elapsed = 0
	exploded_idx = -1
	timer_node.stop()
	_rpg_chain_count = 0

	_update_all_cells()
	mine_label.text = str(mine_total)
	timer_label.text = "000"
	restart_btn.text = "😊"
	result_overlay.hide()

	# RPG 模式重置 chain
	if is_instance_valid(rpg_manager_ref):
		rpg_manager_ref.combo_chain = 0
		_update_rpg_hud()

	flag_count_changed.emit(flag_count)
	time_changed.emit(elapsed)


func _place_mines(safe_col: int, safe_row: int) -> void:
	var total := grid_cols * grid_rows
	var candidates: Array[int] = []
	for idx in range(total):
		var c = idx % grid_cols
		var r = idx / grid_cols
		if abs(c - safe_col) > 1 or abs(r - safe_row) > 1:
			candidates.append(idx)

	candidates.shuffle()
	for i in range(min(mine_total, candidates.size())):
		grid_mine[candidates[i]] = true

	for idx in range(total):
		grid_adjacent[idx] = _count_adjacent_mines(idx % grid_cols, idx / grid_cols)


func _count_adjacent_mines(col: int, row: int) -> int:
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := col + dx
			var nr := row + dy
			if nc >= 0 and nc < grid_cols and nr >= 0 and nr < grid_rows:
				if grid_mine[nr * grid_cols + nc]:
					count += 1
	return count


func _reveal_cell(col: int, row: int) -> void:
	if col < 0 or col >= grid_cols or row < 0 or row >= grid_rows:
		return

	var idx := row * grid_cols + col
	if grid_state[idx] != CellType.HIDDEN:
		return

	if first_click:
		first_click = false
		_place_mines(col, row)
		game_active = true
		timer_node.start()
		game_started.emit()

	if grid_mine[idx]:
		exploded_idx = idx
		audio.play("boom")
		_animate_boom()
		grid_state[idx] = CellType.REVEALED
		_update_cell(col, row)

		# RPG 模式 → Boss 战
		if rpg_mode and is_instance_valid(rpg_manager_ref):
			_trigger_boss_battle()
			return

		if rogue_mode and is_instance_valid(rogue_manager_ref):
			rogue_manager_ref.record_mine_hit()
			var alive = rogue_manager_ref.take_damage()
			if alive:
				# 踩雷但还活着，继续玩
				_reveal_all_mines()
				return
			# HP 归零 → 游戏结束
			_reveal_all_mines()
			game_active = false
			game_won = false
			timer_node.stop()
			restart_btn.text = "💀"
			game_ended.emit(false)
			_show_result(false)
			return
		else:
			game_active = false
			game_won = false
			timer_node.stop()
			_reveal_all_mines()
			restart_btn.text = "😵"
			game_ended.emit(false)
			_show_result(false)
			return

	grid_state[idx] = CellType.REVEALED
	cells_revealed += 1
	var cell_node = grid_cells[idx] if idx < grid_cells.size() else null
	_update_cell(col, row)
	_animate_cell_pop(cell_node)
	audio.play("reveal")

	# RPG: 统计链数
	if rpg_mode:
		_rpg_chain_count += 1

	if rogue_mode and is_instance_valid(rogue_manager_ref):
		rogue_manager_ref.record_reveal(grid_adjacent[idx])

	if grid_adjacent[idx] == 0:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx != 0 or dy != 0:
					_reveal_cell(col + dx, row + dy)

	# RPG: 数字格触发战斗
	if rpg_mode and is_instance_valid(rpg_manager_ref) and grid_adjacent[idx] > 0:
		_trigger_rpg_battle(grid_adjacent[idx], _rpg_chain_count)
		_rpg_chain_count = 0

	if cells_revealed >= grid_cols * grid_rows - mine_total:
		game_active = false
		game_won = true
		timer_node.stop()
		restart_btn.text = "😎"
		if rogue_mode and is_instance_valid(rogue_manager_ref):
			rogue_manager_ref.record_time(elapsed)
			rogue_floor_cleared.emit()
		else:
			game_ended.emit(true)
			_show_result(true)


func _toggle_flag(col: int, row: int) -> void:
	var idx := row * grid_cols + col
	if grid_state[idx] == CellType.REVEALED:
		return

	match grid_state[idx]:
		CellType.HIDDEN:
			grid_state[idx] = CellType.FLAGGED
			flag_count += 1
			audio.play("flag")
		CellType.FLAGGED:
			grid_state[idx] = CellType.QUESTION
			flag_count -= 1
			audio.play("unflag")
		CellType.QUESTION:
			grid_state[idx] = CellType.HIDDEN
			audio.play("question")
		_:
			return

	mine_label.text = str(mine_total - flag_count)
	_update_cell(col, row)
	flag_count_changed.emit(flag_count)


func _reveal_all_mines() -> void:
	for idx in range(grid_cols * grid_rows):
		if grid_mine[idx] and grid_state[idx] != CellType.REVEALED:
			grid_state[idx] = CellType.REVEALED
			_update_cell(idx % grid_cols, idx / grid_cols)


func _show_result(won: bool) -> void:
	if rogue_mode and is_instance_valid(rogue_manager_ref):
		var f: int = rogue_manager_ref.current_floor - 1
		if f < 1:
			f = 1
		if won:
			result_label.text = "🎉 爬塔通关！全部 10 层完成！"
			result_label.add_theme_color_override("font_color", Color("#ffcc00"))
		else:
			result_label.text = "💀 止步第 " + str(f) + " 层"
			result_label.add_theme_color_override("font_color", Color("#ff4a4a"))
	elif won:
		result_label.text = "🎉 你赢了！"
		result_label.add_theme_color_override("font_color", Color("#4acf4a"))
	else:
		result_label.text = "💥 踩雷了！"
		result_label.add_theme_color_override("font_color", Color("#ff4a4a"))
	result_overlay.show()
	_animate_result_dialog()


# ═══════════════════════════════════════════════════
#  单元格渲染
# ═══════════════════════════════════════════════════

func _update_cell(col: int, row: int) -> void:
	var idx := row * grid_cols + col
	var cell := grid_cells[idx] as ColorRect
	if not cell:
		return

	var label := cell.get_child(0) as Label
	var state := grid_state[idx]

	if state == CellType.REVEALED:
		if grid_mine[idx]:
			if idx == exploded_idx:
				cell.color = palette.exploded_bg
			else:
				cell.color = palette.mine_bg
			label.text = "💣"
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			cell.color = palette.revealed
			var n := grid_adjacent[idx]
			if n > 0:
				label.text = str(n)
				label.add_theme_color_override("font_color", palette.number.get(n, Color.WHITE))
			else:
				label.text = ""
	elif state == CellType.FLAGGED:
		cell.color = palette.flagged
		label.text = "⚑"
		label.add_theme_color_override("font_color", Color("#ff6666"))
	elif state == CellType.QUESTION:
		cell.color = palette.question
		label.text = "?"
		label.add_theme_color_override("font_color", Color("#8888aa"))
	else:
		cell.color = palette.hidden
		label.text = ""


func _update_all_cells() -> void:
	for idx in range(grid_cols * grid_rows):
		_update_cell(idx % grid_cols, idx / grid_cols)


# ═══════════════════════════════════════════════════
#  输入处理（鼠标 + 触摸 + 键盘）
# ═══════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	# 键盘快捷键
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R, KEY_F5:
				reset_game()
			KEY_1:
				_on_difficulty_pressed(Difficulty.BEGINNER)
			KEY_2:
				_on_difficulty_pressed(Difficulty.INTERMEDIATE)
			KEY_3:
				_on_difficulty_pressed(Difficulty.EXPERT)
			KEY_4:
				_on_difficulty_pressed(Difficulty.CUSTOM)
			KEY_T:
				_cycle_theme()
			KEY_L:
				_show_leaderboard()
		return

	# 触摸输入（移动端）
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_touch_hold_time = 0.0
			_touch_cell = _find_cell_at(event.position)
			set_process(true)
		elif not event.pressed and event.index == _touch_index:
			var cell = _touch_cell
			var threshold = _rogue_long_press_threshold()
			var was_long = _touch_hold_time >= threshold
			_touch_index = -1
			_touch_hold_time = 0.0
			_touch_cell = null
			set_process(false)
			if not is_instance_valid(cell):
				return
			if not game_active and not first_click:
				return
			var col := cell.get_meta("grid_col") as int
			var row := cell.get_meta("grid_row") as int
			var idx := row * grid_cols + col
			if was_long:
				_toggle_flag(col, row)
			else:
				if grid_state[idx] == CellType.FLAGGED or grid_state[idx] == CellType.QUESTION:
					return
				_reveal_cell(col, row)
		return


func _process(delta: float) -> void:
	if _touch_index != -1:
		_touch_hold_time += delta
		# 长按视觉反馈 — 触摸超一半阈值时变橙色提示
		var _th = _rogue_long_press_threshold()
		if _touch_hold_time >= _th * 0.5:
			if is_instance_valid(_touch_cell) and _touch_cell is ColorRect:
				_touch_cell.color = Color("#cc8844")


func _find_cell_at(screen_pos: Vector2) -> Control:
	if not is_instance_valid(board_wrapper) or not is_instance_valid(board):
		return null
	# 从屏幕坐标找到对应的单元格
	for cell in grid_cells:
		if not is_instance_valid(cell):
			continue
		# 将单元格位置转换到屏幕坐标系
		var cell_rect := Rect2(cell.get_global_rect().position, cell.size)
		if cell_rect.has_point(screen_pos):
			return cell
	return null


func _on_cell_gui_input(event: InputEvent, cell: Control) -> void:
	# 桌面鼠标输入
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not game_active and not first_click:
		return

	var col := cell.get_meta("grid_col") as int
	var row := cell.get_meta("grid_row") as int
	var idx := row * grid_cols + col

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if grid_state[idx] == CellType.FLAGGED or grid_state[idx] == CellType.QUESTION:
				return
			_reveal_cell(col, row)
		MOUSE_BUTTON_RIGHT:
			_toggle_flag(col, row)


func _on_cell_hover(cell: Control) -> void:
	var col := cell.get_meta("grid_col") as int
	var row := cell.get_meta("grid_row") as int
	var idx := row * grid_cols + col
	if grid_state[idx] == CellType.HIDDEN or grid_state[idx] == CellType.QUESTION:
		cell.color = palette.hidden_hover


func _on_cell_hover_end(cell: Control) -> void:
	var col := cell.get_meta("grid_col") as int
	var row := cell.get_meta("grid_row") as int
	var idx := row * grid_cols + col
	if grid_state[idx] == CellType.HIDDEN or grid_state[idx] == CellType.QUESTION:
		cell.color = palette.hidden


# ═══════════════════════════════════════════════════
#  计时器
# ═══════════════════════════════════════════════════

func _on_timer_tick() -> void:
	elapsed += 1
	timer_label.text = "%03d" % elapsed
	time_changed.emit(elapsed)


# ═══════════════════════════════════════════════════
#  控制台打印（调试用）
# ═══════════════════════════════════════════════════

func print_board() -> void:
	var lines: PackedStringArray = []
	for row in range(grid_rows):
		var line := ""
		for col in range(grid_cols):
			var idx := row * grid_cols + col
			match grid_state[idx]:
				CellType.HIDDEN:
					line += "."
				CellType.FLAGGED:
					line += "F"
				CellType.QUESTION:
					line += "?"
				CellType.REVEALED:
					if grid_mine[idx]:
						line += "*"
					else:
						var n := grid_adjacent[idx]
						line += str(n) if n > 0 else " "
				_:
					line += "?"
		lines.append(line)
	for l in lines:
		print(l)

func debug_show_all_mines() -> void:
	for idx in range(grid_cols * grid_rows):
		if grid_mine[idx]:
			var col := idx % grid_cols
			var row := idx / grid_cols
			print("(%d,%d) has mine" % [col, row])

func show_mine_count() -> void:
	var count := 0
	for idx in range(grid_cols * grid_rows):
		if grid_mine[idx]:
			count += 1
	print("当前地图有 %d 颗雷" % count)
