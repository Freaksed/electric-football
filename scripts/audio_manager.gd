extends Node
## Autoload singleton that manages all game audio.
## Generates procedural sounds for the electric football experience.

# Audio players
var _buzz_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

# Generated audio streams
var _buzz_stream: AudioStreamGenerator
var _whistle_stream: AudioStreamWAV
var _touchdown_stream: AudioStreamWAV
var _kick_stream: AudioStreamWAV

# Buzz parameters
var _buzz_playback: AudioStreamGeneratorPlayback
var _buzz_phase: float = 0.0
const BUZZ_FREQUENCY := 120.0  # Hz - the iconic electric football buzz
const BUZZ_MIX_RATE := 44100.0


func _ready() -> void:
	_setup_audio_players()
	_generate_sounds()
	_connect_signals()


func _setup_audio_players() -> void:
	# Buzz player (looping generator)
	_buzz_player = AudioStreamPlayer.new()
	_buzz_player.bus = "Master"
	_buzz_player.volume_db = -6.0
	add_child(_buzz_player)

	# SFX player (one-shot sounds)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	_sfx_player.volume_db = -3.0
	add_child(_sfx_player)

	# Create buzz stream generator
	_buzz_stream = AudioStreamGenerator.new()
	_buzz_stream.mix_rate = BUZZ_MIX_RATE
	_buzz_stream.buffer_length = 0.1
	_buzz_player.stream = _buzz_stream


func _generate_sounds() -> void:
	_whistle_stream = _generate_whistle()
	_touchdown_stream = _generate_touchdown()
	_kick_stream = _generate_kick()


func _connect_signals() -> void:
	# Connect to VibrationController
	var vibration := get_node_or_null("/root/VibrationController")
	if vibration:
		vibration.vibration_started.connect(_on_vibration_started)
		vibration.vibration_stopped.connect(_on_vibration_stopped)


func _process(_delta: float) -> void:
	# Fill buzz buffer when playing
	if _buzz_player.playing and _buzz_playback:
		_fill_buzz_buffer()


func _on_vibration_started() -> void:
	play_buzz()


func _on_vibration_stopped() -> void:
	stop_buzz()
	play_whistle()


## Start the buzz sound
func play_buzz() -> void:
	if not _buzz_player.playing:
		_buzz_player.play()
		_buzz_playback = _buzz_player.get_stream_playback()
		_buzz_phase = 0.0


## Stop the buzz sound
func stop_buzz() -> void:
	_buzz_player.stop()
	_buzz_playback = null


## Play the whistle sound
func play_whistle() -> void:
	_sfx_player.stream = _whistle_stream
	_sfx_player.play()


## Play the touchdown celebration sound
func play_touchdown() -> void:
	_sfx_player.stream = _touchdown_stream
	_sfx_player.play()


## Play the kick sound
func play_kick() -> void:
	_sfx_player.stream = _kick_stream
	_sfx_player.play()


## Fill the buzz buffer with generated audio
func _fill_buzz_buffer() -> void:
	if not _buzz_playback:
		return

	var frames_available := _buzz_playback.get_frames_available()

	for i in range(frames_available):
		# Generate buzz using multiple harmonics for that electric motor sound
		var sample := 0.0

		# Fundamental frequency
		sample += sin(_buzz_phase * TAU) * 0.3

		# First harmonic (2x)
		sample += sin(_buzz_phase * 2.0 * TAU) * 0.2

		# Second harmonic (3x) - adds the "buzz" character
		sample += sin(_buzz_phase * 3.0 * TAU) * 0.15

		# Third harmonic (4x)
		sample += sin(_buzz_phase * 4.0 * TAU) * 0.1

		# Add slight noise for grit
		sample += randf_range(-0.05, 0.05)

		# Amplitude modulation for pulsing effect
		var mod := 0.8 + 0.2 * sin(_buzz_phase * 0.5 * TAU)
		sample *= mod

		_buzz_playback.push_frame(Vector2(sample, sample))

		_buzz_phase += BUZZ_FREQUENCY / BUZZ_MIX_RATE
		if _buzz_phase > 1.0:
			_buzz_phase -= 1.0


## Generate a whistle sound (procedural)
func _generate_whistle() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.4  # seconds
	var samples := int(sample_rate * duration)

	var data := PackedByteArray()
	data.resize(samples * 2)  # 16-bit samples

	var freq := 2800.0  # Whistle frequency
	var phase := 0.0

	for i in range(samples):
		# Envelope (attack and decay)
		var t := float(i) / float(samples)
		var envelope := 1.0
		if t < 0.05:
			envelope = t / 0.05  # Quick attack
		elif t > 0.7:
			envelope = (1.0 - t) / 0.3  # Decay

		# Add slight pitch bend
		var pitch_mod := 1.0 + 0.02 * sin(t * 20.0)

		# Generate tone
		var sample := sin(phase * TAU) * envelope * 0.4
		phase += (freq * pitch_mod) / sample_rate
		if phase > 1.0:
			phase -= 1.0

		# Convert to 16-bit
		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


## Generate a touchdown celebration sound (crowd cheer simulation)
func _generate_touchdown() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 1.0  # seconds
	var samples := int(sample_rate * duration)

	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / float(samples)

		# Envelope
		var envelope := 1.0
		if t < 0.1:
			envelope = t / 0.1
		elif t > 0.5:
			envelope = (1.0 - t) / 0.5

		# Noise-based cheer (filtered noise)
		var sample := randf_range(-1.0, 1.0) * 0.3

		# Add some tonal content
		sample += sin(t * 400.0 * TAU / sample_rate * float(i)) * 0.1
		sample += sin(t * 600.0 * TAU / sample_rate * float(i)) * 0.08

		sample *= envelope

		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


## Generate a kick/throw sound
func _generate_kick() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.15  # seconds
	var samples := int(sample_rate * duration)

	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / float(samples)

		# Fast decay envelope
		var envelope := pow(1.0 - t, 2.0)

		# Percussive thump with pitch drop
		var freq := 200.0 * (1.0 - t * 0.5)  # Pitch drops
		var phase := float(i) * freq / sample_rate
		var sample := sin(phase * TAU) * envelope * 0.5

		# Add noise transient at start
		if t < 0.05:
			sample += randf_range(-0.3, 0.3) * (1.0 - t / 0.05)

		var sample_int := int(clampf(sample, -1.0, 1.0) * 32767)
		data[i * 2] = sample_int & 0xFF
		data[i * 2 + 1] = (sample_int >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
