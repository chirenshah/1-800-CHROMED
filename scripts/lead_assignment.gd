extends RefCounted
class_name LeadAssignment
## Pure routing policy: opportunity follows the slot, never the employee profile.


## An optional eligibility filter lets a role restrict which seats may take a lead.
static func next_available_seat(employees: Array[String], active: Dictionary, eligible: Callable = Callable()) -> int:
	for seat in employees.size():
		if employees[seat].is_empty() or active.has(seat):
			continue
		if eligible.is_valid() and not eligible.call(employees[seat]):
			continue
		return seat
	return -1
