extends RefCounted
class_name GridSelector

const COLUMNS := 3
const ROWS := 3
const SEAT_COUNT := COLUMNS * ROWS


static func select(selector: String, origin_seat: int, occupied_seats: Array[String]) -> Array[String]:
	var selected: Array[String] = []
	if origin_seat < 0 or origin_seat >= SEAT_COUNT:
		return selected
	var origin_row := floori(float(origin_seat) / COLUMNS)
	var origin_column := origin_seat % COLUMNS
	for seat in SEAT_COUNT:
		var employee_id := occupied_seats[seat] if seat < occupied_seats.size() else ""
		if employee_id.is_empty() or seat == origin_seat:
			continue
		var row := floori(float(seat) / COLUMNS)
		var column := seat % COLUMNS
		var matches := false
		match selector:
			"adjacent":
				matches = absi(row - origin_row) + absi(column - origin_column) == 1
			"diagonal":
				matches = absi(row - origin_row) == 1 and absi(column - origin_column) == 1
			"row":
				matches = row == origin_row
			"column":
				matches = column == origin_column
			"left":
				matches = row == origin_row and column < origin_column
			"right":
				matches = row == origin_row and column > origin_column
			"above":
				matches = column == origin_column and row < origin_row
			"below":
				matches = column == origin_column and row > origin_row
		if matches:
			selected.append(employee_id)
	return selected
