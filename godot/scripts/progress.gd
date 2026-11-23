class_name RainProgress
extends RefCounted

const SPEED_COST := 10
const RANGE_COST := 30
const REWARDS := [10, 30, 50]
const TREE_COUNTS := [1, 3, 10]
const SAVE_FILE := "user://raining_v1.json"
var level := 0
var coins := 0
var speed_level := 0
var range_level := 0
var phase := "playing"
var hits: Array[int] = [0]
var batches := 0
var elapsed := 0.0

func cooldown() -> float:
	return 0.65 if speed_level > 0 else 1.0

func radius() -> float:
	return 125.0 if range_level > 0 else 55.0

func apply_batch(indices: Array[int]) -> int:
	if phase != "playing":
		return 0
	batches += 1
	var affected := 0
	for index in indices:
		if index >= 0 and index < hits.size() and hits[index] < 5:
			hits[index] += 1
			affected += 1
	var all_out := true
	for value in hits:
		if value < 5:
			all_out = false
	if all_out:
		coins += REWARDS[level]
		phase = "cleared" if level < 2 else "finished"
	return affected

func buy_upgrade() -> bool:
	if phase != "cleared":
		return false
	var cost: int = SPEED_COST if level == 0 else RANGE_COST
	if coins < cost:
		return false
	coins -= cost
	if level == 0:
		speed_level = 1
	else:
		range_level = 1
	phase = "ready"
	return true

func next_level() -> bool:
	if phase != "ready" or level >= 2:
		return false
	level += 1
	hits.clear()
	for i in TREE_COUNTS[level]:
		hits.append(0)
	phase = "playing"
	batches = 0
	elapsed = 0.0
	return true

func reset() -> void:
	level = 0
	coins = 0
	speed_level = 0
	range_level = 0
	phase = "playing"
	hits = [0]
	batches = 0
	elapsed = 0.0

func save_game() -> void:
	var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version":1, "level":level, "coins":coins,
			"speed":speed_level, "range":range_level, "phase":phase, "hits":hits,
			"batches":batches, "elapsed":elapsed}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if not data is Dictionary or data.get("version") != 1:
		return
	var candidate_level := int(data.get("level", -1))
	var candidate_hits = data.get("hits", [])
	if candidate_level < 0 or candidate_level > 2 or not candidate_hits is Array:
		return
	if candidate_hits.size() != TREE_COUNTS[candidate_level]:
		return
	var candidate_phase := str(data.get("phase", ""))
	if candidate_phase not in ["playing", "cleared", "ready", "finished"]:
		return
	level = candidate_level
	coins = maxi(0, int(data.get("coins", 0)))
	speed_level = clampi(int(data.get("speed", 0)), 0, 1)
	range_level = clampi(int(data.get("range", 0)), 0, 1)
	phase = candidate_phase
	hits.clear()
	for value in candidate_hits:
		hits.append(clampi(int(value), 0, 5))
	batches = maxi(0, int(data.get("batches", 0)))
	elapsed = maxf(0, float(data.get("elapsed", 0)))
