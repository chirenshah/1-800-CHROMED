extends RefCounted
class_name FinancialLedger
## Company cash, daily sales revenue, payroll accounting, transaction history, and write-ups.

const WRITEUPS_TO_TERMINATE := 3
const STARTING_CASH := 500

var company_cash := STARTING_CASH
var daily_sales_revenue := 0
var daily_sales_goal := 0
var day_opening_cash := STARTING_CASH
var day_cash_effect_net := 0
var current_day := 1
var upkeep_debt := 0
var writeups := 0
var settlements: Dictionary = {}
var transactions: Array[Dictionary] = []
var _next_transaction_id := 1


func reset_daily_revenue(day: int, sales_goal: int) -> void:
	current_day = maxi(day, 1)
	daily_sales_revenue = 0
	daily_sales_goal = maxi(sales_goal, 0)
	day_cash_effect_net = 0


func begin_workday() -> void:
	day_opening_cash = company_cash


func settle_sale(
		employee_id: String,
		amount: int,
		timestamp: float,
		source_augment_id: String = "",
		event_id: int = 0
	) -> Dictionary:
	var settled_amount := maxi(amount, 0)
	daily_sales_revenue += settled_amount
	var transaction := _record_transaction({
		"type": "sale",
		"source_employee_id": employee_id,
		"source_augment_id": source_augment_id,
		"event_id": event_id,
		"timestamp": timestamp,
		"requested_amount": settled_amount,
		"applied_amount": settled_amount,
		"ledger": ["daily_sales_revenue"],
		"daily_sales_revenue_delta": settled_amount,
		"sales_cash_credit": 0,
		"company_cash_delta": 0,
	})
	return transaction


func apply_augment_cash_effect(
		action: String,
		requested_amount: int,
		employee_id: String,
		augment_id: String,
		timestamp: float,
		event_id: int
	) -> Dictionary:
	assert(action in ["grant", "penalty", "spend"], "Unknown cash-effect action: " + action)
	return _change_cash(
		action, requested_amount, "augment_effect", employee_id, augment_id, timestamp, event_id
	)


func spend_cash(amount: int, source_type: String, source_id: String) -> bool:
	var requested := maxi(amount, 0)
	if company_cash < requested:
		return false
	var result := _change_cash(
		"spend", requested, source_type, "", source_id, 0.0, 0
	)
	return int(result["applied_amount"]) == requested


func _change_cash(
		action: String,
		requested_amount: int,
		source_type: String,
		employee_id: String,
		source_id: String,
		timestamp: float,
		event_id: int
	) -> Dictionary:
	var requested := maxi(requested_amount, 0)
	var applied := requested if action == "grant" else mini(company_cash, requested)
	var cash_delta := applied if action == "grant" else -applied
	company_cash += cash_delta
	if source_type == "augment_effect":
		day_cash_effect_net += cash_delta
	return _record_transaction({
		"type": source_type,
		"action": action,
		"source_employee_id": employee_id,
		"source_id": source_id,
		"source_augment_id": source_id if source_type == "augment_effect" else "",
		"event_id": event_id,
		"timestamp": timestamp,
		"requested_amount": requested,
		"applied_amount": applied,
		"ledger": ["company_cash"],
		"company_cash_delta": cash_delta,
	})


func _record_transaction(data: Dictionary) -> Dictionary:
	var transaction := data.duplicate(true)
	transaction["transaction_id"] = _next_transaction_id
	transaction["day"] = current_day
	_next_transaction_id += 1
	transactions.append(transaction)
	return transaction


func next_settlement_id() -> int:
	var latest := 0
	for settlement_id: Variant in settlements:
		latest = maxi(latest, int(settlement_id))
	return latest + 1


