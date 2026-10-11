class_name SoundBank
extends Node
var enabled = true
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var cursor = 0

func _ready() -> void:
	for i in 4:
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	samples["walk"] = tone([240.0], 0.055, 0.07)
	samples["push"] = tone([150.0, 190.0], 0.06, 0.12)
	samples["blocked"] = tone([90.0], 0.06, 0.07)
	samples["goal"] = tone([523.25, 783.99], 0.09, 0.13)
	samples["win"] = tone([523.25, 659.25, 783.99, 1046.5], 0.13, 0.16)
	samples["undo"] = tone([330.0, 220.0], 0.05, 0.09)

func play_sound(kind: String) -> void:
	if not enabled or not samples.has(kind): return
	var voice = voices[cursor % voices.size()]
	cursor += 1
	voice.stream = samples[kind]
	voice.play()

func tone(notes: Array, seconds: float, gain: float) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	var count = int(22050 * seconds)
	bytes.resize(count * notes.size() * 2)
	for n in notes.size():
		for i in count:
			var t = float(i) / 22050.0
			var envelope = sin(PI * float(i) / count)
			var value = int(sin(TAU * float(notes[n]) * t) * envelope * gain * 32767.0)
			bytes.encode_s16((n * count + i) * 2, value)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	return stream

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	samples.clear()