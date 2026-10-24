extends RefCounted
## One pausable transition cursor. The owning scene controls unloading and music.
const DURATION: float = 0.80
var active: bool = false
var progress: float = 0.0
var target: String = ""
var mounted: bool = false

func begin(next_room: String) -> bool:
    if active or next_room not in ["dungeon", "boss"]:
        return false
    target = next_room
    active = true
    mounted = false
    progress = 0.0
    return true

func advance(delta: float) -> Dictionary:
    var result: Dictionary = {"mount": false, "finish": false}
    if not active:
        return result
    progress = minf(1.0, progress + maxf(0.0, delta) / DURATION)
    if progress >= 0.40 and not mounted:
        mounted = true
        result["mount"] = true
    if progress >= 1.0:
        active = false
        result["finish"] = true
    return result
