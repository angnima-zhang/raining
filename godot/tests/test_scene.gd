extends SceneTree

class MemoryProgress extends "res://scripts/progress.gd":
	func save_game() -> void:
		pass
	func load_game() -> void:
		pass

var game: Node
var checks := 0
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failed = true
	checks += 1

func rain_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	game._unhandled_input(event)
	game._process(0.01)
	event.pressed = false
	game._input(event)
	game._process(0.5)
	game._process(0.6)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.progress = MemoryProgress.new()
	root.add_child(game)
	game.set_process(false)
	check(game.trees.size() == 1, "First scene has one tree")
	for i in 5: rain_at(Vector2(490, 205))
	check(game.progress.phase == "cleared" and game.progress.coins == 10, "Mouse input and delayed rain complete first level")
	game._on_action()
	check(game.progress.speed_level == 1 and game.progress.coins == 0, "Speed purchase updates state")
	game._on_action()
	check(game.trees.size() == 3, "Second scene has three isometric trees")
	for tree in game.trees:
		for i in 5: rain_at(Vector2(tree.base.x, 205))
	check(game.progress.phase == "cleared" and game.progress.coins == 30, "Second scene clears and rewards")
	game._on_action()
	game._on_action()
	check(game.trees.size() == 10 and game.progress.radius() == 125, "Third scene has ten trees and expanded cloud")
	for i in 5: rain_at(Vector2(334, 180))
	var out := 0
	for count in game.progress.hits:
		if count == 5: out += 1
	check(out > 1, "Expanded cloud extinguishes multiple isometric trees per batch")
	for tree in game.trees:
		for i in 5: rain_at(Vector2(tree.base.x, 180))
	check(game.progress.phase == "finished" and game.progress.coins == 50, "All three scenes complete")
	check(game.weather.player.stream is AudioStreamWAV and game.weather.player.stream.data.size() == 352800, "Generated rain uses bounded 8-second PCM buffer")
	print("PASS: %d scene/input/audio checks (in-memory progress; player save untouched)" % checks)
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(1 if failed else 0)
