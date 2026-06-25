extends Node
## 程序化像素风美术资源生成器
## 运行时生成贴图，零外部文件依赖
##
## 用法: ArtGenerator.new() → gen.monster_sprite(id, size) / gen.hp_bar(...)

class_name ArtGenerator

# ═══════════════════════════════════════════════════
#  怪物调色板 — 每怪 5 色
# ═══════════════════════════════════════════════════

const PALETTES := {
	1: [Color("#4ade4a"), Color("#2a9a2a"), Color("#6afe6a"), Color("#ffffff"), Color("#ee4444")],  # 史莱姆
	2: [Color("#8a6a3a"), Color("#5a4a2a"), Color("#ba9a5a"), Color("#ff4444"), Color("#4a3a1a")],  # 哥布林
	3: [Color("#d0d0d0"), Color("#909090"), Color("#ffffff"), Color("#ff2222"), Color("#606060")],  # 骷髅兵
	4: [Color("#8a8a8a"), Color("#5a5a5a"), Color("#cacaca"), Color("#ffaa22"), Color("#3a3a3a")],  # 野狼
	5: [Color("#5a8a3a"), Color("#3a5a2a"), Color("#7aaa5a"), Color("#ff4444"), Color("#2a4a1a")],  # 兽人
	6: [Color("#8a4a8a"), Color("#5a2a5a"), Color("#ba6aba"), Color("#ffaa44"), Color("#3a1a3a")],  # 巨魔
	7: [Color("#cc3333"), Color("#8a2222"), Color("#ff5555"), Color("#ffaa00"), Color("#5a1515")],  # 恶魔
	8: [Color("#3a6acc"), Color("#2a4a8a"), Color("#5a8afe"), Color("#ffcc00"), Color("#1a3a6a")],  # 飞龙
}
const BOSS_PALETTE := [Color("#ffcc00"), Color("#cc8800"), Color("#ffee55"), Color("#ff4444"), Color("#996600")]

# ═══════════════════════════════════════════════════
#  像素画定义 — 12x12 网格
#  0=透明, 1=body, 2=dark, 3=light, 4=eye, 5=accent
# ═══════════════════════════════════════════════════

const _ART := {
	1: [  # 史莱姆 — 绿色圆球
		"....0000....",
		"...011110...",
		"..01111110..",
		".0111111110.",
		".0111111110.",
		"011111111110",
		"011141114110",
		"011111111110",
		"011111111110",
		".0111111110.",
		"..01111110..",
		"...011110...",
	],
	2: [  # 哥布林 — 棕色小个子
		"....0..0....",
		"...01..10...",
		"..01111110..",
		"..01111110..",
		"...011110...",
		"..01111110..",
		".0111111110.",
		".0114141110.",
		"..01111110..",
		"...011110...",
		"..0.0110.0..",
		".00.0110.00.",
	],
	3: [  # 骷髅兵 — 白色骷髅
		"....0110....",
		"...022220...",
		"..02222220..",
		".0222222220.",
		".0222022220.",
		"022222222220",
		"022222222220",
		"022224222220",
		".0222222220.",
		"..02222220..",
		"...022220...",
		"....0220....",
	],
	4: [  # 野狼 — 灰色狼头
		"....000.....",
		"...01110....",
		"..0111110...",
		".011111110..",
		"01111111110.",
		"01111111110.",
		"01113113110.",
		".0111111110.",
		"..01111110..",
		"...011110...",
		"....0110....",
		".....00.....",
	],
	5: [  # 兽人 — 绿色壮汉
		"....0..0....",
		"...01..10...",
		"..01111110..",
		"..01111110..",
		"...011110...",
		"..01111110..",
		".0111111110.",
		".0111111110.",
		".0115451110.",
		"..01111110..",
		"..0.0110.0..",
		".00.0110.00.",
	],
	6: [  # 巨魔 — 紫色大块头
		"...0....0...",
		"..011..110..",
		"..01111110..",
		"..01111110..",
		"..01111110..",
		".0111111110.",
		"011111111110",
		"011111111110",
		"011111111110",
		".0111111110.",
		"..01111110..",
		"...011110...",
	],
	7: [  # 恶魔 — 红色双角
		"0..0....0..0",
		".0220..0220.",
		"..01111110..",
		"..01111110..",
		"...011110...",
		".0111111110.",
		"011111111110",
		"011151151110",
		"011111111110",
		".0111111110.",
		"..01111110..",
		"...011110...",
	],
	8: [  # 飞龙 — 蓝色飞龙
		"..0..0..0...",
		"0011001100..",
		"..01111110..",
		"..01111110..",
		".0111111110.",
		"011111111110",
		"011111111110",
		"011161161110",
		".0111111110.",
		"..01111110..",
		"..0..0..0...",
		".00..0..00..",
	],
}

