extends Node

var player: AudioStreamPlayer
var enabled := true
var target_db := -22.0
var rain_mix := 0.0

func _ready() -> void:
	# Generate a short noise bed once; smoothing the seam keeps loop clicks small.
	var random := RandomNumberGenerator.new()
	random.seed = 23917
	var samples := 22050 * 8
	var pcm := PackedByteArray()
	pcm.resize(samples * 2)
	var values := PackedFloat32Array()
	values.resize(samples)
	var low := 0.0
	var bass := 0.0
	for i in samples:
		var n := random.randf_range(-1, 1)
		low += 0.24 * (n - low)
		bass += 0.025 * (low - bass)
		values[i] = (low - bass * 0.45) * 0.8
	var seam := 2048
	for i in seam:
		var ratio := float(i) / seam
		values[i] = lerpf(values[samples - seam + i], values[i], ratio)
	# Use the same crossing point at the loop boundary without a silent fade.
	values[0] = values[samples - 1]
	for i in samples:
		pcm.encode_s16(i * 2, int(clampf(values[i], -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -60
	add_child(player)
	if DisplayServer.get_name() != "headless":
		player.play()

func _process(delta: float) -> void:
	var desired := target_db if enabled else -70.0
	if player:
		player.volume_db = move_toward(player.volume_db, desired, delta * 22)

func set_raining(active: bool) -> void:
	target_db = -14.0 if active else -24.0

func _exit_tree() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
