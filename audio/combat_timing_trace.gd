extends RefCounted
## Discrete same-clock diagnostics; no timer, playback, automatic file writes or audio data.
var enabled: bool = true
var limit: int = 8192
var events: Array[Dictionary] = []
func record(kind: String, scheduled: float, actual: float, context: Dictionary = {}) -> void:
    if not enabled or not is_finite(scheduled) or not is_finite(actual): return
    events.append({"kind": kind, "scheduled": scheduled, "actual": actual, "error_ms": (actual - scheduled) * 1000.0, "context": context.duplicate(true)})
    if events.size() > limit: events.pop_front()
func clear() -> void:
    events.clear()
func summary() -> Dictionary:
    var groups: Dictionary = {}
    for event: Dictionary in events:
        var kind: String = str(event["kind"])
        if not groups.has(kind): groups[kind] = []
        groups[kind].append(float(event["error_ms"]))
    var result: Dictionary = {}
    for kind: String in groups:
        var values: Array = groups[kind]
        values.sort()
        var total: float = 0.0
        for value: float in values: total += value
        result[kind] = {"count": values.size(), "min_ms": values[0], "max_ms": values[-1], "mean_ms": total / values.size(), "p95_ms": values[mini(values.size()-1, int(ceil(float(values.size()) * 0.95))-1)]}
    return result