# Boss 16x14 — 黄金龙王
const _BOSS_ART := [
	"....0..00..0..",
	"..0011001100..",
	"..0111111110..",
	"..0111111110..",
	".011111111110.",
	"01111111111110",
	"01111111111110",
	"01116111611110",
	"01111111111110",
	".011111111110.",
	"..0111111110..",
	"...01111110...",
	"....011110....",
	".....0110.....",
]

# ═══════════════════════════════════════════════════
#  怪物精灵
# ═══════════════════════════════════════════════════

func monster_sprite(monster_id: int, pixel_size: int = 4) -> ImageTexture:
	var pal = PALETTES.get(monster_id, PALETTES[1])
	return _render(_ART.get(monster_id, _ART[1]), pal, pixel_size)


func boss_sprite(pixel_size: int = 4) -> ImageTexture:
	return _render_boss(BOSS_PALETTE, pixel_size)


func _render(grid: Array, pal: Array, pixel_size: int) -> ImageTexture:
	var w := 12 * pixel_size
	var h := len(grid) * pixel_size
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for row in range(len(grid)):
		var line = grid[row]
		for col in range(len(line)):
			var c := int(line[col]) if col < line.length() else 0
			var color := Color.TRANSPARENT
			if c >= 1 and c <= 5 and c - 1 < pal.size():
				color = pal[c - 1]
			# 填充像素块 (pixel_size x pixel_size)
			for dy in range(pixel_size):
				for dx in range(pixel_size):
					img.set_pixel(col * pixel_size + dx, row * pixel_size + dy, color)
	return ImageTexture.create_from_image(img)


func _render_boss(pal: Array, pixel_size: int) -> ImageTexture:
	var w := 16 * pixel_size
	var h := len(_BOSS_ART) * pixel_size
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for row in range(len(_BOSS_ART)):
		var line = _BOSS_ART[row]
		for col in range(len(line)):
			var c := int(line[col]) if col < line.length() else 0
			var color := Color.TRANSPARENT
			if c >= 1 and c <= 5 and c - 1 < pal.size():
				color = pal[c - 1]
			for dy in range(pixel_size):
				for dx in range(pixel_size):
					img.set_pixel(col * pixel_size + dx, row * pixel_size + dy, color)
	return ImageTexture.create_from_image(img)


# ═══════════════════════════════════════════════════
#  进度条
# ═══════════════════════════════════════════════════

func hp_bar(current: int, max_val: int, width: int = 120, height: int = 14) -> ImageTexture:
	# 红→黄→绿渐变条，带边框
	return _make_bar(current, max_val, width, height,
		Color("#22cc44"), Color("#cccc22"), Color("#cc3333"),
		Color("#116622"), Color("#666611"), Color("#661111"))


func xp_bar(current: int, max_val: int, width: int = 100, height: int = 10) -> ImageTexture:
	# 蓝→紫渐变条
	return _make_bar(current, max_val, width, height,
		Color("#4488ff"), Color("#8844ff"), Color("#4488ff"),
		Color("#224488"), Color("#442288"), Color("#224488"))


