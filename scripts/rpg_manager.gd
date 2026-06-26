extends Node
## RPG 模式管理器 — 扫雷×解谜RPG 核心逻辑
##
## 翻数字格→遇敌战斗，踩雷→Boss战，连消→Combo倍率
## 自动结算，保留扫雷快节奏

signal player_damaged(amount: int)
signal monster_defeated(monster_name: String, xp: int, gold: int)
signal boss_defeated()
signal player_died()
signal leveled_up(new_level: int)
signal stats_changed()

# ─── 怪物数据 ──────────────────────────────────────
# 数字 1-8 对应 8 种怪物，数字越大越强

class MonsterData:
	var id: int          # 对应数字 1-8
	var name: String
	var icon: String
	var hp: int
	var attack: int
	var defense: int
	var xp_reward: int
	var gold_reward: int

	func _init(p_id: int, p_name: String, p_icon: String,
			   p_hp: int, p_atk: int, p_def: int,
			   p_xp: int, p_gold: int):
		id = p_id
		name = p_name
		icon = p_icon
		hp = p_hp
		attack = p_atk
		defense = p_def
		xp_reward = p_xp
		gold_reward = p_gold

var MONSTERS := {
	1: MonsterData.new(1, "史莱姆", "🟢",  5,  2, 0,  3,  1),
	2: MonsterData.new(2, "哥布林", "🟤",  8,  3, 1,  6,  2),
	3: MonsterData.new(3, "骷髅兵", "⚪", 12,  4, 2, 10,  4),
	4: MonsterData.new(4, "野狼",   "🐺", 16,  6, 3, 15,  6),
	5: MonsterData.new(5, "兽人",   "🟠", 22,  8, 4, 22,  9),
	6: MonsterData.new(6, "巨魔",   "🟣", 30, 10, 5, 30, 12),
	7: MonsterData.new(7, "恶魔",   "🔴", 40, 13, 7, 42, 16),
	8: MonsterData.new(8, "飞龙",   "🐉", 55, 16, 9, 55, 22),
}

class BossData:
	var name: String = "龙王"
	var icon: String = "👑"
	var hp: int = 80
	var attack: int = 20
	var defense: int = 12
	var xp_reward: int = 200
	var gold_reward: int = 100

var boss := BossData.new()

# ─── Combo 系统 ────────────────────────────────────
const COMBO_RATE := 0.15       # 每 chain 一格 +15%
var combo_chain := 0


# ─── 玩家属性 ─────────────────────────────────────
class PlayerStats:
	var hp: int = 30
	var max_hp: int = 30
	var atk: int = 5
	var defense: int = 2
	var level: int = 1
	var xp: int = 0
	var gold: int = 0

var stats := PlayerStats.new()


# ─── 战斗系统 ─────────────────────────────────────

# 遇敌：根据数字 1-8 触发战斗
func encounter_monster(number: int, combo: int) -> Dictionary:
	combo_chain = combo
	var monster = MONSTERS.get(number)
	if not monster:
		return {"result": "none"}

	var result = _resolve_battle(monster.hp, monster.attack, monster.defense)

	if result.won:
		var mult: float = 1.0 + combo_chain * COMBO_RATE
		var earned_xp := int(floor(monster.xp_reward * mult))
		var earned_gold := int(floor(monster.gold_reward * mult))
		stats.xp += earned_xp
		stats.gold += earned_gold
		stats.hp = result.player_hp_remaining

		var did_level_up := false
		while _check_level_up():
			did_level_up = true

		monster_defeated.emit(monster.name, earned_xp, earned_gold)
		if did_level_up:
			leveled_up.emit(stats.level)
		stats_changed.emit()
		return {
			"result": "win",
			"monster": monster,
			"xp": earned_xp,
			"gold": earned_gold,
			"damage_taken": result.player_damage_taken,
			"leveled_up": did_level_up,
		}
	else:
		stats.hp = max(1, result.player_hp_remaining)
		combo_chain = 0
		player_damaged.emit(result.player_damage_taken)
		stats_changed.emit()
		return {
			"result": "flee",
			"monster": monster,
			"damage_taken": result.player_damage_taken,
		}


# Boss 战：踩雷触发
func encounter_boss(combo: int) -> Dictionary:
	combo_chain = combo
	var result = _resolve_battle(boss.hp, boss.attack, boss.defense)

	if result.won:
		var mult: float = 1.0 + combo_chain * COMBO_RATE
		var earned_xp := int(floor(boss.xp_reward * mult))
		var earned_gold := int(floor(boss.gold_reward * mult))
		stats.xp += earned_xp
		stats.gold += earned_gold
		stats.hp = result.player_hp_remaining

		var did_level_up := false
		while _check_level_up():
			did_level_up = true

		boss_defeated.emit()
		if did_level_up:
			leveled_up.emit(stats.level)
		stats_changed.emit()
		return {
			"result": "win",
			"monster_name": boss.name,
			"xp": earned_xp,
			"gold": earned_gold,
			"damage_taken": result.player_damage_taken,
			"leveled_up": did_level_up,
		}
	else:
		# Boss 战失败 → 游戏结束
		stats.hp = 0
		player_died.emit()
		stats_changed.emit()
		return {
			"result": "dead",
			"damage_taken": result.player_damage_taken,
		}


# 内部战斗结算：回合制模拟，自动返回结果
func _resolve_battle(monster_hp: int, monster_atk: int, monster_def: int) -> Dictionary:
	var player_dmg: int = max(1, stats.atk - monster_def)
	var monster_dmg: int = max(1, monster_atk - stats.defense)

	var m_hp: int = monster_hp
	var p_hp: int = stats.hp
	var total_damage := 0

	while m_hp > 0 and p_hp > 0:
		m_hp -= player_dmg   # 玩家先手
		if m_hp <= 0:
			break
		p_hp -= monster_dmg
		total_damage += monster_dmg

	var won := p_hp > 0
	return {
		"won": won,
		"player_hp_remaining": p_hp if won else max(1, p_hp),
		"player_damage_taken": total_damage,
	}


# ─── 等级系统 ─────────────────────────────────────

func _check_level_up() -> bool:
	var threshold := xp_for_level(stats.level)
	if stats.xp >= threshold:
		stats.level += 1
		stats.xp -= threshold
		stats.max_hp += 10
		stats.hp = stats.max_hp  # 升级回满血
		stats.atk += 2
		stats.defense += 1
		return true
	return false


func xp_for_level(level: int) -> int:
	return level * 18 + 5


# ─── 新游戏重置 ────────────────────────────────────

func reset() -> void:
	stats = PlayerStats.new()
	combo_chain = 0


# ─── 获取怪物名 ───────────────────────────────────

func get_monster_name(number: int) -> String:
	var m = MONSTERS.get(number)
	return m.name if m else "???"

func get_monster(number: int) -> MonsterData:
	return MONSTERS.get(number)
