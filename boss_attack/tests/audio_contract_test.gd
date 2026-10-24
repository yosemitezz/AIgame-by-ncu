extends SceneTree

const MUSIC_PATH := "res://audio/if_infinity.ogg"

var passed := 0
var failed := 0


func _initialize() -> void:
	assert_true(ResourceLoader.exists(MUSIC_PATH), "music resource exists")
	var stream: Resource = load(MUSIC_PATH)
	assert_true(stream is AudioStream, "music imports as AudioStream")
	if stream is AudioStream:
		assert_true(stream.get_length() > 400.0, "music stream reports its duration")
	print("AUDIO RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func assert_true(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s" % label)
