extends Node2D

const Progress = preload("res://scripts/progress.gd")
const WeatherAudio = preload("res://scripts/weather_audio.gd")
const VIEW := Rect2(28, 133, 926, 466)
const INK := Color("e1e8da")
const MUTED := Color("90aaa4")
const MINT := Color("b5dac2")
const TITLES := ["第一场雨", "让雨快一些", "照顾整片树林"]
const SUBTITLES := ["长按下雨，救下这棵树。", "三棵树，感受更快的降雨。", "十棵树，试试扩大后的降雨范围。"]
var progress = Progress.new()
var weather: Node
var font: Font
var trees: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var splashes: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var labels: Dictionary = {}
var hold := false
var active_touch := -1
var pointer := Vector2(490, 215)
var timer := 0.0
var time := 0.0
var action_button: Button
var sound_button: Button
var reset_dialog: ConfirmationDialog
var current_phase := ""
var random := RandomNumberGenerator.new()
var total_effective := 0
var focus_ring := 0.0

func _ready() -> void:
	font = preload("res://fonts/RainingSans.ttf")
	progress.load_game()
	random.seed = 1197
	weather = WeatherAudio.new()
	add_child(weather)
	_create_ui()
	_build_trees()
	_refresh_ui()
	get_tree().auto_accept_quit = false

func _make_label(key: String, text: String, position: Vector2, size: int, color: Color = INK, width: float = 800) -> Label:
	var label := Label.new()
	label.position = position
	label.size = Vector2(width, 40)
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	labels[key] = label
	return label

