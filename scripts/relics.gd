extends Node
## 遗物系统 — Roguelike 爬塔模式
## 每通关一层，从 3 个随机遗物中选 1 个

enum RelicId {
	NONE,
	MINER_HELMET,      # 开局显示雷位 3 秒
	MAGNET,            # 每层 3 次高亮最近雷
	SPEED_BOOTS,       # 长按阈值降至 0.15s
	HEAL_POTION,       # HP +1
	TELESCOPE,         # 开局显示中心 5×5
	LIGHTNING,         # 每层 2 次自动展开
	GOLDEN_ARMOR,      # 踩雷不掉血（一次性）
	MAP,               # 数字永久显示
	BRAVE_HEART,       # 揭开数字 20% 自动标记雷
	LUCKY_DICE,        # 随机额外 2 个遗物
}

class RelicDef:
	var id: RelicId
	var name: String
	var desc: String
	var icon: String
	var rarity: String  # common / rare / legendary / ???

	func _init(p_id: RelicId, p_name: String, p_desc: String, p_icon: String, p_rarity: String):
		id = p_id
		name = p_name
		desc = p_desc
		icon = p_icon
		rarity = p_rarity

var ALL_RELICS := {
	RelicId.MINER_HELMET:   RelicDef.new(RelicId.MINER_HELMET,   "矿工头盔", "开局显示全部雷的位置 3 秒",             "🪖", "common"),
	RelicId.MAGNET:         RelicDef.new(RelicId.MAGNET,         "磁铁",     "每层 3 次高亮最近 3 颗雷的方向",           "🧲", "common"),
	RelicId.SPEED_BOOTS:    RelicDef.new(RelicId.SPEED_BOOTS,    "疾跑鞋",   "长按旗帜阈值从 0.3s 降到 0.15s",           "🥾", "common"),
	RelicId.HEAL_POTION:    RelicDef.new(RelicId.HEAL_POTION,    "治疗药水", "HP +1（不会超过上限）",                     "💊", "common"),
	RelicId.TELESCOPE:      RelicDef.new(RelicId.TELESCOPE,      "望远镜",   "开局显示中心 5×5 区域的内容",               "🔭", "rare"),
	RelicId.LIGHTNING:      RelicDef.new(RelicId.LIGHTNING,      "闪电",     "每层 2 次自动揭开一片空白区域",             "⚡", "rare"),
	RelicId.GOLDEN_ARMOR:   RelicDef.new(RelicId.GOLDEN_ARMOR,   "金甲",     "踩雷不掉血（一次性）",                       "🛡️", "rare"),
	RelicId.MAP:            RelicDef.new(RelicId.MAP,            "地图",     "棋盘上的数字永久显示",                       "🗺️", "legendary"),
	RelicId.BRAVE_HEART:    RelicDef.new(RelicId.BRAVE_HEART,    "勇者之心", "揭开数字格 20% 概率自动标记一颗雷",         "💎", "legendary"),
	RelicId.LUCKY_DICE:     RelicDef.new(RelicId.LUCKY_DICE,     "命运骰子", "开局时随机额外获得 2 个遗物（可能负面）",   "🎲", "???"),
}

# 稀有度权重（用于随机遗物抽取）
const RARITY_WEIGHTS := {
	"common": 50,
	"rare": 30,
	"legendary": 15,
	"???": 5,
}

const RARITY_COLORS := {
	"common": Color("#a0a0c0"),
	"rare": Color("#4a8cff"),
	"legendary": Color("#ffaa00"),
	"???": Color("#ff44ff"),
}

# 按稀有度分组的遗物列表
var _by_rarity: Dictionary = {}

func _ready() -> void:
	# 按稀有度分组
	for rid in ALL_RELICS:
		var def = ALL_RELICS[rid]
		if not _by_rarity.has(def.rarity):
			_by_rarity[def.rarity] = []
		_by_rarity[def.rarity].append(rid)


# 抽出 n 个遗物作为候选
func draw_candidates(count: int = 3) -> Array[RelicId]:
	var pool: Array[RelicId] = []
	for rarity in _by_rarity:
		var weight = RARITY_WEIGHTS.get(rarity, 10)
		var items = _by_rarity[rarity]
		for _w in range(weight):
			pool.append_array(items)

	pool.shuffle()
	var picked: Array[RelicId] = []
	var seen: Dictionary = {}
	for rid in pool:
		if seen.has(rid):
			continue
		seen[rid] = true
		picked.append(rid)
		if picked.size() >= count:
			break
	return picked


func get_def(rid: RelicId) -> RelicDef:
	return ALL_RELICS.get(rid)


# 命运骰子：随机额外获得 2 个遗物
func roll_dice() -> Array[RelicId]:
	var pool: Array[RelicId] = []
	for rid in ALL_RELICS:
		if rid != RelicId.LUCKY_DICE and rid != RelicId.NONE:
			pool.append(rid)
	pool.shuffle()
	var result: Array[RelicId] = []
	result.append(pool[0])
	result.append(pool[1])
	return result
