extends PanelContainer
class_name PlanningPanel

signal assignment_requested(seat: int, employee_id: String)
signal bench_requested(seat: int)
signal augment_purchase_requested(offer_index: int)
signal augment_equip_requested(employee_id: String, inventory_index: int)
signal augment_unequip_requested(employee_id: String, slot_index: int)
signal surgery_requested(employee_id: String)

@onready var summary_label: Label = $Margin/Content/Header/Summary
@onready var score_target_label: Label = $Margin/Content/Scoreboard/ScoreTarget
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
@onready var budget_label: Label = $Margin/Content/DetailScroll/Details/Budget
@onready var offer_buttons: Array[Button] = [
	$Margin/Content/DetailScroll/Details/Offer1,
	$Margin/Content/DetailScroll/Details/Offer2,
	$Margin/Content/DetailScroll/Details/Offer3,
]
@onready var equipment_label: Label = $Margin/Content/DetailScroll/Details/Equipment
@onready var inventory_selector: OptionButton = $Margin/Content/DetailScroll/Details/InventoryRow/Inventory
@onready var equip_button: Button = $Margin/Content/DetailScroll/Details/InventoryRow/EquipButton
@onready var unequip_buttons: Array[Button] = [
	$Margin/Content/DetailScroll/Details/Unequip1,
	$Margin/Content/DetailScroll/Details/Unequip2,
]
@onready var surgery_button: Button = $Margin/Content/DetailScroll/Details/SurgeryButton

var selected_seat := 0
var candidate_id := "nina"
var _plan: FloorPlan
var _augment_manager: AugmentManager
var _augment_editable := false


func _ready() -> void:
	candidate_selector.get_popup().max_size = Vector2i(0, 320)
	candidate_selector.item_selected.connect(_on_candidate_selected)
	assign_button.pressed.connect(func() -> void: assignment_requested.emit(selected_seat, candidate_id))
	bench_button.pressed.connect(func() -> void: bench_requested.emit(selected_seat))
	for index in offer_buttons.size():
		offer_buttons[index].pressed.connect(_on_offer_pressed.bind(index))
	equip_button.pressed.connect(_equip_selected)
	for slot_index in unequip_buttons.size():
		unequip_buttons[slot_index].pressed.connect(_on_unequip_pressed.bind(slot_index))
	surgery_button.pressed.connect(func() -> void: surgery_requested.emit(candidate_id))


func show_score_target(day: int, target: int) -> void:
	score_target_label.text = "$%d" % target
	score_target_label.tooltip_text = "Reach $%d in revenue on Day %d to advance." % [target, day]


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


func update_augment_state(manager: AugmentManager, editable: bool) -> void:
	_augment_manager = manager
	_augment_editable = editable
	_refresh_augment_controls()
	if _plan != null:
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
	profile_label.text = "Speed: %d/5 · Conversion: %d%%\nUpsell: %d%% · Multiplier: ×%.1f" % [candidate["speed"], candidate["conversion"], candidate["upsell_chance"], candidate["upsell_multiplier"]]
	var effective_handling := FloorPlan.CATALOG.handling_seconds(candidate_id)
	if _augment_manager != null:
		var loadout := _augment_manager.loadout(candidate_id)
		if not loadout.is_empty():
			var effective_conversion := roundi(FloorPlan.CATALOG.conversion_chance_with_augments(candidate_id, loadout) * 100.0)
			effective_handling = FloorPlan.CATALOG.handling_seconds_with_augments(candidate_id, loadout)
			profile_label.text += "\nEffective: %d%% conversion · %.1fs/call" % [effective_conversion, effective_handling]
	profile_label.tooltip_text = "Effective handling: %.1f seconds per interaction. Conversion is the chance of a sale when an interaction finishes." % effective_handling
	if FloorPlan.CATALOG.is_recycler(candidate_id):
		profile_label.tooltip_text += " Scrap attempts one recovery for each discarded lead."
	else:
		profile_label.tooltip_text += " Other special abilities are previews."
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
	_refresh_augment_controls()


func _equip_selected() -> void:
	if inventory_selector.selected < 0:
		return
	var inventory_index: int = inventory_selector.get_item_metadata(inventory_selector.selected)
	augment_equip_requested.emit(candidate_id, inventory_index)


func _on_offer_pressed(offer_index: int) -> void:
	augment_purchase_requested.emit(offer_index)


func _on_unequip_pressed(slot_index: int) -> void:
	augment_unequip_requested.emit(candidate_id, slot_index)


func _refresh_augment_controls() -> void:
	if _augment_manager == null:
		return
	budget_label.text = "Department budget: $%d" % _augment_manager.budget
	for index in offer_buttons.size():
		var button := offer_buttons[index]
		if index >= _augment_manager.shop_offers.size():
			button.text = "No augment offer"
			button.disabled = true
			continue
		var augment_id: String = _augment_manager.shop_offers[index]
		var augment := AugmentManager.CATALOG.profile(augment_id)
		var effect := "+%d pp Conversion" % int(augment["bonus"]) if augment["stat"] == "conversion" else "+%d%% Speed" % int(augment["bonus"])
		button.text = "%s · %s\n%s · $%d" % [augment["name"], augment["rarity"], effect, augment["price"]]
		button.disabled = not _augment_editable or _augment_manager.purchased_offer_indexes.has(index) or _augment_manager.budget < int(augment["price"])
		if _augment_manager.purchased_offer_indexes.has(index):
			button.text += " · Purchased"

	inventory_selector.clear()
	for index in _augment_manager.inventory.size():
		var augment := AugmentManager.CATALOG.profile(_augment_manager.inventory[index])
		inventory_selector.add_item("%s · %s" % [augment["name"], _augment_effect_text(augment)])
		inventory_selector.set_item_metadata(index, index)
	if _augment_manager.inventory.is_empty():
		inventory_selector.add_item("Inventory empty")
		inventory_selector.set_item_disabled(0, true)
	else:
		inventory_selector.select(0)

	var loadout := _augment_manager.loadout(candidate_id)
	var slot_limit := _augment_manager.slot_limit(candidate_id)
	var employee_name := candidate_id
	if _plan != null:
		employee_name = _plan.profile(candidate_id).get("name", candidate_id)
	equipment_label.text = "%s · %d/%d slots used" % [
		employee_name, loadout.size(), slot_limit
	]
	for slot_index in unequip_buttons.size():
		var button := unequip_buttons[slot_index]
		button.visible = slot_index < slot_limit
		button.disabled = not _augment_editable or slot_index >= loadout.size()
		button.text = "Unequip slot %d" % (slot_index + 1)
		if slot_index < loadout.size():
			var augment := AugmentManager.CATALOG.profile(loadout[slot_index])
			button.text = "Unequip %d: %s" % [slot_index + 1, augment["name"]]
	equip_button.disabled = not _augment_editable or _augment_manager.inventory.is_empty() or loadout.size() >= slot_limit
	surgery_button.visible = slot_limit == 1
	surgery_button.disabled = not _augment_editable or _augment_manager.budget < AugmentManager.SURGERY_COST
	surgery_button.text = "Unlock second slot — $%d" % AugmentManager.SURGERY_COST


func _augment_effect_text(augment: Dictionary) -> String:
	return "+%d pp CNV" % int(augment["bonus"]) if augment["stat"] == "conversion" else "+%d%% Speed" % int(augment["bonus"])
