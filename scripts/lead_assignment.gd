extends RefCounted
class_name LeadAssignment
## Pure routing policy: opportunity follows the slot, never the employee profile.


static func next_available_seat(employees: Array[String], active: Dictionary) -> int:
	for seat in employees.size():
		if not employees[seat].is_empty() and not active.has(seat):
			return seat
	return -1
