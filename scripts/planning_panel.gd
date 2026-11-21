extends PanelContainer
class_name PlanningPanel

signal augment_equip_requested(employee_id: String, inventory_index: int)
signal augment_replace_requested(employee_id: String, slot_index: int, inventory_slot: int)
signal augment_discard_requested(inventory_slot: int)
signal surgery_requested(employee_id: String)
signal fire_requested(employee_id: String)
signal return_reward_requested

@onready var summary_label: Label = $Margin/Content/Header/Summary
@onready var financial_label: Label = $Margin/Content/Views/Team/TeamContent/FinancialSummary
@onready var views: TabContainer = $Margin/Content/Views
@onready var reward_banner: Label = $Margin/Content/RewardBanner
@onready var return_reward_button: Button = $Margin/Content/ReturnRewardButton
@onready var seat_label: Label = $Margin/Content/Views/Team/TeamContent/SeatLabel
@onready var candidate_selector: OptionButton = $Margin/Content/Views/Details/DetailContent/CandidateSelector
@onready var location_label: Label = $Margin/Content/Views/Team/TeamContent/Location
@onready var detail_scroll: ScrollContainer = $Margin/Content/Views/Details
@onready var strength_label: Label = $Margin/Content/Views/Details/DetailContent/Strength
@onready var tradeoff_label: Label = $Margin/Content/Views/Details/DetailContent/Tradeoff
@onready var profile_label: Label = $Margin/Content/Views/Team/TeamContent/Profiles
@onready var hint_label: Label = $Margin/Content/Views/Details/DetailContent/Hint
@onready var details_title: Label = $Margin/Content/Views/Details/DetailContent/DetailsTitle
@onready var more_stats: Label = $Margin/Content/Views/Details/DetailContent/MoreStats
@onready var budget_label: Label = $Margin/Content/Views/Upgrades/UpgradeContent/Budget
@onready var equipment_label: Label = $Margin/Content/Views/Upgrades/UpgradeContent/Equipment
@onready var inventory_selector: OptionButton = $Margin/Content/Views/Upgrades/UpgradeContent/InventoryRow/Inventory
@onready var equip_button: Button = $Margin/Content/Views/Upgrades/UpgradeContent/InventoryRow/EquipButton
@onready var unequip_buttons: Array[Button] = [
	$Margin/Content/Views/Upgrades/UpgradeContent/Unequip1,
	$Margin/Content/Views/Upgrades/UpgradeContent/Unequip2,
]
@onready var discard_button: Button = $Margin/Content/Views/Upgrades/UpgradeContent/DiscardButton
@onready var surgery_button: Button = $Margin/Content/Views/Upgrades/UpgradeContent/SurgeryButton
@onready var fire_button: Button = $Margin/Content/Views/Details/DetailContent/FireButton

var selected_seat := 0
var candidate_id := "nina"
var _plan: FloorPlan
var _augment_manager: AugmentManager
var _augment_editable := false
var _financial_summary := ""


func _ready() -> void:
	candidate_selector.get_popup().max_size = Vector2i(0, 320)
	candidate_selector.item_selected.connect(_on_candidate_selected)
	equip_button.pressed.connect(_equip_selected)
	for slot_index in unequip_buttons.size():
		unequip_buttons[slot_index].pressed.connect(_on_replace_pressed.bind(slot_index))
	discard_button.pressed.connect(_discard_selected)
	surgery_button.pressed.connect(func() -> void: surgery_requested.emit(candidate_id))
	fire_button.pressed.connect(func() -> void: fire_requested.emit(candidate_id))
	return_reward_button.pressed.connect(func() -> void: return_reward_requested.emit())


func set_pending_reward_management(pending: bool) -> void:
	reward_banner.visible = pending
	return_reward_button.visible = pending


