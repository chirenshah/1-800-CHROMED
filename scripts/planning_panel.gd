extends PanelContainer
class_name PlanningPanel

signal assignment_requested(seat: int, employee_id: String)
signal bench_requested(seat: int)

@onready var summary_label: Label = $Margin/Content/Header/Summary
@onready var seat_label: Label = $Margin/Content/SeatLabel
@onready var candidate_selector: OptionButton = $Margin/Content/CandidateSelector
@onready var location_label: Label = $Margin/Content/Location
@onready var detail_scroll: ScrollContainer = $Margin/Content/DetailScroll
@onready var strength_label: Label = $Margin/Content/DetailScroll/Details/Strength
@onready var tradeoff_label: Label = $Margin/Content/DetailScroll/Details/Tradeoff
@onready var profile_label: Label = $Margin/Content/Profiles
@onready var hint_label: Label = $Margin/Content/DetailScroll/Details/Hint
@onready var assign_button: Button = $Margin/Content/AssignButton
@onready var bench_button: Button = $Margin/Content/BenchButton

var selected_seat := 0
var candidate_id := "nina"
var _plan: FloorPlan


func _ready() -> void:
	candidate_selector.get_popup().max_size = Vector2i(0, 320)
	candidate_selector.item_selected.connect(_on_candidate_selected)
	assign_button.pressed.connect(func() -> void: assignment_requested.emit(selected_seat, candidate_id))
	bench_button.pressed.connect(func() -> void: bench_requested.emit(selected_seat))


func show_plan(plan: FloorPlan, seat: int, select_occupant := false) -> void:
	_plan = plan
	selected_seat = seat
	if select_occupant and not plan.seats[seat].is_empty():
		candidate_id = plan.seats[seat]
	summary_label.text = "%d / 9 seated" % plan.occupied_seats().size()
	var occupant := plan.profile(plan.seats[seat])
	seat_label.text = "SEAT %02d  /  %s" % [seat + 1, occupant.get("name", "Unassigned")]
	candidate_selector.clear()
	for index in plan.roster.size():
		var employee := plan.roster[index]
		candidate_selector.add_item("%s · %s" % [employee["name"], employee["archetype"]])
		candidate_selector.set_item_metadata(index, employee["id"])
		if employee["id"] == candidate_id:
			candidate_selector.select(index)
	_show_candidate()


func _on_candidate_selected(index: int) -> void:
	candidate_id = candidate_selector.get_item_metadata(index)
	detail_scroll.scroll_vertical = 0
	_show_candidate()


func _show_candidate() -> void:
	var candidate := _plan.profile(candidate_id)
	if candidate.is_empty():
		return
	candidate_selector.tooltip_text = candidate["purpose"]
	strength_label.text = candidate["strength"]
	tradeoff_label.text = candidate["tradeoff"]
	profile_label.text = "Speed: %d/5 · Conversion: %d%%" % [candidate["speed"], candidate["conversion"]]
	profile_label.tooltip_text = "Higher Speed means shorter calls: %.1f seconds per interaction. Conversion is the chance of a sale when a call finishes. Special abilities are previews." % FloorPlan.CATALOG.handling_seconds(candidate_id)
	hint_label.text = candidate["planning_hint"]
	var source := _plan.seats.find(candidate_id)
	location_label.text = "ON BENCH  /  Available to assign" if source == -1 else "CURRENTLY IN SEAT %02d" % (source + 1)
	assign_button.disabled = source == selected_seat
	if source == selected_seat:
		assign_button.text = "Already in this seat"
	elif source != -1:
		assign_button.text = "%s Seat %02d → %02d" % ["Move" if _plan.seats[selected_seat].is_empty() else "Swap", source + 1, selected_seat + 1]
	else:
		var current := _plan.profile(_plan.seats[selected_seat])
		assign_button.text = "Assign %s to Seat %02d" % [candidate["name"], selected_seat + 1] if current.is_empty() else "Replace %s with %s" % [current["name"], candidate["name"]]
	var occupant := _plan.profile(_plan.seats[selected_seat])
	bench_button.disabled = occupant.is_empty()
	bench_button.text = "Seat already empty" if occupant.is_empty() else "Bench " + str(occupant["name"])
	assign_button.tooltip_text = "A seated colleague swaps with this seat. Assigning from the bench replaces its occupant."
