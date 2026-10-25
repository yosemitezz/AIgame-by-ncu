extends SceneTree
## Validate every chapter-data glyph against the bundled native pixel font.
const FontFactory=preload("res://presentation/pixel_font.gd")
var failed:int=0
var passed:int=0
var strings:Array[String]=[]
func collect(value:Variant)->void:
    if value is String:strings.append(value)
    elif value is Dictionary:
        for key:Variant in value:collect(value[key])
    elif value is Array:
        for item:Variant in value:collect(item)
func _initialize()->void:call_deferred("run")
func run()->void:
    var data:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapter_story.json"))
    if not data is Dictionary:push_error("FAIL chapter data is not JSON");quit(1);return
    collect(data)
    var font:FontFile=FontFactory.create()
    var seen:Dictionary={}
    var missing:Array[String]=[]
    var cjk:int=0
    for text:String in strings:
        for index:int in text.length():
            var code:int=text.unicode_at(index)
            if code<32 or seen.has(code):continue
            seen[code]=true
            if code>=0x4e00 and code<=0x9fff:cjk+=1
            if not font.has_char(code):missing.append("U+%04X"%code)
    if cjk<80:failed+=1;push_error("FAIL chapter Chinese text missing or encoding-corrupted")
    else:passed+=1
    if not missing.is_empty():failed+=1;push_error("FAIL chapter font lacks "+str(missing))
    else:passed+=1
    if font.allow_system_fallback or not font.fallbacks.is_empty():failed+=1;push_error("FAIL mixed system font fallback")
    else:passed+=1
    var output:FileAccess=FileAccess.open("res://artifacts/chapter-story/font-report.json",FileAccess.WRITE)
    output.store_string(JSON.stringify({"unique_glyphs":seen.size(),"cjk_glyphs":cjk,"missing":missing,"passed":passed,"failed":failed},"  "))
    print("Chapter font: %d passed, %d failed; %d native glyphs"%[passed,failed,seen.size()])
    quit(0 if failed==0 else 1)
