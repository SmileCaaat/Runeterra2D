extends Node

## Encounter-scoped combat meter data. Events are recorded after mitigation and
## shields so the UI reports effective damage/healing rather than attempted values.
signal updated

const WINDOW_SECONDS := 10.0
const MAX_EVENTS := 4000

var _events: Array[Dictionary] = []
var _buff_started: Dictionary = {}
var _buff_uptime: Dictionary = {}
var _started_at := 0.0


func _ready() -> void:
	_started_at = Time.get_ticks_msec() / 1000.0


func record_damage(source: Node, target: Node, amount: float, action: String, damage_type: StringName = &"physical") -> void:
	_record_event(&"damage", source, target, amount, action, damage_type)


func record_healing(source: Node, target: Node, amount: float, action: String = "治疗") -> void:
	_record_event(&"healing", source, target, amount, action, &"healing")


func record_buff(source: Node, target: Node, buff_id: StringName, active: bool) -> void:
	if source == null or target == null:
		return
	var key := "%d:%d:%s" % [source.get_instance_id(), target.get_instance_id(), String(buff_id)]
	var now := Time.get_ticks_msec() / 1000.0
	if active:
		if not _buff_started.has(key):
			_buff_started[key] = {"time": now, "source": weakref(source), "target": weakref(target), "buff": String(buff_id)}
	else:
		_close_buff(key, now)
	updated.emit()


func snapshot(mode: StringName, window_seconds := WINDOW_SECONDS) -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var rows: Dictionary = {}
	var window_start := now - maxf(window_seconds, 0.1)
	var effective_window := minf(maxf(now - _started_at, 0.1), maxf(window_seconds, 0.1))
	for event: Dictionary in _events:
		if event.kind != mode:
			continue
		var source: Node = event.source.get_ref() if event.source is WeakRef else null
		var source_id := int(event.source_id)
		if not rows.has(source_id):
			rows[source_id] = {"name": event.source_name, "team": event.team, "total": 0.0, "window": 0.0, "actions": {}, "events": 0}
		var row: Dictionary = rows[source_id]
		row.total = float(row.total) + float(event.amount)
		if event.time >= window_start:
			row.window = float(row.window) + float(event.amount)
		row.events = int(row.events) + 1
		var actions: Dictionary = row.actions
		actions[event.action] = float(actions.get(event.action, 0.0)) + float(event.amount)
		row.actions = actions
		row.source_valid = is_instance_valid(source)
	var result: Array[Dictionary] = []
	for row: Dictionary in rows.values():
		row["rate"] = float(row.window) / effective_window
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.rate) > float(b.rate))
	return {"rows": result, "elapsed": maxf(0.0, now - _started_at), "window": window_seconds}


func buff_uptime_snapshot() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var totals := _buff_uptime.duplicate(true)
	for entry: Dictionary in _buff_started.values():
		var source: Node = entry.source.get_ref() if entry.source is WeakRef else null
		var key := "%s:%s" % [entry.buff, _node_label(source)]
		totals[key] = float(totals.get(key, 0.0)) + now - float(entry.time)
	var result: Array[Dictionary] = []
	for key: String in totals:
		result.append({"name": key, "seconds": float(totals[key])})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.seconds) > float(b.seconds))
	return {"rows": result, "elapsed": maxf(0.0, now - _started_at)}


func reset_encounter() -> void:
	_events.clear()
	_buff_started.clear()
	_buff_uptime.clear()
	_started_at = Time.get_ticks_msec() / 1000.0
	updated.emit()


func _record_event(kind: StringName, source: Node, target: Node, amount: float, action: String, damage_type: StringName) -> void:
	if source == null or target == null or amount <= 0.0:
		return
	var team := String(source.get("team")) if _has_property(source, &"team") else "?"
	_events.append({
		"time": Time.get_ticks_msec() / 1000.0,
		"kind": kind,
		"source": weakref(source),
		"source_id": source.get_instance_id(),
		"source_name": _node_label(source),
		"team": team,
		"target": _node_label(target),
		"amount": amount,
		"action": action,
		"damage_type": damage_type,
	})
	while _events.size() > MAX_EVENTS:
		_events.pop_front()
	updated.emit()


func _close_buff(key: String, now: float) -> void:
	if not _buff_started.has(key):
		return
	var entry: Dictionary = _buff_started[key]
	var source: Node = entry.source.get_ref() if entry.source is WeakRef else null
	var uptime_key := "%s:%s" % [entry.buff, _node_label(source)]
	_buff_uptime[uptime_key] = float(_buff_uptime.get(uptime_key, 0.0)) + now - float(entry.time)
	_buff_started.erase(key)


func _node_label(node: Node) -> String:
	if not is_instance_valid(node):
		return "已离场单位"
	if node.has_method("get_display_name"):
		return String(node.call("get_display_name"))
	return String(node.get("display_name")) if _has_property(node, &"display_name") else String(node.name)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false