func show_plan(plan: FloorPlan, seat: int, select_occupant := false) -> void:
	_plan = plan
	selected_seat = seat
	if select_occupant and not plan.seats[seat].is_empty():
		candidate_id = plan.seats[seat]
	summary_label.text = "%d / 9 seated" % plan.occupied_seats().size()
	var occupant := plan.profile(plan.seats[seat])
	seat_label.text = "Seat %02d · %s" % [seat + 1, occupant.get("name", "Open seat")]
	candidate_selector.clear()
	for index in plan.roster.size():
		var employee := plan.roster[index]
		var suffix := " · DEPARTED" if _is_fired(employee["id"]) else ""
		candidate_selector.add_item("%s · %s · $%d/day%s" % [
			employee["name"], employee["archetype"], FloorPlan.CATALOG.daily_upkeep(employee["id"]), suffix
		])
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


func show_financial_state(
		cash: int,
		daily_sales_revenue: int,
		debt: int,
		active_upkeep: int,
		bench_upkeep: int
	) -> void:
	var total_upkeep := active_upkeep + bench_upkeep
	var risk := "CASH COVERS PROJECTED PAYROLL" if cash >= total_upkeep else "SALES NEEDED TO COVER PAYROLL"
	if debt > 0:
		risk = "UPKEEP DEBT CARRIED" if cash >= total_upkeep else "HIGH RISK · DEBT + PAYROLL SHORTFALL"
	_financial_summary = "CASH $%d · TODAY SALES $%d · DEBT $%d\nUPKEEP $%d/day (FLOOR $%d · BENCH $%d) · %s" % [
		cash, daily_sales_revenue, debt, total_upkeep, active_upkeep, bench_upkeep, risk
	]
	financial_label.text = _financial_summary


func _is_fired(employee_id: String) -> bool:
	return _augment_manager != null and _augment_manager.bag.fired_employee_ids.has(employee_id)


func _on_candidate_selected(index: int) -> void:
	candidate_id = candidate_selector.get_item_metadata(index)
	detail_scroll.scroll_vertical = 0
	_show_candidate()


func _show_candidate() -> void:
	var show_seat_stats := _plan.seats[selected_seat] == candidate_id
	profile_label.visible = show_seat_stats
	location_label.visible = show_seat_stats
	var candidate := _plan.profile(candidate_id)
	if candidate.is_empty():
		return
	candidate_selector.tooltip_text = candidate["purpose"]
	details_title.text = "%s · %s" % [candidate["name"], candidate["archetype"]]
	strength_label.text = candidate["strength"]
	tradeoff_label.text = candidate["tradeoff"]
	more_stats.text = "Upsell %d%% · Payout ×%.1f · Upkeep $%d/day" % [
		candidate["upsell_chance"], candidate["upsell_multiplier"], FloorPlan.CATALOG.daily_upkeep(candidate_id)
	]
	var effective_stats := _augment_manager.modified_stats(candidate_id) if _augment_manager != null else {
		"speed": float(candidate.get("speed", 0.0)),
		"conversion": float(candidate.get("conversion", 0.0)),
		"upsell_chance": float(candidate.get("upsell_chance", 0.0)),
		"upsell_multiplier": float(candidate.get("upsell_multiplier", 1.0)),
	}
	var speed := float(effective_stats.get("speed", 0.0))
	var effective_handling := INF if speed <= 0.0 else EmployeeRoster.BASE_HANDLING_SECONDS / speed
	profile_label.text = "Close %.0f%% · Speed %.2f · Talk %s · Stamina %.0fh" % [
		float(effective_stats.get("conversion", 0.0)), speed,
		"Paused" if speed <= 0.0 else EmployeeRoster.format_game_duration(effective_handling),
		float(candidate.get("stamina_hours", EmployeeRoster.DEFAULT_STAMINA_HOURS)),
	]
	more_stats.text = "Upsell %.1f%% · Payout ×%.2f · Upkeep $%.0f/day" % [
		float(effective_stats.get("upsell_chance", 0.0)),
		float(effective_stats.get("upsell_multiplier", 1.0)),
		float(effective_stats.get("daily_upkeep", FloorPlan.CATALOG.daily_upkeep(candidate_id))),
	]
	profile_label.tooltip_text = "Stats include installed augment effects. Conversion and upsell probability rolls clamp to 0–100%."
	if FloorPlan.CATALOG.is_recycler(candidate_id):
		profile_label.tooltip_text += " Scrap attempts one recovery for each discarded lead."
	else:
		profile_label.tooltip_text += " Other special abilities are previews."
	hint_label.text = candidate["planning_hint"]
	var source := _plan.seats.find(candidate_id)
	var bag: InventoryManager = _augment_manager.bag if _augment_manager != null else null
	var reserve_slot := -1 if bag == null else bag.person_slots.find(candidate_id)
	var fired := _is_fired(candidate_id)
	var owned := bag != null and (source != -1 or reserve_slot != -1)
	if fired:
		location_label.text = "DEPARTED  /  Permanently unavailable this run"
	elif source != -1:
		location_label.text = "CURRENTLY IN SEAT %02d" % (source + 1)
	elif owned:
		location_label.text = "IN RESERVE  /  Ready to deploy"
	else:
		location_label.text = "NOT HIRED  /  $%d to hire into reserve" % AugmentManager.HIRE_COST
	fire_button.visible = owned and not fired
	fire_button.disabled = not _augment_editable or not owned or fired
	fire_button.text = "Fire %s permanently" % candidate["name"]
	_refresh_augment_controls()


