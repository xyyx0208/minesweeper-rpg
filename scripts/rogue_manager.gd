extends Node
## 爬塔核心管理器 — Roguelike 模式
## 控制层数递进、HP、遗物、难度参数

# 从 relics.gd 预加载 RelicId 枚举
const RelicId = preload("res://scripts/relics.gd").RelicId

signal floor_changed(floor: int)
signal hp_changed(hp: int)
signal game_over(won: bool, floor: int)
signal relic_activated(rid: int)

# 层数配置：{层数: {cols, rows, mines, safe_size, label}}
const FLOOR_CONFIG := {
	1:  { cols=6,  rows=6,  mines=4,  safe=1, label="🟢 第1层" },
	2:  { cols=7,  rows=7,  mines=6,  safe=1, label="🟢 第2层" },
	3:  { cols=8,  rows=8,  mines=10, safe=1, label="🟡 第3层" },
	4:  { cols=9,  rows=9,  mines=12, safe=1, label="🟡 第4层" },
	5:  { cols=10, rows=10, mines=15, safe=1, label="🟠 第5层" },
	6:  { cols=11, rows=11, mines=18, safe=1, label="🟠 第6层" },
	7:  { cols=12, rows=12, mines=22, safe=0, label="🔴 第7层" },
	8:  { cols=13, rows=13, mines=26, safe=0, label="🔴 第8层" },
	9:  { cols=14, rows=14, mines=30, safe=0, label="🔴 第9层" },
	10: { cols=16, rows=16, mines=40, safe=-1, label="👑 BOSS层" },
}
const MAX_FLOOR := 10

# ─── 当前状态 ─────────────────────────────────────
var current_floor := 0
var hp := 3
var max_hp := 3
var active := false

# 遗物（当前拥有的，按 id 为 key）
var relics_owned: Dictionary = {}  # RelicId → 使用次数（-1=无限）
var relics_node: Node

# 层统计
var floor_stats := {
	"revealed": 0,     # 揭开格数
	"mines_hit": 0,    # 踩雷次数
	"time": 0,         # 用时
	"score": 0,        # 勇气值
}


# 注意：由 game_manager 在 _ready 后创建
func _ready() -> void:
	relics_node = load("res://scripts/relics.gd").new()
	relics_node.name = "Relics"
	add_child(relics_node)


# ─── 游戏控制 ─────────────────────────────────────

func start_run() -> void:
	current_floor = 0
	hp = max_hp
	relics_owned.clear()
	active = true
	_reset_stats()
	next_floor()


func next_floor() -> void:
	if not active:
		return
	current_floor += 1
	if current_floor > MAX_FLOOR:
		# 全部通关！
		active = false
		game_over.emit(true, current_floor - 1)
		return

	hp = max_hp  # 每层回满 HP
	_reset_stats()
	floor_changed.emit(current_floor)

	# 遗物效果：新层重置
	_reset_relic_charges()


func _reset_stats() -> void:
	floor_stats.revealed = 0
	floor_stats.mines_hit = 0
	floor_stats.time = 0
	floor_stats.score = 0


func _reset_relic_charges() -> void:
	# 每层重置使用次数型遗物
	for rid in [RelicId.MAGNET, RelicId.LIGHTNING, RelicId.GOLDEN_ARMOR]:
		if relics_owned.has(rid):
			relics_owned[rid] = _get_max_charges(rid)


func _get_max_charges(rid: int) -> int:
	match rid:
		RelicId.MAGNET: return 3
		RelicId.LIGHTNING: return 2
		RelicId.GOLDEN_ARMOR: return 1
		_: return -1  # 无限


# ─── 当前层参数 ───────────────────────────────────

func get_floor_config() -> Dictionary:
	var cfg = FLOOR_CONFIG.get(current_floor, FLOOR_CONFIG[1])
	return cfg


# ─── HP ────────────────────────────────────────────

func take_damage() -> bool:
	# 返回 true = 还有 HP，false = 游戏结束
	if relics_owned.has(RelicId.GOLDEN_ARMOR) and relics_owned[RelicId.GOLDEN_ARMOR] > 0:
		# 金甲挡一次
		relics_owned[RelicId.GOLDEN_ARMOR] -= 1
		if relics_owned[RelicId.GOLDEN_ARMOR] <= 0:
			relics_owned.erase(RelicId.GOLDEN_ARMOR)
		return true

	hp -= 1
	hp_changed.emit(hp)
	if hp <= 0:
		active = false
		game_over.emit(false, current_floor)
		return false
	return true


# ─── 遗物操作 ─────────────────────────────────────

func add_relic(rid: int) -> void:
	if relics_owned.has(rid):
		return  # 不重复拥有
	relics_owned[rid] = _get_max_charges(rid)
	relic_activated.emit(rid)

	# 命运骰子：额外随机遗物
	if rid == RelicId.LUCKY_DICE:
		var extra = relics_node.roll_dice()
		for eid in extra:
			add_relic(eid)


func get_long_press_threshold() -> float:
	if relics_owned.has(2):  # SPEED_BOOTS
		return 0.15
	return 1.0  # 1.0 = 不覆盖默认值


func has_relic(rid: int) -> bool:
	return relics_owned.has(rid)


func use_relic(rid: int) -> bool:
	# 使用一次消耗型遗物，返回是否成功
	if not relics_owned.has(rid):
		return false
	var charges = relics_owned[rid]
	if charges == -1:
		return true  # 无限使用
	if charges <= 0:
		return false
	relics_owned[rid] = charges - 1
	if relics_owned[rid] <= 0:
		relics_owned.erase(rid)
	return true


func get_relic_list() -> Array:
	var list: Array = []
	for rid in relics_owned:
		list.append(rid)
	return list


# ─── 层间遗物选择 ────────────────────────────────

func draw_relic_candidates(count: int = 3) -> Array:
	return relics_node.draw_candidates(count)


# ─── 记录 ─────────────────────────────────────────

func record_reveal(number_val: int) -> void:
	floor_stats.revealed += 1
	floor_stats.score += number_val


func record_mine_hit() -> void:
	floor_stats.mines_hit += 1


func record_time(sec: int) -> void:
	floor_stats.time = sec
