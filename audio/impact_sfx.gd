extends Node
## Original short PCM impact sounds. No external recordings or sample packs.
## Every sound is layered: a low body thump, a noise crack, a metallic or glassy ring and, for the big ones,
## a crystal shatter tail. Noise is real (seeded) white noise, softened by a one-pole filter where a whoosh is wanted.
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _last_played: Dictionary = {}
var _elapsed: float = 0.0
var _dummy: bool = false
var _rng := RandomNumberGenerator.new()
const KINDS: Array[String] = ["light", "heavy", "parry", "reflect", "break", "swing", "dash", "hurt", "stun", "launch", "air_jump"]
const RATE: int = 32000

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    _dummy = AudioServer.get_driver_name() == "Dummy"
    var bus: int = AudioServer.get_bus_index("SFX")
    if bus < 0:
        AudioServer.add_bus()
        bus = AudioServer.bus_count - 1
        AudioServer.set_bus_name(bus, "SFX")
    for kind: String in KINDS:
        _streams[kind] = _synth(kind)
    for i: int in 8:
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
    var minimum: float = 0.13 if kind == "dash" else (0.06 if kind == "swing" else 0.025)
    if _elapsed - float(_last_played.get(kind, -10.0)) < minimum:
        return
    _last_played[kind] = _elapsed
    if _dummy:
        return
    var voice: AudioStreamPlayer = _players[_cursor]
    _cursor = (_cursor + 1) % _players.size()
    voice.stop()
    voice.stream = _streams[kind]
    # Louder than before (was -17 / -14 / -12 dB) and a slight random pitch so repeated hits do not machine-gun.
    var gain: Dictionary = {"heavy": -4.0, "break": -3.0, "parry": -6.0, "reflect": -8.0, "light": -7.0, "stun": -8.0, "launch": -6.0, "hurt": -7.0, "swing": -13.0, "dash": -14.0, "air_jump": -12.0}
    voice.volume_db = float(gain.get(kind, -9.0))
    voice.pitch_scale = _rng.randf_range(0.94, 1.07) if kind in ["light", "heavy", "swing", "hurt"] else 1.0
    voice.play()

func _noise() -> float:
    return _rng.randf_range(-1.0, 1.0)