func _make_bar(cur: int, maxv: int, w: int, h: int,
			   fill_bright: Color, fill_mid: Color, fill_dark: Color,
			   bg_bright: Color, bg_mid: Color, bg_dark: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var ratio: float = clamp(float(cur) / maxv if maxv > 0 else 0.0, 0.0, 1.0)
	var fill_end: int = int(w * ratio)

	for y in range(h):
		for x in range(w):
			var color: Color
			if y == 0 or y == h - 1 or x == 0 or x == w - 1:
				# 边框
				color = Color("#cccccc") if (y == 0 or y == h - 1) else Color("#aaaaaa")
			elif x < fill_end:
				# 填充区：从左到右渐变 绿→黄→红
				var t: float = float(x) / max(w - 1, 1)
				if t < 0.5:
					color = fill_bright.lerp(fill_mid, t * 2.0)
				else:
					color = fill_mid.lerp(fill_dark, (t - 0.5) * 2.0)
			else:
				# 空白区
				var t: float = float(x - fill_end) / max(w - fill_end - 1, 1)
				if t < 0.5:
					color = bg_bright.lerp(bg_mid, t * 2.0)
				else:
					color = bg_mid.lerp(bg_dark, (t - 0.5) * 2.0)

			# 内发光效果
			if x >= fill_end - 2 and x <= fill_end and y >= 2 and y < h - 2:
				color = Color("#ffffff").lerp(color, 0.3)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


# ═══════════════════════════════════════════════════
#  面板背景（带边框）
# ═══════════════════════════════════════════════════

func panel_texture(w: int, h: int, border_color: Color, bg_color: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
				img.set_pixel(x, y, border_color)
			else:
				img.set_pixel(x, y, bg_color)
	return ImageTexture.create_from_image(img)


# ═══════════════════════════════════════════════════
#  升级特效 — 星星徽章
# ═══════════════════════════════════════════════════

func level_up_badge(pixel_size: int = 3) -> ImageTexture:
	# 12x12 星星 + "↑" 箭头
	var art := [
		"....00..00....",
		"....00..00....",
		"....011110....",
		"....011110....",
		"..0011111100..",
		".001111111100.",
		"00111111111100",
		".001111111100.",
		"..0055555500..",
		"....055550....",
		"....005500....",
		".....00.00....",
		"....00...00...",
		"...00.....00..",
	]
	var pal := [Color("#ffcc00"), Color("#cc8800"), Color("#ffee55"), Color("#ffffff"), Color("#44ff44")]
	var w := 14 * pixel_size
	var h := len(art) * pixel_size
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for row in range(len(art)):
		var line = art[row]
		for col in range(len(line)):
			var c := int(line[col]) if col < line.length() else 0
			var color := Color.TRANSPARENT
			if c >= 1 and c <= 5 and c - 1 < pal.size():
				color = pal[c - 1]
			for dy in range(pixel_size):
				for dx in range(pixel_size):
					img.set_pixel(col * pixel_size + dx, row * pixel_size + dy, color)
	return ImageTexture.create_from_image(img)


# ═══════════════════════════════════════════════════
#  主菜单装饰 — 像素地牢背景
# ═══════════════════════════════════════════════════

func dungeon_bg(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var wall := Color("#1a1a2e")
	var stone1 := Color("#222244")
	var stone2 := Color("#252548")
	for y in range(h):
		for x in range(w):
			# 砖墙图案
			var bx := x / 16
			var by := y / 12
			var offset := (by % 2) * 8
			var is_joint := (x % 16 < 1) or (y % 12 < 1)
			if is_joint:
				img.set_pixel(x, y, Color("#111122"))
			elif (bx + offset) % 3 == 0 and (by % 3) == 0:
				img.set_pixel(x, y, stone2)
			else:
				img.set_pixel(x, y, stone1)
			# 底部发光线
			if y % 12 == 11:
				img.set_pixel(x, y, Color("#161633"))
	return ImageTexture.create_from_image(img)
