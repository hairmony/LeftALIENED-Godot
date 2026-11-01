class_name RunStats
extends RefCounted

const CLASSIC: String = "classic"
const ENDLESS: String = "endless"

static var last: String = CLASSIC
static var classic_stages: Array = []
static var classic_totals: Dictionary = {}
static var endless_stages: Array = []
static var endless_totals: Dictionary = {}
static var _loaded: bool = false


static func empty_totals() -> Dictionary:
	return {
		"asteroids": 0,
		"enemies": 0,
		"shots": 0,
		"supers": 0,
		"super_level": 0,
		"guns_level": 0,
		"drone_level": 0,
	}


static func mode_for_kind(kind: String) -> String:
	return ENDLESS if kind == "level" else CLASSIC


static func kind_for_mode(mode: String) -> String:
	return "level" if mode == ENDLESS else "wave"


static func tab_for_mode(mode: String) -> String:
	return "Endless" if mode == ENDLESS else "Classic"


static func mode_for_tab(tab_name: String) -> String:
	return ENDLESS if tab_name == "Endless" else CLASSIC


static func save_run(new_kind: String, new_stages: Array, new_totals: Dictionary) -> void:
	_ensure_loaded()
	_store(mode_for_kind(new_kind), new_stages, new_totals, true)
	_write()


static func clear(mode: String) -> void:
	_ensure_loaded()
	_store(mode, [], empty_totals(), false)
	_write()


static func snapshot(mode: String) -> Dictionary:
	_ensure_loaded()
	if mode == ENDLESS:
		return {
			"kind": "level",
			"stages": endless_stages.duplicate(true),
			"totals": endless_totals.duplicate(true),
		}
	return {
		"kind": "wave",
		"stages": classic_stages.duplicate(true),
		"totals": classic_totals.duplicate(true),
	}


static func load_run() -> void:
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(Main.SAVE_PATH) != OK:
		return
	last = str(cf.get_value("stats", "last", CLASSIC))
	if last != ENDLESS:
		last = CLASSIC
	var classic := _read_pack(cf, CLASSIC)
	var endless := _read_pack(cf, ENDLESS)
	classic_stages = classic["stages"]
	classic_totals = classic["totals"]
	endless_stages = endless["stages"]
	endless_totals = endless["totals"]
	if str(classic_stages) == str(endless_stages):
		var recovered_classic := _stages_from_file(CLASSIC)
		var recovered_endless := _stages_from_file(ENDLESS)
		if not recovered_classic.is_empty() or not recovered_endless.is_empty():
			if str(recovered_classic) != str(recovered_endless):
				classic_stages = recovered_classic
				endless_stages = recovered_endless
	if not cf.has_section_key("stats", "classic_json"):
		_write()


static func format_duration(seconds: float) -> String:
	seconds = maxf(seconds, 0.0)
	if seconds < 60.0:
		return "%.2f seconds" % seconds
	var mins := int(seconds / 60.0)
	var rem := seconds - float(mins) * 60.0
	var secs := int(rem)
	var cs := int(round((rem - float(secs)) * 100.0))
	if cs >= 100:
		cs -= 100
		secs += 1
	if secs >= 60:
		secs -= 60
		mins += 1
	return "%d.%02d.%02d minutes" % [mins, secs, cs]


static func _ensure_loaded() -> void:
	if not _loaded:
		load_run()


static func _store(mode: String, new_stages: Array, new_totals: Dictionary, set_last: bool) -> void:
	if mode == ENDLESS:
		endless_stages = new_stages.duplicate(true)
		endless_totals = new_totals.duplicate(true)
	else:
		classic_stages = new_stages.duplicate(true)
		classic_totals = new_totals.duplicate(true)
	if set_last:
		last = mode


static func _read_pack(cf: ConfigFile, mode: String) -> Dictionary:
	var json_key := "%s_json" % mode
	if cf.has_section_key("stats", json_key):
		var parsed = JSON.parse_string(str(cf.get_value("stats", json_key, "")))
		if parsed is Dictionary:
			return {
				"stages": _as_stages(parsed.get("stages", [])),
				"totals": _as_totals(parsed.get("totals", {})),
			}
	return {
		"stages": _read_stages(cf, "%s_stages" % mode),
		"totals": _read_totals(cf, "%s_totals" % mode),
	}


static func _as_stages(stored) -> Array:
	var stages: Array = []
	if stored is Array:
		for row in stored:
			if row is Dictionary:
				stages.append((row as Dictionary).duplicate(true))
	return stages


static func _as_totals(saved) -> Dictionary:
	var totals := empty_totals()
	if saved is Dictionary:
		for item in totals.keys():
			totals[item] = int(saved.get(item, 0))
	return totals


static func _read_stages(cf: ConfigFile, key: String) -> Array:
	return _as_stages(cf.get_value("stats", key, []))


static func _read_totals(cf: ConfigFile, key: String) -> Dictionary:
	return _as_totals(cf.get_value("stats", key, {}))


static func _stages_from_file(mode: String) -> Array:
	if not FileAccess.file_exists(Main.SAVE_PATH):
		return []
	var text := FileAccess.get_file_as_string(Main.SAVE_PATH)
	var token := "%s_stages=" % mode
	var start := text.find(token)
	if start < 0:
		return []
	start += token.length()
	var finish := text.find("\n%s_totals=" % mode, start)
	if finish < 0:
		finish = text.find("\n", start)
	if finish < 0:
		finish = text.length()
	var parsed = JSON.parse_string(text.substr(start, finish - start).strip_edges())
	return _as_stages(parsed)


static func _write() -> void:
	var cf := ConfigFile.new()
	cf.load(Main.SAVE_PATH)
	cf.set_value("stats", "last", last)
	cf.set_value("stats", "classic_json", JSON.stringify({
		"stages": classic_stages,
		"totals": classic_totals,
	}))
	cf.set_value("stats", "endless_json", JSON.stringify({
		"stages": endless_stages,
		"totals": endless_totals,
	}))
	for key in ["kind", "stages", "totals", "times", "classic_stages", "classic_totals", "endless_stages", "endless_totals"]:
		if cf.has_section_key("stats", key):
			cf.erase_section_key("stats", key)
	cf.save(Main.SAVE_PATH)