func _equip_selected() -> void:
	if inventory_selector.selected < 0:
		return
	var inventory_slot: int = inventory_selector.get_item_metadata(inventory_selector.selected)
	augment_equip_requested.emit(candidate_id, inventory_slot)


func _on_unequip_pressed(slot_index: int) -> void:
	if inventory_selector.selected < 0:
		return
	var inventory_slot: int = inventory_selector.get_item_metadata(inventory_selector.selected)
	augment_replace_requested.emit(candidate_id, slot_index, inventory_slot)


func _on_replace_pressed(slot_index: int) -> void:
	_on_unequip_pressed(slot_index)


func _discard_selected() -> void:
	if inventory_selector.selected < 0:
		return
	augment_discard_requested.emit(inventory_selector.get_item_metadata(inventory_selector.selected))


func _refresh_augment_controls() -> void:
	if _augment_manager == null:
		return
	budget_label.text = "COMPANY CASH  $%d · AUGMENT INVENTORY  %d/%d" % [
		_augment_manager.budget, _augment_manager.bag.item_count(), InventoryManager.ITEM_SLOTS,
	]

	inventory_selector.clear()
	var inventory_option := 0
	for slot_index in _augment_manager.bag.item_slots.size():
		var item: Dictionary = _augment_manager.bag.item_slots[slot_index]
		if item.is_empty():
			continue
		var augment := AugmentManager.CATALOG.profile(item["augment_id"])
		inventory_selector.add_item("%s · %s" % [augment["name"], _augment_effect_text(augment)])
		inventory_selector.set_item_metadata(inventory_option, slot_index)
		inventory_option += 1
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
		button.disabled = not _augment_editable or slot_index >= loadout.size() \
			or _augment_manager.inventory.is_empty() or not _augment_manager.bag.owns(candidate_id)
		button.text = "Replace slot %d (old augment destroyed)" % (slot_index + 1)
		if slot_index < loadout.size():
			var augment := AugmentManager.CATALOG.profile(loadout[slot_index])
			button.text = "Replace %d: %s" % [slot_index + 1, augment["name"]]
	equip_button.disabled = not _augment_editable or _augment_manager.inventory.is_empty() or loadout.size() >= slot_limit or not _augment_manager.bag.owns(candidate_id)
	discard_button.disabled = not _augment_editable or _augment_manager.inventory.is_empty()
	surgery_button.visible = slot_limit == 1
	surgery_button.disabled = not _augment_editable or not _augment_manager.bag.owns(candidate_id) \
		or _is_fired(candidate_id) or _augment_manager.budget < AugmentManager.SURGERY_COST
	surgery_button.text = "Unlock second slot — $%d" % AugmentManager.SURGERY_COST


func _augment_effect_text(augment: Dictionary) -> String:
	if augment.has("stat") and augment.has("bonus"):
		return "+%d pp CNV" % int(augment["bonus"]) if augment["stat"] == "conversion" else "+%d%% Speed" % int(augment["bonus"])
	return str(augment.get("description", "Rule-changing effect"))
