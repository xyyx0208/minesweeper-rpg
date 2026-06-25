extends Node
## 排行榜管理器
## 本地 JSON 存储，按用时升序排列

const SAVE_PATH := "user://leaderboard.dat"
const MAX_RECORDS := 50

var records: Array[Dictionary] = []


func _ready() -> void:
	load_records()


# ─── 数据操作 ──────────────────────────────────────

func add_record(difficulty: String, cols: int, rows: int, mines: int, time_sec: int, won: bool) -> void:
	if not won:
		return  # 只记录胜利局

	records.append({
		"date": Time.get_datetime_string_from_system(),
		"difficulty": difficulty,
		"cols": cols, "rows": rows,
		"mines": mines,
		"time": time_sec,
		"won": won,
	})

	# 排序：用时升序
	records.sort_custom(func(a, b): return a.time < b.time)

	# 限制数量
	if records.size() > MAX_RECORDS:
		records = records.slice(0, MAX_RECORDS)

	save_records()


func get_top(n: int = 10) -> Array[Dictionary]:
	return records.slice(0, mini(n, records.size()))


func clear_all() -> void:
	records.clear()
	save_records()


# ─── 持久化 ─────────────────────────────────────────

func save_records() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str := JSON.stringify({"records": records}, "\t")
		file.store_string(json_str)
		file.close()


func load_records() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json_str := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary and parsed.has("records"):
		var data = parsed.records
		if data is Array:
			records.assign(data)


# ─── 格式化 ─────────────────────────────────────────

static func format_time(sec: int) -> String:
	var m := sec / 60
	var s := sec % 60
	return "%d:%02d" % [m, s]
