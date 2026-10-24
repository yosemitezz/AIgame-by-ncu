extends RefCounted
## Fusion Pixel Font, unmodified 12px monospaced zh-Hans, release 2026.10.16.
## The font and its component notices remain under SIL OFL 1.1; see assets/fonts/.

const FONT_PATH: String = "res://assets/fonts/fusion-pixel-12px-monospaced-zh_hans.otf"
const NATIVE_SIZE: int = 12
const LARGE_SIZE: int = 24

static func create() -> FontFile:
	var source: Resource = ResourceLoader.load(FONT_PATH, "FontFile")
	if not source is FontFile:
		push_error("Fusion Pixel Font could not be loaded. Import project resources first.")
		return null
	var font: FontFile = source.duplicate(true) as FontFile
	# A missing glyph must remain visible to validation rather than silently mixing styles.
	font.allow_system_fallback = false
	font.fallbacks = []
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.multichannel_signed_distance_field = false
	font.generate_mipmaps = false
	font.hinting = TextServer.HINTING_NONE
	font.force_autohinter = false
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.keep_rounding_remainders = false
	font.oversampling = 1.0
	# This is an OpenType outline font authored on a 12px grid. fixed_size is for
	# bitmap fonts; keep this OTF dynamic and request only native integer multiples.
	font.fixed_size = 0
	return font

static func is_native_multiple(size: int) -> bool:
	return size >= NATIVE_SIZE and size % NATIVE_SIZE == 0