func _button(text: String, position: Vector2, size: Vector2, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = position
	b.size = size
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("b5dac2") if primary else Color("203a3b")
		if state == "hover": box.bg_color = box.bg_color.lightened(0.12)
		if state == "pressed": box.bg_color = box.bg_color.darkened(0.12)
		if state == "disabled": box.bg_color = Color("263b3b")
		box.set_corner_radius_all(12)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", Color("183430") if primary else INK)
	b.add_theme_color_override("font_hover_color", Color("183430") if primary else INK)
	b.add_theme_color_override("font_pressed_color", Color("183430") if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color("6b8980"))
	add_child(b)
	return b

func _create_ui() -> void:
	_make_label("brand", "听 雨  /  R A I N I N G", Vector2(42, 27), 17, MINT)
	_make_label("title", "", Vector2(42, 65), 32)
	_make_label("subtitle", "", Vector2(300, 75), 17, MUTED, 640)
	_make_label("chapter", "灭火 · 三场入门", Vector2(1000, 37), 16, MUTED, 245)
	_make_label("level", "", Vector2(1000, 73), 23, INK, 240)
	_make_label("coin_label", "积累的金币", Vector2(1000, 151), 15, MUTED, 230)
	_make_label("coins", "0", Vector2(1000, 178), 40, Color("e6c887"), 240)
	_make_label("speed_caption", "降雨间隔", Vector2(1000, 264), 15, MUTED, 230)
	_make_label("speed", "", Vector2(1000, 289), 24, INK, 230)
	_make_label("range_caption", "降雨范围", Vector2(1000, 345), 15, MUTED, 230)
	_make_label("range", "", Vector2(1000, 371), 24, INK, 230)
	_make_label("result", "", Vector2(1000, 438), 18, MINT, 230)
	var detail := _make_label("detail", "", Vector2(1000, 473), 15, MUTED, 230)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size.y = 100
	action_button = _button("", Vector2(998, 596), Vector2(236, 52), true)
	action_button.pressed.connect(_on_action)
	sound_button = _button("雨声 开", Vector2(42, 646), Vector2(122, 42))
	sound_button.pressed.connect(func():
		weather.enabled = not weather.enabled
		sound_button.text = "雨声 开" if weather.enabled else "雨声 关")
	var reset := _button("重新开始", Vector2(177, 646), Vector2(124, 42))
	reset.pressed.connect(func():
		hold = false
		reset_dialog.popup_centered())
	_make_label("hint", "", Vector2(330, 650), 16, MUTED, 620)
	_make_label("footer", "长按降雨 · 松手停雨", Vector2(1000, 666), 13, MUTED, 240)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "重新开始"
	reset_dialog.dialog_text = "重置这三关的进度和升级？"
	reset_dialog.ok_button_text = "重新开始"
	reset_dialog.cancel_button_text = "继续听雨"
	reset_dialog.confirmed.connect(_restart)
	add_child(reset_dialog)

func _build_trees() -> void:
	trees.clear()
	drops.clear()
	pending.clear()
	splashes.clear()
	var positions: Array[Vector2] = []
	if progress.level == 0:
		positions = [Vector2(490, 475)]
	elif progress.level == 1:
		positions = [_iso(Vector2(-1, -1)), _iso(Vector2(-1, 1)), _iso(Vector2(1, 1))]
	else:
		for row in 2:
			for col in 5:
				positions.append(_iso(Vector2(col - 2, row - 0.5)))
	positions.sort_custom(func(a: Vector2, b: Vector2): return a.y < b.y)
	for i in positions.size():
		var scale_value := 1.16 if progress.level == 0 else (0.94 if progress.level == 1 else 0.65)
		trees.append({"base":positions[i], "scale":scale_value, "seed":float(i) * 2.71})
	pointer = Vector2(490, 205)
	hold = false
	timer = 0
	total_effective = 0

func _refresh_ui() -> void:
	labels.title.text = TITLES[progress.level]
	labels.subtitle.text = SUBTITLES[progress.level]
	labels.level.text = "第 %02d / 03 关" % (progress.level + 1)
	labels.coins.text = str(progress.coins)
	labels.speed.text = "%.2f 秒  ·  Lv.%d" % [progress.cooldown(), progress.speed_level + 1]
	labels.range.text = "%d  ·  Lv.%d" % [int(progress.radius()), progress.range_level + 1]
	var out := 0
	for value in progress.hits:
		if value >= 5: out += 1
	labels.result.text = "已救下 %d / %d 棵树" % [out, progress.hits.size()]
	if progress.phase == "playing":
		action_button.text = "让雨落在树上"
		action_button.disabled = true
		labels.detail.text = ["在树冠上方长按。\n雨落下来，火会一点点变小。", "降雨间隔已缩短。\n移动到其他树的上方继续长按。", "范围已扩大。\n试着把雨放在两棵树之间。"][progress.level]
		labels.hint.text = "按住鼠标左键，或用手指长按树冠上方"
	elif progress.phase == "cleared":
		action_button.disabled = false
		if progress.level == 0:
			action_button.text = "升级速度  ·  10 金币"
			labels.detail.text = "这棵树得救了。\n用刚得到的金币，让雨下得快一些。"
		else:
			action_button.text = "升级范围  ·  30 金币"
			labels.detail.text = "三棵树都得救了。\n扩大范围，一场雨照顾更多树。"
		labels.hint.text = "灭火完成  ·  获得 %d 金币" % progress.REWARDS[progress.level]
	elif progress.phase == "ready":
		action_button.disabled = false
		action_button.text = "进入第 %d 关  →" % (progress.level + 2)
		labels.detail.text = "速度升级完成。\n降雨间隔 1.00 → 0.65 秒。" if progress.level == 0 else "范围升级完成。\n降雨半径 55 → 125。"
		labels.hint.text = "升级已生效  ·  去下一片树林试试"
	else:
		action_button.disabled = false
		action_button.text = "再听一场雨"
		labels.detail.text = "十棵树都得救了。\n用时 %.1f 秒 / %d 批降雨。\n留在这里，听一会儿雨。" % [progress.elapsed, progress.batches]
		labels.hint.text = "三场雨结束了，树林重新安静下来。"
	current_phase = progress.phase

func _on_action() -> void:
	hold = false
	if progress.phase == "cleared":
		progress.buy_upgrade()
	elif progress.phase == "ready":
		progress.next_level()
		_build_trees()
	elif progress.phase == "finished":
		_restart()
	progress.save_game()
	_refresh_ui()

func _restart() -> void:
	progress.reset()
	progress.save_game()
	_build_trees()
	_refresh_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		hold = false
	if event is InputEventMouseMotion and active_touch < 0:
		pointer = event.position
	if event is InputEventScreenTouch and not event.pressed and event.index == active_touch:
		hold = false
		active_touch = -1
	if event is InputEventScreenDrag and event.index == active_touch:
		pointer = event.position

func _unhandled_input(event: InputEvent) -> void:
	if progress.phase != "playing": return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer = event.position
		if VIEW.has_point(pointer):
			hold = true
	if event is InputEventScreenTouch and event.pressed and active_touch < 0:
		pointer = event.position
		if VIEW.has_point(pointer):
			active_touch = event.index
			hold = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		hold = false
		active_touch = -1
		progress.save_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		progress.save_game()
		get_tree().quit()

func _spawn_batch() -> void:
	var radius: float = progress.radius()
	var targets: Array[int] = []
	for i in trees.size():
		var base: Vector2 = trees[i].base
		var crown_y: float = base.y - 96 * float(trees[i].scale)
		if absf(base.x - pointer.x) <= radius + 18 and pointer.y <= crown_y + 30 and base.y > pointer.y:
			targets.append(i)
	pending.append({"remaining":0.40, "targets":targets})
	for i in 52:
		var offset := random.randf_range(-radius, radius)
		var pos := Vector2(clampf(pointer.x + offset, 38, 944), pointer.y + random.randf_range(12, 23))
		drops.append({"p":pos, "speed":random.randf_range(650, 820), "life":0.55, "length":random.randf_range(10, 24)})
	focus_ring = 1.0

func _process(delta: float) -> void:
	time += delta
	timer = maxf(0, timer - delta)
	if progress.phase == "playing":
		progress.elapsed += delta
	if hold and VIEW.has_point(pointer) and progress.phase == "playing" and timer <= 0:
		_spawn_batch()
		timer = progress.cooldown()
	for i in range(pending.size() - 1, -1, -1):
		pending[i].remaining -= delta
		if float(pending[i].remaining) <= 0:
			total_effective += progress.apply_batch(pending[i].targets)
			pending.remove_at(i)
			if progress.phase != "playing": hold = false
			progress.save_game()
			_refresh_ui()
	for i in range(drops.size() - 1, -1, -1):
		drops[i].p.y += float(drops[i].speed) * delta
		drops[i].p.x -= delta * 24
		drops[i].life -= delta
		if float(drops[i].life) <= 0 or drops[i].p.y > 557:
			if splashes.size() < 180:
				splashes.append({"p":Vector2(drops[i].p.x, minf(drops[i].p.y, 557)), "life":0.3})
			drops.remove_at(i)
	for i in range(splashes.size() - 1, -1, -1):
		splashes[i].life -= delta
		if float(splashes[i].life) <= 0: splashes.remove_at(i)
	focus_ring = maxf(0, focus_ring - delta * 2)
	weather.set_raining(hold and progress.phase == "playing")
	queue_redraw()

func _draw() -> void:
	_draw_background()
	for i in trees.size():
		_draw_tree(trees[i], progress.hits[i])
	for d in drops:
		draw_line(d.p, d.p + Vector2(-1, float(d.length)), Color(0.70, 0.86, 0.82, 0.65), 1.4, true)
	for s in splashes:
		var life: float = s.life / 0.3
		draw_arc(s.p, (1 - life) * 10 + 1, PI, TAU, 10, Color(0.62, 0.79, 0.73, life * 0.4), 1, true)
	if progress.phase == "playing":
		var location := pointer if hold else Vector2(490, 205)
		if VIEW.has_point(location):
			_draw_cloud(location, progress.radius(), hold)
		if progress.batches == 0:
			draw_string(font, Vector2(418, 166), "长按，让云带来雨", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d4e4d0"))
	if progress.phase in ["cleared", "ready", "finished"]:
		draw_string(font, Vector2(76, 577), "树林安静下来了。", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, MINT)

func _iso(grid: Vector2) -> Vector2:
	return Vector2(490, 410) + Vector2((grid.x - grid.y) * 78, (grid.x + grid.y) * 36)

func _diamond(center: Vector2, width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -height), center + Vector2(width, 0), center + Vector2(0, height), center + Vector2(-width, 0)])

