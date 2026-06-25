extends Node
## 程序化音效管理器
## 运行时生成 AudioStreamWAV，零外部文件依赖
##
## 用法: AudioManager.play("sound_name") 或 AudioManager.sound_name()

var _players: Dictionary = {}  # sound_name → AudioStreamPlayer

# 采样参数
const RATE := 22050            # 采样率（低 = 更像素风）
const AMPLITUDE := 0.45        # 振幅 (0.0-1.0)

# ─── 公开接口 ───────────────────────────────────────

func play(sound: String) -> void:
	var player = _players.get(sound)
	if not player:
		player = _make_player(sound)
		_players[sound] = player
		add_child(player)
	player.play()


# ═══════════════════════════════════════════════════
#  音效生成（∞ 符号函数 → AudioStreamWAV）
# ═══════════════════════════════════════════════════

func _make_player(sound: String) -> AudioStreamPlayer:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = RATE

	match sound:
		"reveal":    wav.data = _gen_beep(320, 0.05)         # 短促点击
		"flag":      wav.data = _gen_beep(600, 0.08)         # 旗帜插拔
		"unflag":    wav.data = _gen_beep(220, 0.08)         # 取消旗帜
		"boom":      wav.data = _gen_noise(0.6)              # 爆炸噪声
		"win":       wav.data = _gen_chime(0, 0.5)           # 上行胜利音
		"lose":      wav.data = _gen_chime(1, 0.5)           # 下行失败音
		"start":     wav.data = _gen_arpeggio(0.3)           # 开始琶音
		"question":  wav.data = _gen_beep(440, 0.06)         # 问号标记
		_:
			wav.data = _gen_beep(440, 0.1)

	var player = AudioStreamPlayer.new()
	player.stream = wav
	player.name = "SFX_" + sound
	player.volume_db = -6.0  # 降低默认音量
	return player


# ═══════════════════════════════════════════════════
#  波形生成器
# ═══════════════════════════════════════════════════

func _gen_silence(samples: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples * 2)  # 16-bit = 2 bytes
	for i in range(samples * 2):
		data[i] = 0
	return data


func _write_sample(data: PackedByteArray, idx: int, val: float) -> void:
	# 16-bit PCM: val 范围 -1.0 ~ 1.0
	var s := int(clamp(val, -1.0, 1.0) * 32767.0)
	data[idx * 2] = s & 0xFF
	data[idx * 2 + 1] = (s >> 8) & 0xFF


func _gen_beep(freq: float, duration: float) -> PackedByteArray:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / RATE
		# 方波 + 指数衰减
		var env := exp(-3.0 * t / duration) if duration > 0 else 1.0
		var sample: float = sign(sin(2.0 * PI * freq * t)) * AMPLITUDE * env
		_write_sample(data, i, sample)
	return data


func _gen_noise(duration: float) -> PackedByteArray:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / RATE
		# 白噪声 + 指数衰减
		var env := exp(-8.0 * t / duration)
		var sample: float = (randf() * 2.0 - 1.0) * AMPLITUDE * env
		_write_sample(data, i, sample)
	return data


func _gen_chime(direction: int, duration: float) -> PackedByteArray:
	# direction 0=上行, 1=下行
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var start_freq := 400.0
	var end_freq := 800.0 if direction == 0 else 200.0
	for i in range(n):
		var t := float(i) / RATE
		var progress := float(i) / n
		var freq: float = start_freq + (end_freq - start_freq) * progress
		var env := exp(-2.0 * t / duration)
		# 三角波（更柔和）
		var phase := fmod(freq * t, 1.0)
		var sample: float = (abs(phase * 4.0 - 2.0) - 1.0) * AMPLITUDE * env
		_write_sample(data, i, sample)
	return data


func _gen_arpeggio(duration: float) -> PackedByteArray:
	# 快速上行三个音
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var notes := [260.0, 330.0, 440.0, 520.0]  # C4, E4, A4, C5
	var note_len := n / notes.size()
	for i in range(n):
		var t := float(i) / RATE
		var note_idx := mini(i / note_len, notes.size() - 1)
		var freq: float = notes[note_idx]
		var env := exp(-1.5 * t / duration)
		var sample: float = sign(sin(2.0 * PI * freq * t)) * AMPLITUDE * env
		_write_sample(data, i, sample)
	return data


# ═══════════════════════════════════════════════════
#  便捷方法
# ═══════════════════════════════════════════════════

func play_reveal() -> void:  play("reveal")
func play_flag() -> void:    play("flag")
func play_unflag() -> void:  play("unflag")
func play_boom() -> void:    play("boom")
func play_win() -> void:     play("win")
func play_lose() -> void:    play("lose")
func play_start() -> void:   play("start")
