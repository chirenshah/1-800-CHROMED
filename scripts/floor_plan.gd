extends RefCounted
class_name FloorPlan
## Session-local seating. Base stats are active; conditional traits are previews.

const CATALOG := preload("res://data/planning_roster.tres")
const SEAT_COUNT := 9

var roster: Array[Dictionary] = []
var seats: Array[String] = ["nina", "zip", "ada", "victoria", "dex", "marcus", "brick", "zero", "mox"]
var _profiles: Dictionary = {}


func _init() -> void:
	for entry: Dictionary in CATALOG.employees:
		roster.append(entry)
		_profiles[entry["id"]] = entry


func profile(employee_id: String) -> Dictionary:
	return _profiles.get(employee_id, {})


func assign(seat: int, employee_id: String) -> bool:
	if seat < 0 or seat >= SEAT_COUNT or not _profiles.has(employee_id):
		return false
	var previous := seats.find(employee_id)
	if previous == seat:
		return false
	# A seated colleague swaps places; a benched colleague replaces the occupant.
	if previous != -1:
		seats[previous] = seats[seat]
	seats[seat] = employee_id
	return true


func bench(seat: int) -> bool:
	if seat < 0 or seat >= SEAT_COUNT or seats[seat].is_empty():
		return false
	seats[seat] = ""
	return true


func occupied_seats() -> Array[int]:
	var occupied: Array[int] = []
	for seat in SEAT_COUNT:
		if not seats[seat].is_empty():
			occupied.append(seat)
	return occupied
