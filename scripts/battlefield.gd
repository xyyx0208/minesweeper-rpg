extends Control
## 战场管理器 — 上下分屏自动战斗
##
## 下面扫雷翻格产生士兵，上面战场自动打怪
## 负责：军队管理、怪物波次、自动战斗循环、战斗UI

signal soldiers_changed(count: int)
signal monsters_changed(count: int)
signal monster_defeated(monster_name: String, xp: int, gold: int)
signal player_damaged(amount: int)
signal boss_spawned()
signal boss_defeated()
signal battlefield_cleared()

# ─── 内部类：怪物实例 ─────────────────────────────
class MonsterInstance:
	var id: int
	var name: String
	var icon: String
	var hp: int
	var max_hp: int
	var atk: int
	var def: int
	var xp_reward: int
	var gold_reward: int

	func _init(data, scale: float = 1.0):
		id = data.id
		name = data.name
		icon = data.icon
		hp = ceili(data.hp * scale)
		max_hp = hp
		atk = data.attack
		def = data.defense
		xp_reward = ceili(data.xp_reward * scale)
		gold_reward = ceili(data.gold_reward * scale)

# ─── 引用 ─────────────────────────────────────────
var rpg_ref = null   # rpg_manager 引用
var art_gen = null   # 美术生成器引用

# ─── 军队状态 ─────────────────────────────────────
var soldier_count: int = 0
var max_soldiers: int = 99
var army_hp_pool: int = 0
var max_army_hp: int = 500
var total_killed: int = 0

# ─── 怪物状态 ─────────────────────────────────────
var active_monsters: Array[MonsterInstance] = []
var spawn_queue: Array[MonsterInstance] = []
var is_boss_fight: bool = false
var current_wave: int = 0

# ─── 战斗控制 ─────────────────────────────────────
var combat_timer: Timer
var is_paused: bool = false
var combat_logs: Array[String] = []
const MAX_LOGS := 3

# ─── 节点引用 ─────────────────────────────────────
var soldier_label: Label
var army_hp_fill: ColorRect
var army_atk_label: Label
var kill_count_label: Label
var vs_label: Label
var wave_label: Label
var monster_name_label: Label
var monster_sprite: TextureRect
var monster_hp_fill: ColorRect
var monster_count_label: Label
var log_label: Label


# ═══════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_setup_combat_timer()


func setup(rpg: Node, art: Node) -> void:
	rpg_ref = rpg
	art_gen = art
	_init_state()


