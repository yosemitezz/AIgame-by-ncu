extends RefCounted
## Small local chapter/run save. No network, private paths or export-time side effects.
const VERSION: int=1
static func read(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):return {}
    var parser:=JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path))!=OK:return {}
    var parsed:Variant=parser.data
    if not parsed is Dictionary or parsed.get("version",-1)!=VERSION:return {}
    if not parsed.has("story") or not parsed.has("progress"):return {}
    if not parsed["story"] is Dictionary or not parsed["progress"] is Dictionary:return {}
    return parsed.duplicate(true)
static func write(path: String,story: Dictionary,progress: Dictionary) -> Error:
    var absolute: String=ProjectSettings.globalize_path(path)
    var error: Error=DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    if error!=OK:return error
    var stream: FileAccess=FileAccess.open(path,FileAccess.WRITE)
    if stream==null:return FileAccess.get_open_error()
    stream.store_string(JSON.stringify({"version":VERSION,"story":story,"progress":progress},"  ")+"\n")
    stream.flush()
    return OK
static func erase(path: String) -> Error:
    if not FileAccess.file_exists(path):return OK
    return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))