func _draw_cloud(center: Vector2, radius: float, raining: bool) -> void:
	# The visible left/right cloud edges exactly match the gameplay radius.
	var cloud_color := Color("99b5b8") if raining else Color("78999e")
	var y := center.y + sin(time * 0.9) * 2
	var height := 22.0 + radius * 0.10
	var hull := PackedVector2Array([Vector2(center.x - radius, y + 4), Vector2(center.x - radius * 0.85, y - height * 0.45), Vector2(center.x - radius * 0.55, y - height * 0.45), Vector2(center.x - radius * 0.4, y - height), Vector2(center.x - radius * 0.08, y - height * 1.08), Vector2(center.x + radius * 0.12, y - height * 0.65), Vector2(center.x + radius * 0.45, y - height * 0.75), Vector2(center.x + radius * 0.8, y - height * 0.25), Vector2(center.x + radius, y + 4), Vector2(center.x + radius * 0.78, y + 17), Vector2(center.x - radius * 0.78, y + 17)])
	var shadow := hull.duplicate()
	for i in shadow.size(): shadow[i] += Vector2(0, 5)
	draw_colored_polygon(shadow, Color(0.08, 0.17, 0.19, 0.3))
	draw_colored_polygon(hull, cloud_color)
	draw_polyline(PackedVector2Array([Vector2(center.x - radius * 0.78, y + 13), Vector2(center.x + radius * 0.78, y + 13)]), cloud_color.darkened(0.14), 5, true)
	draw_line(Vector2(center.x - radius * 0.35, y - height * 0.7), Vector2(center.x - radius * 0.1, y - height * 0.7), cloud_color.lightened(0.16), 3, true)
	if not raining:
		for i in 5:
			var x := center.x + (i - 2) * radius * 0.30
			var offset := fmod(time * 17 + i * 9, 30)
			draw_line(Vector2(x, y + 22 + offset), Vector2(x - 1, y + 26 + offset), Color(0.6, 0.78, 0.80, 0.22), 1, true)

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("101f27"))
	for row in 28:
		var mix_value := float(row) / 28
		draw_rect(Rect2(28, 133 + row * 16.65, 926, 18), Color("233b42").lerp(Color("28403c"), mix_value))
	# An orthographic 2:1-style diamond terrain, with visible raised sides.
	var center := Vector2(490, 407)
	var top := center + Vector2(0, -165)
	var right := center + Vector2(390, 0)
	var bottom := center + Vector2(0, 165)
	var left := center + Vector2(-390, 0)
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + Vector2(0, 18), left + Vector2(0, 18)]), Color("263c32"))
	draw_colored_polygon(PackedVector2Array([right, bottom, bottom + Vector2(0, 18), right + Vector2(0, 18)]), Color("1a302c"))
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), Color("405c45"))
	for gx in range(-4, 5):
		for gy in range(-4, 5):
			var point := center + Vector2((gx - gy) * 39, (gx + gy) * 16.5)
			var color := Color("48654b") if (gx + gy) % 2 == 0 else Color("426048")
			draw_colored_polygon(_diamond(point, 39, 16.5), color)
	for i in trees.size():
		var recovery := float(progress.hits[i]) / 5
		var color := Color("6e5841").lerp(Color("4e7158"), recovery)
		draw_colored_polygon(_diamond(trees[i].base + Vector2(0, 2), 44 * float(trees[i].scale), 21 * float(trees[i].scale)), color)
	for i in 100:
		var gx := sin(i * 16.37) * 4.3
		var gy := cos(i * 5.73) * 4.3
		var pos := center + Vector2((gx - gy) * 39, (gx + gy) * 16.5)
		draw_line(pos, pos + Vector2(1, -3), Color(0.65, 0.75, 0.54, 0.25), 1, true)
	# Grid edge accents make the fixed isometric viewing angle legible.
	draw_polyline(PackedVector2Array([left, top, right]), Color("6e8764"), 1.5, true)
	draw_polyline(PackedVector2Array([left, bottom, right]), Color("3b5741"), 1, true)
	draw_rect(Rect2(973, 26, 287, 668), Color("172b30"))
	draw_line(Vector2(997, 246), Vector2(1232, 246), Color("304844"), 1)
	for i in 3:
		draw_circle(Vector2(914 - (2 - i) * 18, 47), 4, MINT if i <= progress.level else Color("36504d"))
	draw_rect(Rect2(28, 133, 926, 466), Color("425f59"), false, 1)