func _synth(kind: String) -> AudioStreamWAV:
    _rng.seed = hash(kind)
    var length: float = {"light": 0.2, "heavy": 0.42, "parry": 0.3, "reflect": 0.22, "break": 0.5, "swing": 0.2, "dash": 0.16, "hurt": 0.3, "stun": 0.45, "launch": 0.4, "air_jump": 0.36}.get(kind, 0.2)
    var count: int = int(length * RATE)
    var pcm := PackedByteArray()
    pcm.resize(count * 2)
    var low: float = 0.0
    for i: int in count:
        var t: float = float(i) / RATE
        var u: float = float(i) / count
        var attack: float = minf(t * 2500.0, 1.0)
        var n: float = _noise()
        var sample: float = 0.0
        match kind:
            "light":
                # Thump (260 to 80 Hz) + sharp crack + a short steel ring.
                sample = sin(TAU * (260.0 * t - 900.0 * t * t)) * exp(-t * 34.0) * 0.55
                sample += n * exp(-t * 80.0) * 0.55
                sample += (sin(TAU * 2600.0 * t) + sin(TAU * 3900.0 * t) * 0.5) * exp(-t * 30.0) * 0.16
            "heavy":
                # Sub boom + hard crack + steel ring + glassy shatter tail.
                sample = sin(TAU * (120.0 * t - 160.0 * t * t)) * exp(-t * 7.5) * 0.85
                sample += n * exp(-t * 34.0) * 0.6
                sample += (sin(TAU * 1900.0 * t) + sin(TAU * 2850.0 * t) * 0.6) * exp(-t * 16.0) * 0.18
                sample += (sin(TAU * 3100.0 * t) + sin(TAU * 4300.0 * t) + sin(TAU * 5200.0 * t) + sin(TAU * 6100.0 * t)) * exp(-t * 14.0) * 0.07 * (0.6 + 0.4 * sin(TAU * 38.0 * t))
            "parry":
                sample = (sin(TAU * 1320.0 * t) + sin(TAU * 1980.0 * t) * 0.5 + sin(TAU * 2640.0 * t) * 0.3) * exp(-t * 11.0) * 0.28
                sample += n * exp(-t * 90.0) * 0.4 + sin(TAU * (200.0 * t - 400.0 * t * t)) * exp(-t * 30.0) * 0.3
            "reflect":
                sample = (sin(TAU * 1760.0 * t) + sin(TAU * 2349.0 * t) * 0.6) * exp(-t * 16.0) * 0.28 + n * exp(-t * 95.0) * 0.18
            "break":
                sample = sin(TAU * (170.0 * t - 220.0 * t * t)) * exp(-t * 6.0) * 0.8
                sample += n * exp(-t * 20.0) * 0.5
                sample += (sin(TAU * 880.0 * t) + sin(TAU * 1320.0 * t) * 0.7 + sin(TAU * 3300.0 * t) * 0.4) * exp(-t * 9.0) * 0.18
                sample += (sin(TAU * 4200.0 * t) + sin(TAU * 5600.0 * t)) * exp(-t * 11.0) * 0.08 * (0.5 + 0.5 * sin(TAU * 31.0 * t))
            "swing":
                # Whoosh: low-passed noise that opens up toward the middle, with a rising airy tone.
                var open: float = 0.05 + 0.5 * sin(PI * u)
                low += (n - low) * open
                sample = low * sin(PI * pow(u, 0.7)) * 0.9 + sin(TAU * (500.0 * t + 3500.0 * t * t)) * sin(PI * u) * 0.05
                attack = 1.0
            "dash":
                low += (n - low) * (0.12 + 0.3 * u)
                sample = low * (1.0 - u) * 0.8 + sin(TAU * 260.0 * t) * (1.0 - u) * 0.08
                attack = minf(t * 300.0, 1.0)
            "hurt":
                sample = sin(TAU * (320.0 * t - 700.0 * t * t)) * exp(-t * 12.0) * 0.6
                sample += n * exp(-t * 36.0) * 0.45
                sample += sin(TAU * 140.0 * t) * sin(TAU * 151.0 * t) * exp(-t * 9.0) * 0.4
            "stun":
                # Dizzy ding-ding: two bell notes with a wobble.
                var bell: float = (sin(TAU * 988.0 * t) + sin(TAU * 1976.0 * t) * 0.4 + sin(TAU * 2960.0 * t) * 0.2) * exp(-t * 13.0)
                var t2: float = maxf(t - 0.16, 0.0)
                var bell2: float = (sin(TAU * 1318.0 * t2) + sin(TAU * 2636.0 * t2) * 0.4) * exp(-t2 * 13.0) * (1.0 if t >= 0.16 else 0.0)
                sample = (bell + bell2) * 0.3 * (0.85 + 0.15 * sin(TAU * 9.0 * t))
            "launch":
                # Hard thump followed by a rising whoosh and a bright shard sweep.
                sample = sin(TAU * (200.0 * t - 450.0 * t * t)) * exp(-t * 22.0) * 0.7
                low += (n - low) * (0.1 + 0.5 * u)
                sample += low * sin(PI * minf(u * 1.3, 1.0)) * 0.55
                sample += sin(TAU * (400.0 * t + 2400.0 * t * t)) * exp(-t * 6.0) * 0.14
                sample += n * exp(-t * 60.0) * 0.4
            "air_jump":
                # Feather flutter: shimmering noise pulses and a soft chime.
                low += (n - low) * 0.35
                sample = low * (0.5 + 0.5 * sin(TAU * 26.0 * t)) * exp(-t * 7.0) * 0.5
                sample += (sin(TAU * 1568.0 * t) + sin(TAU * 2093.0 * t) * 0.6) * exp(-t * 11.0) * 0.12
                attack = minf(t * 400.0, 1.0)
            _:
                sample = n * exp(-t * 40.0) * 0.4
        var shaped: float = tanh(sample * attack * 1.25) * 0.88
        pcm.encode_s16(i * 2, int(clampf(shaped, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = RATE
    stream.data = pcm
    return stream

func _exit_tree() -> void:
    for voice: AudioStreamPlayer in _players:
        if is_instance_valid(voice):
            voice.stop()
            voice.stream = null
