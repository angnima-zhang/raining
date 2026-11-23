extends SceneTree
const Progress = preload("res://scripts/progress.gd")
var checks := 0
var failed := false

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true
		return
	checks += 1

func _initialize() -> void:
	var p = Progress.new()
	check(not p.buy_upgrade(), "Cannot upgrade before completing level")
	var empty: Array[int] = []
	p.apply_batch(empty)
	check(p.hits[0] == 0 and p.coins == 0, "Off-target rain gives no progress or coins")
	var first: Array[int] = [0]
	for i in 4:
		p.apply_batch(first)
	check(p.phase == "playing" and p.coins == 0, "Four batches cannot clear first tree")
	p.apply_batch(first)
	check(p.phase == "cleared" and p.coins == 10, "Fifth batch clears and rewards 10")
	p.apply_batch(first)
	check(p.coins == 10, "Completed tree cannot reward twice")
	check(not p.next_level(), "Upgrade required for tutorial progression")
	check(p.buy_upgrade() and p.coins == 0 and p.cooldown() == 0.65, "Speed reward exactly funds speed upgrade")
	check(not p.buy_upgrade(), "No duplicate upgrade")
	check(p.next_level() and p.hits.size() == 3, "Level two has three trees")
	for index in 3:
		var target: Array[int] = [index]
		for i in 5: p.apply_batch(target)
	check(p.phase == "cleared" and p.coins == 30, "Level two rewards 30 once all trees extinguished")
	check(p.buy_upgrade() and p.coins == 0 and p.radius() == 125, "Range reward exactly funds range upgrade")
	check(p.next_level() and p.hits.size() == 10, "Level three has ten trees")
	var all: Array[int] = []
	for i in 10: all.append(i)
	for i in 5: p.apply_batch(all)
	check(p.phase == "finished" and p.coins == 50, "Third level finishes")
	check(not p.next_level(), "No invalid fourth level")
	p.reset()
	check(p.level == 0 and p.coins == 0 and p.speed_level == 0 and p.range_level == 0 and p.hits == [0], "Restart resets all progress")
	print("PASS: %d progression checks" % checks)
	quit(1 if failed else 0)
