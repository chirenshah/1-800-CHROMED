extends Node
class_name SalesSlamAudio
## Temporary procedural audio for Sales Slam. Every sound is synthesized here as a clearly
## placeholder tone, so final assets can replace `_stream_for` without touching the board.
## The board never depends on this node: with it missing, muted, or failing, playback is identical.

const RATE := 22050
const POOL_SIZE := 10
const HEADROOM := 0.55

var enabled := true
var master_volume := 1.0
## Independent per-category volumes (0..1): impact, tension, payoff.
var category_volume := {"impact": 1.0, "tension": 1.0, "payoff": 1.0}

var _board
var _plan := SalesSlamPlan.new()
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1800


func attach(board) -> void:
	_board = board
	_plan = board.plan
	board.sale_impacted.connect(_on_sale_impacted)
	board.anticipation_started.connect(_on_anticipation)
	board.goal_broken.connect(_on_goal_broken)
	board.reveal_started.connect(_on_reveal)
	board.finished.connect(_on_finished)
	board.audio_silenced.connect(silence)


func silence() -> void:
	for player in _players:
		player.stop()


# --- Event handlers --------------------------------------------------------

func _on_sale_impacted(_index: int, step: Dictionary) -> void:
	if step["breaks_goal"]:
		return
	var heat: float = step["intensity"]
	var progress := clampf(float(step["tally_after"]) / maxf(float(_board.goal), 1.0), 0.0, 1.0)
	# Pitch climbs with progress so the whole tally reads as a rising line.
	var pitch := (0.8 + 0.55 * progress) * lerpf(0.9, 1.1, heat)
	var heavy := heat >= _plan.heavy_intensity
	_play("impact_heavy" if heavy else "impact", "impact", pitch, lerpf(0.45, 1.0, heat))
	var stage: int = step["stage"]
	if stage >= SalesSlamPlan.Stage.WARM and stage < SalesSlamPlan.Stage.REACHED:
		var tension_gain := 0.25 + 0.2 * float(stage - SalesSlamPlan.Stage.WARM)
		_play("tick", "tension", 0.8 + 0.8 * progress, tension_gain)
	if int(step["tally_after"]) == _board.goal:
		_play("chime", "payoff", 1.0, 0.9)


func _on_anticipation(_step: Dictionary, seconds: float) -> void:
	_play("riser", "tension", _plan.windup_seconds / maxf(seconds, 0.05), 0.9)


func _on_goal_broken(_step: Dictionary) -> void:
	# A skip jumps straight to the end state silently.
	if _board.running:
		_play("boom", "payoff", 1.0, 1.0)


func _on_reveal(near_miss: bool) -> void:
	if not near_miss:
		_play("final", "payoff", 1.0, 0.7)


func _on_finished(result: Dictionary) -> void:
	if result.get("skipped", false):
		return
	if result["outcome"] == SalesSlamPlan.Outcome.SHORT:
		_play("fail", "payoff", 1.0, 0.8)


# --- Playback --------------------------------------------------------------

func _play(key: String, category: String, pitch: float, gain: float) -> void:
	if not enabled or not is_inside_tree():
		return
	var volume := master_volume * float(category_volume.get(category, 1.0)) * gain * HEADROOM
	if volume <= 0.0001:
		return
	var player := _acquire_player()
	player.stream = _stream_for(key)
	player.pitch_scale = maxf(pitch, 0.1)
	player.volume_db = linear_to_db(volume)
	player.play()


func _acquire_player() -> AudioStreamPlayer:
	if _players.size() < POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
		return player
	var reused := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return reused


func _stream_for(key: String) -> AudioStreamWAV:
	if not _streams.has(key):
		_streams[key] = _synthesize(key)
	return _streams[key]


# --- Placeholder synthesis -------------------------------------------------