func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.color = Color("#0a0a1a")
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 主布局：左士兵 | 中VS | 右怪物
	var main_row := HBoxContainer.new()
	main_row.anchor_left = 0.0
	main_row.anchor_top = 0.0
	main_row.anchor_right = 1.0
	main_row.anchor_bottom = 1.0
	main_row.offset_bottom = -18  # 底部留日志行
	main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_row)

	var margin := 6

	# ─── 左边：士兵阵营 ──────────────────────────
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(left_vbox)

	soldier_label = Label.new()
	soldier_label.text = "⚔️ x0"
	soldier_label.add_theme_font_size_override("font_size", 14)
	soldier_label.add_theme_color_override("font_color", Color("#44cc44"))
	soldier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(soldier_label)

	# 军队HP条
	var hp_bg := ColorRect.new()
	hp_bg.color = Color("#1a1a1a")
	hp_bg.custom_minimum_size = Vector2(60, 8)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.clip_contents = true
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(hp_bg)

	army_hp_fill = ColorRect.new()
	army_hp_fill.color = Color("#22cc44")
	army_hp_fill.anchor_left = 0.0
	army_hp_fill.anchor_top = 0.0
	army_hp_fill.anchor_right = 1.0
	army_hp_fill.anchor_bottom = 1.0
	army_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bg.add_child(army_hp_fill)

	army_atk_label = Label.new()
	army_atk_label.text = "ATK:1 DEF:0"
	army_atk_label.add_theme_font_size_override("font_size", 9)
	army_atk_label.add_theme_color_override("font_color", Color("#8888aa"))
	army_atk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(army_atk_label)

	kill_count_label = Label.new()
	kill_count_label.text = "击杀:0"
	kill_count_label.add_theme_font_size_override("font_size", 9)
	kill_count_label.add_theme_color_override("font_color", Color("#8888aa"))
	kill_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(kill_count_label)

	# ─── 中间：VS区 ──────────────────────────────
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(center_vbox)

	vs_label = Label.new()
	vs_label.text = "⚡"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_size_override("font_size", 22)
	vs_label.add_theme_color_override("font_color", Color("#ffaa44"))
	vs_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(vs_label)

	wave_label = Label.new()
	wave_label.text = "待命中"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", 10)
	wave_label.add_theme_color_override("font_color", Color("#666688"))
	wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(wave_label)

	# ─── 右边：怪物阵营 ──────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_row.add_child(right_vbox)

	monster_name_label = Label.new()
	monster_name_label.text = ""
	monster_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	monster_name_label.add_theme_font_size_override("font_size", 13)
	monster_name_label.add_theme_color_override("font_color", Color("#cc4444"))
	monster_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(monster_name_label)

	# 怪物精灵区
	var sprite_center := CenterContainer.new()
	sprite_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(sprite_center)

	monster_sprite = TextureRect.new()
	monster_sprite.custom_minimum_size = Vector2(48, 48)
	monster_sprite.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	monster_sprite.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	monster_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_center.add_child(monster_sprite)

	# 怪物HP条
	var m_hp_bg := ColorRect.new()
	m_hp_bg.color = Color("#1a1a1a")
	m_hp_bg.custom_minimum_size = Vector2(60, 8)
	m_hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_hp_bg.clip_contents = true
	m_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(m_hp_bg)

	monster_hp_fill = ColorRect.new()
	monster_hp_fill.color = Color("#cc3333")
	monster_hp_fill.anchor_left = 0.0
	monster_hp_fill.anchor_top = 0.0
	monster_hp_fill.anchor_right = 1.0
	monster_hp_fill.anchor_bottom = 1.0
	monster_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_hp_bg.add_child(monster_hp_fill)

	monster_count_label = Label.new()
	monster_count_label.text = ""
	monster_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	monster_count_label.add_theme_font_size_override("font_size", 9)
	monster_count_label.add_theme_color_override("font_color", Color("#8888aa"))
	monster_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_vbox.add_child(monster_count_label)

	# ─── 底部战斗日志 ────────────────────────────
	log_label = Label.new()
	log_label.anchor_left = 0.0
	log_label.anchor_top = 0.0
	log_label.anchor_right = 1.0
	log_label.anchor_bottom = 1.0
	log_label.offset_top = -18
	log_label.offset_bottom = 0
	log_label.add_theme_font_size_override("font_size", 9)
	log_label.add_theme_color_override("font_color", Color("#666688"))
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_label)


func _setup_combat_timer() -> void:
	combat_timer = Timer.new()
	combat_timer.name = "CombatTimer"
	combat_timer.one_shot = false
	combat_timer.wait_time = 1.5
	combat_timer.timeout.connect(_on_combat_tick)
	add_child(combat_timer)
	combat_timer.stop()


func _init_state() -> void:
	soldier_count = 0
	army_hp_pool = 0
	total_killed = 0
	active_monsters.clear()
	spawn_queue.clear()
	is_boss_fight = false
	current_wave = 0
	combat_logs.clear()
	combat_timer.stop()
	_update_ui()


# ═══════════════════════════════════════════════════
#  军队管理
# ═══════════════════════════════════════════════════

func add_soldiers(count: int) -> void:
	if not rpg_ref:
		return
	count = mini(count, max_soldiers - soldier_count)
	if count <= 0:
		return

	var unit_hp := rpg_ref.get_soldier_hp_per_unit()
	soldier_count += count
	army_hp_pool += unit_hp * count
	max_army_hp = soldier_count * unit_hp
	soldiers_changed.emit(soldier_count)
	_update_ui()

	# 有怪物在打→启动/继续战斗
	if not active_monsters.is_empty() and combat_timer.is_stopped():
		combat_timer.start()


func remove_soldiers(count: int) -> void:
	if count <= 0:
		return
	var actual: int = mini(count, soldier_count)
	var unit_hp := rpg_ref.get_soldier_hp_per_unit() if rpg_ref else 10
	soldier_count -= actual
	army_hp_pool = max(0, army_hp_pool - unit_hp * actual)
	soldiers_changed.emit(soldier_count)
	_update_ui()

	if soldier_count <= 0:
		_on_army_depleted()