func _draw_tree(tree: Dictionary, hits: int) -> void:
	var base: Vector2 = tree.base
	var s: float = tree.scale
	var seed_value: float = tree.seed
	var sway := sin(time * 0.65 + seed_value) * 1.2 * s
	var crown := base + Vector2(sway, -102 * s)
	var alive := float(hits) / 5
	# Ellipse shadow, branches, then layered scalloped canopy.
	draw_set_transform(base + Vector2(0, 6), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, 60 * s, Color(0.04, 0.12, 0.12, 0.27))
	draw_set_transform(Vector2.ZERO)
	draw_line(base, crown + Vector2(0, 8 * s), Color("63554a"), 14 * s, true)
	draw_line(base + Vector2(-2, -10 * s), crown + Vector2(-29 * s, 4), Color("63554a"), 6 * s, true)
	draw_line(base + Vector2(2, -32 * s), crown + Vector2(33 * s, -7), Color("73614e"), 5 * s, true)
	var foliage := Color("65604a").lerp(Color("638873"), alive)
	var offsets := [Vector2(-32, 0), Vector2(31, 1), Vector2(-12, -32), Vector2(15, -35), Vector2(0, 9)]
	for j in offsets.size():
		var center: Vector2 = crown + offsets[j] * s
		var canopy := PackedVector2Array()
		for k in 8:
			var angle := TAU * k / 8
			canopy.append(center + Vector2(cos(angle) * 32, sin(angle) * 27) * s)
		draw_colored_polygon(canopy, foliage.darkened(0.15))
		var highlight := PackedVector2Array([canopy[4], canopy[5], canopy[6], canopy[7], center + Vector2(6, 1) * s])
		draw_colored_polygon(highlight, foliage.lightened(0.10 + j * 0.013))
	for j in 11:
		var dot := crown + Vector2(sin(j * 3.4 + seed_value) * 45, cos(j * 2.3) * 35) * s
		draw_arc(dot, 4 * s, PI, TAU, 5, foliage.lightened(0.20), 1, true)
	if hits < 5:
		var fire := 1.0 - float(hits) / 5
		for j in 5:
			var loc := crown + Vector2((j - 2) * 20, 14 + sin(j * 2.1) * 13) * s
			var height := (42 + sin(time * 7 + j * 2 + seed_value) * 9) * s * (0.4 + fire * 0.6)
			var width := 13 * s * (0.4 + fire * 0.6)
			var pts := PackedVector2Array([loc + Vector2(-width, 4), loc + Vector2(-width * 0.8, -height * 0.4), loc + Vector2(sin(time * 5 + j) * 7 * s, -height), loc + Vector2(width, -height * 0.3), loc + Vector2(width, 5)])
			draw_colored_polygon(pts, Color("df7649"))
			draw_circle(loc + Vector2(0, -height * 0.20), width * 0.63, Color("edb667"))
		for j in 3:
			var lift := fmod(time * 30 + j * 23 + seed_value * 10, 80)
			var smoke := crown + Vector2(sin(time + j) * 14, -38 * s - lift)
			draw_circle(smoke, (6 + lift * 0.10) * s, Color(0.45, 0.49, 0.43, (1 - lift / 80) * 0.10))
	else:
		draw_arc(base + Vector2(0, 17 * s), 13 * s, 0.2, PI - 0.2, 15, Color("9db8a0"), 1.2, true)
	var tick_y := base.y + 28 * s
	for j in 5:
		draw_circle(Vector2(base.x + (j - 2) * 10 * s, tick_y), 2.4 * s, MINT if j < hits else Color("526353"))
