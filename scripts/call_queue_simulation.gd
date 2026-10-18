extends RefCounted
class_name CallQueueSimulation
## Small deterministic queue model for the floor prototype.
## No patience limits, qualification, transfers, or archetype abilities yet.

const HANDLING_TICKS := 4

var waiting: Array[Dictionary] = []
var active: Dictionary = {}
var staffed_seats: Array[int] = []
var elapsed_ticks := 0
var received := 0
var handled := 0
var sales := 0
var revenue := 0
var last_dispatch := ""


func reset(seats: Array[int]) -> void:
	waiting.clear()
	active.clear()
	staffed_seats.assign(seats)
	staffed_seats.sort()
	elapsed_ticks = 0
	received = 0
	handled = 0
	sales = 0
	revenue = 0
	last_dispatch = ""


func advance() -> void:
	elapsed_ticks += 1
	# Finish existing calls before assigning newly available employees.
	for seat in active.keys():
		var call: Dictionary = active[seat]
		call["remaining"] -= 1
		if call["remaining"] <= 0:
			handled += 1
			# Placeholder outcomes, shared by every employee regardless of role.
			if int(call["id"]) % 3 != 0:
				sales += 1
				revenue += int(call["value"])
			active.erase(seat)

	# Retain the starter's 2 / 3 / 1 arrival rhythm, now as individual calls.
	for arrival in range(1 + elapsed_ticks % 3):
		received += 1
		waiting.append({"id": received, "value": 180 + received * 15})

	# FIFO callers go to the first available occupied slot in fixed order.
	for seat in staffed_seats:
		if waiting.is_empty():
			break
		if active.has(seat):
			continue
		var call: Dictionary = waiting.pop_front()
		call["duration"] = HANDLING_TICKS
		call["remaining"] = HANDLING_TICKS
		active[seat] = call
		last_dispatch = "Call #%03d → Seat %02d" % [call["id"], seat + 1]
