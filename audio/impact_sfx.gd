extends Node
## Original short PCM impact sounds. No external recordings or sample packs.
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _last_played: Dictionary = {}
var _elapsed: float = 0.0
var _dummy: bool = false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    _dummy = AudioServer.get_driver_name() == "Dummy"
    var bus: int = AudioServer.get_bus_index("SFX")
    if bus < 0:
        AudioServer.add_bus()
        bus = AudioServer.bus_count - 1
        AudioServer.set_bus_name(bus, "SFX")
    for kind: String in ["light", "heavy", "parry", "reflect", "break", "swing", "dash", "hurt"]:
        _streams[kind] = _synth(kind)
    for i: int in 6:
        var voice := AudioStreamPlayer.new()
        voice.name = "ImpactVoice%d" % i
        voice.bus = "SFX"
        add_child(voice)
        _players.append(voice)

func _process(delta: float) -> void:
    _elapsed += delta

func play_impact(kind: String) -> void:
    if not _streams.has(kind) or _players.is_empty():
        return
    var minimum: float = 0.13 if kind == "dash" else 0.025
    if _elapsed - float(_last_played.get(kind, -10.0)) < minimum:
        return
    _last_played[kind] = _elapsed
    if _dummy:
        return
    var voice: AudioStreamPlayer = _players[_cursor]
    _cursor = (_cursor + 1) % _players.size()
    voice.stop()
    voice.stream = _streams[kind]
    voice.volume_db = -12 if kind == "parry" else (-14 if kind == "heavy" else -17)
    voice.play()

func _synth(kind: String) -> AudioStreamWAV:
    var rate: int = 22050
    var length: float = 0.18 if kind in ["parry", "break"] else (0.14 if kind == "heavy" else 0.08)
    var pcm := PackedByteArray()
    var count: int = int(length * rate)
    pcm.resize(count * 2)
    for i: int in count:
        var t: float = float(i) / rate
        var envelope: float = pow(1.0 - float(i) / count, 2.5) * minf(t * 900.0, 1.0)
        var noise: float = sin(float(i) * 1.932) * cos(float(i) * 0.7341)
        var sample: float
        match kind:
            "reflect": sample = sin(TAU * 1760 * t) * 0.24 + noise * exp(-t * 95) * 0.07
            "break": sample = sin(TAU * (190 * t - 310 * t * t)) * 0.32 + sin(TAU * 880 * t) * exp(-t * 28) * 0.15 + noise * exp(-t * 25) * 0.20
            "parry": sample = (sin(TAU * 1320 * t) + sin(TAU * 1980 * t) * 0.3) * 0.24 + noise * exp(-t * 100) * 0.15
            "heavy": sample = sin(TAU * (130 * t - 190 * t * t)) * 0.32 + noise * exp(-t * 32) * 0.30
            "swing": sample = noise * sin(PI * float(i) / count) * 0.28
            "dash": sample = noise * 0.13 + sin(TAU * 330 * t) * 0.05
            "hurt": sample = sin(TAU * (240 * t - 540 * t * t)) * 0.2 + noise * 0.2
            _: sample = sin(TAU * (420 * t - 1600 * t * t)) * 0.16 + noise * exp(-t * 44) * 0.32
        pcm.encode_s16(i * 2, int(clampf(sample * envelope, -0.8, 0.8) * 32767))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = rate
    stream.data = pcm
    return stream

func _exit_tree() -> void:
    for voice: AudioStreamPlayer in _players:
        if is_instance_valid(voice):
            voice.stop()
            voice.stream = null