func settle(
		day: int,
		cash: int,
		gross_revenue: int,
		current_upkeep: int,
		goal_met: bool,
		active_upkeep: int,
		bench_upkeep: int,
		display_day: int = -1,
		timestamp: float = 0.0
) -> Dictionary:
	assert(day > 0, "Settlement day must be positive.")
	if settlements.has(day):
		return (settlements[day] as Dictionary).duplicate(true)

	var opening_cash := maxi(cash, 0)
	var revenue := maxi(gross_revenue, 0)
	var sales_cash_credit := maxi(revenue - daily_sales_goal, 0)
	var payroll := maxi(current_upkeep, 0)
	var debt_opening := maxi(upkeep_debt, 0)
	var available := opening_cash + sales_cash_credit
	var paid_current := mini(available, payroll)
	var current_shortfall := payroll - paid_current
	var cash_after_current := available - paid_current
	var paid_old_debt := mini(cash_after_current, debt_opening)
	var debt_closing := debt_opening - paid_old_debt + current_shortfall
	var cash_closing := cash_after_current - paid_old_debt
	var payroll_failed := current_shortfall > 0
	var reasons: Array[String] = []
	if not goal_met:
		reasons.append("revenue_goal_missed")
	if payroll_failed:
		reasons.append("current_upkeep_unpaid")
	var writeup_issued := not reasons.is_empty()

	upkeep_debt = debt_closing
	company_cash = cash_closing
	if writeup_issued:
		writeups += 1
	if sales_cash_credit > 0:
		_record_transaction({
			"type": "sales_surplus_credit",
			"source_employee_id": "",
			"source_augment_id": "",
			"event_id": 0,
			"timestamp": timestamp,
			"requested_amount": sales_cash_credit,
			"applied_amount": sales_cash_credit,
			"ledger": ["company_cash"],
			"company_cash_delta": sales_cash_credit,
		})
	_record_transaction({
		"type": "payroll_settlement",
		"source_employee_id": "",
		"source_augment_id": "",
		"event_id": 0,
		"timestamp": timestamp,
		"requested_amount": payroll + debt_opening,
		"applied_amount": paid_current + paid_old_debt,
		"ledger": ["company_cash", "upkeep_debt"],
		"company_cash_delta": cash_closing - available,
		"upkeep_debt_delta": debt_closing - debt_opening,
	})
	var result := {
		"day": display_day if display_day > 0 else day,
		"gross_revenue": revenue,
		"sales_goal": daily_sales_goal,
		"sales_cash_credited": maxi(revenue - daily_sales_goal, 0),
		"day_opening_cash": day_opening_cash,
		"augment_cash_effect_net": day_cash_effect_net,
		"current_upkeep": payroll,
		"active_upkeep": maxi(active_upkeep, 0),
		"bench_upkeep": maxi(bench_upkeep, 0),
		"opening_cash": opening_cash,
		"available_funds": available,
		"cash_before_payroll": available,
		"debt_brought_forward": debt_opening,
		"paid_current_upkeep": paid_current,
		"current_upkeep_shortfall": current_shortfall,
		"paid_old_debt": paid_old_debt,
		"debt_remaining": debt_closing,
		"ending_cash": cash_closing,
		"goal_met": goal_met,
		"payroll_met": not payroll_failed,
		"failure_reasons": reasons,
		"writeup_issued": writeup_issued,
		"total_writeups": writeups,
		"terminated": writeups >= WRITEUPS_TO_TERMINATE,
	}
	settlements[day] = result.duplicate(true)
	return result


func to_dict() -> Dictionary:
	return {
		"company_cash": maxi(company_cash, 0),
		"daily_sales_revenue": maxi(daily_sales_revenue, 0),
		"daily_sales_goal": maxi(daily_sales_goal, 0),
		"day_opening_cash": maxi(day_opening_cash, 0),
		"day_cash_effect_net": day_cash_effect_net,
		"current_day": maxi(current_day, 1),
		"upkeep_debt": maxi(upkeep_debt, 0),
		"writeups": maxi(writeups, 0),
		"settlements": settlements.duplicate(true),
		"transactions": transactions.duplicate(true),
		"next_transaction_id": _next_transaction_id,
	}


func load_dict(data: Dictionary) -> bool:
	var saved_settlements: Variant = data.get("settlements", {})
	if not saved_settlements is Dictionary:
		return false
	var saved_transactions: Variant = data.get("transactions", [])
	if not saved_transactions is Array:
		return false
	var restored: Dictionary = (saved_settlements as Dictionary).duplicate(true)
	for day: Variant in restored:
		if int(day) <= 0 or not restored[day] is Dictionary:
			return false
	var restored_transactions: Array = (saved_transactions as Array).duplicate(true)
	for transaction: Variant in restored_transactions:
		if not transaction is Dictionary:
			return false
	company_cash = maxi(int(data.get("company_cash", STARTING_CASH)), 0)
	daily_sales_revenue = maxi(int(data.get("daily_sales_revenue", 0)), 0)
	daily_sales_goal = maxi(int(data.get("daily_sales_goal", 0)), 0)
	day_opening_cash = maxi(int(data.get("day_opening_cash", company_cash)), 0)
	day_cash_effect_net = int(data.get("day_cash_effect_net", 0))
	current_day = maxi(int(data.get("current_day", 1)), 1)
	upkeep_debt = maxi(int(data.get("upkeep_debt", 0)), 0)
	writeups = maxi(int(data.get("writeups", 0)), 0)
	settlements = restored
	transactions.assign(restored_transactions)
	_next_transaction_id = maxi(
		int(data.get("next_transaction_id", transactions.size() + 1)), transactions.size() + 1
	)
	return true
