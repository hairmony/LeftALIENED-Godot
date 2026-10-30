class_name RunStats
extends RefCounted

const CLASSIC: String = "classic"
const ENDLESS: String = "endless"

static var last: String = CLASSIC
static var classic_stages: Array = []
static var classic_totals: Dictionary = {}
static var endless_stages: Array = []
static var endless_totals: Dictionary = {}


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
	_store(mode_for_kind(new_kind), new_stages, new_totals, true)
	_write()


static func clear(mode: String) -> void:
	_store(mode, [], empty_totals(), false)
	_write()


static func snapshot(mode: String) -> Dictionary:
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
	var cf := ConfigFile.new()
	if cf.load(Main.SAVE_PATH) != OK:
		return
	var has_split := cf.has_section_key("stats", "classic_stages") or cf.has_section_key("stats", "endless_stages")
	if has_split:
		classic_stages = _read_stages(cf, "classic_stages")
		classic_totals = _read_totals(cf, "classic_totals")
		endless_stages = _read_stages(cf, "endless_stages")
		endless_totals = _read_totals(cf, "endless_totals")
		last = str(cf.get_value("stats", "last", CLASSIC))
		if last != ENDLESS:
			last = CLASSIC
		return
	var old_kind := str(cf.get_value("stats", "kind", "wave"))
	var old_stages := _read_stages(cf, "stages")
	if old_stages.is_empty() and not cf.has_section_key("stats", "stages"):
		var old_times = cf.get_value("stats", "times", [])
		if old_times is Array or old_times is PackedFloat32Array:
			for t in old_times:
				var row := empty_totals()
				row["time"] = float(t)
				old_stages.append(row)
	var old_totals := _read_totals(cf, "totals")
	_store(mode_for_kind(old_kind), old_stages, old_totals, true)


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


static func _store(mode: String, new_stages: Array, new_totals: Dictionary, set_last: bool) -> void:
	if mode == ENDLESS:
		endless_stages = new_stages.duplicate(true)
		endless_totals = new_totals.duplicate(true)
	else:
		classic_stages = new_stages.duplicate(true)
		classic_totals = new_totals.duplicate(true)
	if set_last:
		last = mode


static func _read_stages(cf: ConfigFile, key: String) -> Array:
	var stages: Array = []
	var stored = cf.get_value("stats", key, [])
	if stored is Array:
		for row in stored:
			if row is Dictionary:
				stages.append((row as Dictionary).duplicate(true))
	return stages


static func _read_totals(cf: ConfigFile, key: String) -> Dictionary:
	var totals := empty_totals()
	var saved = cf.get_value("stats", key, {})
	if saved is Dictionary:
		for item in totals.keys():
			totals[item] = int(saved.get(item, 0))
	return totals


static func _write() -> void:
	var cf := ConfigFile.new()
	cf.load(Main.SAVE_PATH)
	cf.set_value("stats", "last", last)
	cf.set_value("stats", "classic_stages", classic_stages)
	cf.set_value("stats", "classic_totals", classic_totals)
	cf.set_value("stats", "endless_stages", endless_stages)
	cf.set_value("stats", "endless_totals", endless_totals)
	for key in ["kind", "stages", "totals", "times"]:
		if cf.has_section_key("stats", key):
			cf.erase_section_key("stats", key)
	cf.save(Main.SAVE_PATH)