# ═══════════════════════════════════════════════════
#  怪物生成
# ═══════════════════════════════════════════════════

func spawn_wave_from_number(number: int, combo: int) -> void:
	if not rpg_ref or not art_gen:
		return

	var monster_data = rpg_ref.get_monster(number)
	if not monster_data:
		return

	current_wave += 1
	var scale: float = 1.0 + combo * 0.1

	# 生成 number 只怪物
	for i in range(mini(number, 5)):  # 最多5只限制
		var inst := MonsterInstance.new(monster_data, scale)
		spawn_queue.append(inst)

	monsters_changed.emit(spawn_queue.size() + active_monsters.size())

	# 如果当前没怪→立即promote
	if active_monsters.is_empty():
		_promote_from_queue()
	else:
		_add_log("波次 %d 待命: %s x%d" % [current_wave, monster_data.name, mini(number, 5)])

	_update_ui()


func spawn_boss(combo: int) -> void:
	if not rpg_ref:
		return

	is_boss_fight = true
	active_monsters.clear()
	spawn_queue.clear()

	var boss_data = rpg_ref.boss
	var scale: float = 1.0 + combo * 0.15
	var boss_inst := MonsterInstance.new(boss_data, scale)
	# Boss 用特殊名字
	boss_inst.name = "龙王"
	boss_inst.icon = "👑"
	active_monsters.append(boss_inst)

	boss_spawned.emit()
	_add_log("👑 龙王登场！")

	if combat_timer.is_stopped():
		combat_timer.start()
	_update_ui()


# ═══════════════════════════════════════════════════
#  标旗反馈
# ═══════════════════════════════════════════════════

func on_correct_flag() -> void:
	# 正确标雷：击杀当前怪物（如果有）或加2精英兵
	if not active_monsters.is_empty():
		var target = active_monsters[0]
		active_monsters.pop_front()
		total_killed += 1
		_add_log("⚑ 旗帜击杀 %s！" % target.name)
		monster_defeated.emit(target.name, target.xp_reward, target.gold_reward)

		if active_monsters.is_empty():
			_promote_from_queue()
	else:
		# 没怪则加2精英兵
		add_soldiers(2)
		_add_log("⚑ 精英援军 +2")
	_update_ui()


func on_wrong_flag() -> void:
	remove_soldiers(2)
	_add_log("⚑ 误判！损失 2 士兵")


# ═══════════════════════════════════════════════════
#  战斗循环
# ═══════════════════════════════════════════════════

func _on_combat_tick() -> void:
	if is_paused:
		return

	# 检查怪物队列
	if active_monsters.is_empty():
		_promote_from_queue()
		if active_monsters.is_empty():
			combat_timer.stop()
			wave_label.text = "✅ 清空"
			_update_ui()
			battlefield_cleared.emit()
			return

	# 检查军队
	if soldier_count <= 0:
		_on_army_depleted()
		return

	_resolve_combat_round()
	_update_ui()


func _resolve_combat_round() -> void:
	if not rpg_ref or active_monsters.is_empty():
		return

	var target = active_monsters[0]
	var unit_atk: int = rpg_ref.get_army_atk()
	var army_def: int = rpg_ref.get_army_def()

	# ─── 士兵攻击阶段 ─────────────────────────────
	var total_atk: int = soldier_count * unit_atk
	var dmg: int = max(1, total_atk - target.def)
	target.hp -= dmg

	var log_msg := "⚔️ 造成 %d 伤害" % dmg

	# ─── 怪物反击阶段 ─────────────────────────────
	var monster_dmg: int = max(1, target.atk - army_def)
	var soldiers_lost: int = ceili(float(monster_dmg) / max(unit_atk, 1))
	# 实际损失不超过士兵数
	soldiers_lost = mini(soldiers_lost, soldier_count)

	var unit_hp := rpg_ref.get_soldier_hp_per_unit()
	soldier_count -= soldiers_lost
	army_hp_pool = max(0, army_hp_pool - unit_hp * soldiers_lost)
	log_msg += " | 损失 %d 兵" % soldiers_lost

	soldiers_changed.emit(soldier_count)

	# ─── 击杀判定 ─────────────────────────────────
	if target.hp <= 0:
		active_monsters.pop_front()
		total_killed += 1
		log_msg += " | ☠️ 击杀 %s" % target.name

		# 发放奖励
		rpg_ref.add_rewards(target.xp_reward, target.gold_reward)
		monster_defeated.emit(target.name, target.xp_reward, target.gold_reward)

		# Boss 判定
		if is_boss_fight:
			is_boss_fight = false
			_add_log("👑 Boss %s 被击败！" % target.name)
			boss_defeated.emit()

		# 队列推进
		if active_monsters.is_empty():
			_promote_from_queue()

	# 如果士兵打没了
	if soldier_count <= 0:
		_on_army_depleted()
		return

	_add_log(log_msg)