func _synthesize(key: String) -> AudioStreamWAV:
	match key:
		"impact":
			return _to_stream(_thump(0.2, 240.0, 80.0, 0.04, 14.0, 0.5))
		"impact_heavy":
			return _to_stream(_thump(0.34, 200.0, 55.0, 0.06, 8.0, 0.8))
		"tick":
			return _to_stream(_tone(0.09, 1320.0, 45.0))
		"riser":
			return _to_stream(_riser(_plan.windup_seconds))
		"chime":
			return _to_stream(_chime())
		"boom":
			return _to_stream(_boom())
		"fail":
			return _to_stream(_fail())
		_:
			return _to_stream(_final())


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		bytes.encode_s16(index * 2, roundi(clampf(samples[index], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream


func _blank(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


## Pitch-dropping sine with a short noise click: the "slam".
func _thump(seconds: float, f_start: float, f_end: float, tau: float, decay: float, click: float) -> PackedFloat32Array:
	var samples := _blank(seconds)
	for index in samples.size():
		var t := float(index) / RATE
		var phase := TAU * (f_end * t + (f_start - f_end) * tau * (1.0 - exp(-t / tau)))
		var value := sin(phase) * exp(-t * decay)
		if t < 0.006:
			value += (_rng.randf() * 2.0 - 1.0) * (1.0 - t / 0.006) * click
		samples[index] = value * 0.9
	return samples


func _tone(seconds: float, frequency: float, decay: float) -> PackedFloat32Array:
	var samples := _blank(seconds)
	for index in samples.size():
		var t := float(index) / RATE
		samples[index] = sin(TAU * frequency * t) * exp(-t * decay) * 0.6
	return samples


## Rising sweep that goes quiet right at the end, so the hit lands after a breath of silence.
func _riser(seconds: float) -> PackedFloat32Array:
	var samples := _blank(seconds)
	var low := 150.0
	var high := 1000.0
	for index in samples.size():
		var t := float(index) / RATE
		var phase := TAU * (low * t + (high - low) / (2.0 * seconds) * t * t)
		var progress := t / seconds
		var tremolo := 0.6 + 0.4 * sin(TAU * 18.0 * t)
		var tail := clampf((1.0 - progress) * 12.0, 0.0, 1.0)
		samples[index] = sin(phase) * progress * progress * tremolo * tail * 0.8
	return samples


## Bright rising arpeggio for hitting the goal exactly.
func _chime() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var samples := _blank(0.75)
	for index in samples.size():
		var t := float(index) / RATE
		var note := mini(int(t / 0.1), notes.size() - 1)
		var local := t - float(note) * 0.1
		var frequency: float = notes[note]
		var decay := 6.0 if note < notes.size() - 1 else 3.0
		var value := sin(TAU * frequency * t) + 0.3 * sin(TAU * frequency * 2.0 * t)
		samples[index] = value * exp(-local * decay) * 0.4
	return samples


## Cracking noise burst over a collapsing low sine.
func _boom() -> PackedFloat32Array:
	var samples := _blank(1.5)
	var smoothed := 0.0
	for index in samples.size():
		var t := float(index) / RATE
		smoothed += ((_rng.randf() * 2.0 - 1.0) - smoothed) * 0.08
		var rumble := smoothed * 3.0 * exp(-t * 2.6)
		var phase := TAU * (30.0 * t + 70.0 * 0.25 * (1.0 - exp(-t / 0.25)))
		var low := sin(phase) * exp(-t * 1.8) * 0.9
		var crack := 0.0
		if t < 0.012:
			crack = (_rng.randf() * 2.0 - 1.0) * (1.0 - t / 0.012)
		samples[index] = clampf(rumble + low + crack, -1.0, 1.0)
	return samples


## Two sagging notes with no payoff.
func _fail() -> PackedFloat32Array:
	var samples := _blank(0.8)
	for index in samples.size():
		var t := float(index) / RATE
		var second := t >= 0.3
		var local := t - (0.3 if second else 0.0)
		var frequency := 233.1 if second else 311.1
		var value := sin(TAU * frequency * t) + 0.3 * sin(TAU * frequency * 2.0 * t)
		samples[index] = value * exp(-local * 3.0) * minf(1.0, local * 200.0) * 0.45
	return samples


func _final() -> PackedFloat32Array:
	var samples := _blank(0.4)
	for index in samples.size():
		var t := float(index) / RATE
		samples[index] = (sin(TAU * 196.0 * t) * exp(-t * 7.0) + 0.5 * sin(TAU * 392.0 * t) * exp(-t * 9.0)) * 0.6
	return samples