func _promote_from_queue() -> void:
	if spawn_queue.is_empty():
		return

	# 最多同时 3 只怪物
	var slots := 3 - active_monsters.size()
	for i in range(mini(slots, spawn_queue.size())):
		var m = spawn_queue[0]
		spawn_queue.remove_at(0)
		active_monsters.append(m)

	_add_log("🏃 新怪物入场！")

	if combat_timer.is_stopped():
		combat_timer.start()
	_update_ui()


func _on_army_depleted() -> void:
	combat_timer.stop()

	# 计算剩余怪物总攻击
	var total_monster_atk := 0
	for m in active_monsters:
		total_monster_atk += m.atk

	if total_monster_atk > 0 and rpg_ref:
		player_damaged.emit(total_monster_atk)
		_add_log("💔 军队全灭！本体受到 %d 伤害" % total_monster_atk)

	# 2秒后自动增援
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return
	if spawn_queue.is_empty() and active_monsters.is_empty():
		return
	add_soldiers(5)
	_add_log("🔄 援军抵达 +5")

	# 如果还有怪物，恢复战斗
	if not active_monsters.is_empty():
		combat_timer.start()
	_update_ui()


# ═══════════════════════════════════════════════════
#  清理
# ═══════════════════════════════════════════════════

func clear_all() -> void:
	combat_timer.stop()
	_init_state()


# ═══════════════════════════════════════════════════
#  日志
# ═══════════════════════════════════════════════════

func _add_log(msg: String) -> void:
	combat_logs.append(msg)
	if combat_logs.size() > MAX_LOGS:
		combat_logs.remove_at(0)
	var text := ""
	for l in combat_logs:
		text += l + "\n"
	log_label.text = text.strip_edges()


# ═══════════════════════════════════════════════════
#  UI 更新
# ═══════════════════════════════════════════════════

func _update_ui() -> void:
	# 士兵数
	soldier_label.text = "⚔️ x%d" % soldier_count

	# 军队HP条
	var hp_ratio: float = float(army_hp_pool) / max(max_army_hp, 1)
	army_hp_fill.anchor_right = clamp(hp_ratio, 0.0, 1.0)

	# ATK/DEF
	if rpg_ref:
		army_atk_label.text = "ATK:%d DEF:%d" % [rpg_ref.get_army_atk(), rpg_ref.get_army_def()]
	kill_count_label.text = "击杀:%d" % total_killed

	# VS区
	wave_label.text = "波次 %d" % current_wave if current_wave > 0 else "待命中"

	# 怪物区
	if not active_monsters.is_empty():
		var target = active_monsters[0]
		var title := target.name
		if is_boss_fight:
			title = "👑 " + title
		monster_name_label.text = title
		monster_name_label.add_theme_color_override("font_color",
			Color("#ffcc00") if is_boss_fight else Color("#cc4444"))

		# 怪物精灵
		if art_gen:
			if is_boss_fight:
				monster_sprite.texture = art_gen.boss_sprite(4)
			else:
				monster_sprite.texture = art_gen.monster_sprite(target.id, 4)
		monster_sprite.show()

		# HP条
		var m_hp_ratio: float = float(target.hp) / max(target.max_hp, 1)
		monster_hp_fill.anchor_right = clamp(m_hp_ratio, 0.0, 1.0)

		# 数量
		var extra := active_monsters.size() - 1
		monster_count_label.text = "x%d" % active_monsters.size() if extra > 0 else ""
	else:
		monster_name_label.text = ""
		monster_sprite.texture = null
		monster_sprite.hide()
		monster_hp_fill.anchor_right = 0.0
		monster_count_label.text = ""
