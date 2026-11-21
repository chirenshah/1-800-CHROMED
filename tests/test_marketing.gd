extends SceneTree

const MODEL := preload("res://scripts/call_queue_simulation.gd")
const MARKETING := preload("res://scripts/marketing_panel.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var model := MODEL.new()
	model.reset([], 41, {}, MARKETING.campaign_plan("cold_list", 0))
	model.advance(36.0)
	_check(model.received == 0, "A zero-lead order must produce no calls.")
	model.reset([], 41, {}, MARKETING.campaign_plan("inquiries", 17, 12.0))
	model.advance(12.0)
	_check(model.received == 17, "All purchased leads must arrive within the configured shift.")
	model.advance(12.0)
	_check(model.received == 17, "The source must stop producing leads once the order is delivered.")
	_check(model.abandoned + model.waiting.size() == 17, "Every purchased lead must remain accounted for.")
	_check(MARKETING.campaign_cost("referrals", 5) == 150, "Lead spend must match source price and quantity.")
	_check(MARKETING.campaign_cost("cold_list", -1) == 0, "Negative requested quantities must clamp to zero.")
	model.reset(["nina"], 41, {}, MARKETING.campaign_plan("referrals", 1))
	model.advance(35.0)
	_check(model.received == 1, "A one-lead order must arrive.")
	_check(model._makes_sale("nina", {"conversion_bonus": 100.0}, {"conversion": 0.0}),
		"Source conversion adjustments must participate in actual conversion rolls.")
	var first := MODEL.new()
	var second := MODEL.new()
	first.reset(["nina"], 90, {}, MARKETING.campaign_plan("inquiries", 12))
	second.reset(["nina"], 90, {}, MARKETING.campaign_plan("inquiries", 12))
	first.advance(36.0)
	second.advance(36.0)
	_check(first.sale_log == second.sale_log and first.abandoned == second.abandoned,
		"Finite campaigns must remain repeatable under the same arrival seed.")
	var panel := MARKETING.new()
	root.add_child(panel)
	await process_frame
	panel.show_plan("referrals", 6, 500)
	_check(panel.source_selector.selected == 2 and int(panel.quantity_input.value) == 6,
		"Marketing controls must show persisted campaign choices.")
	_check(panel.summary_label.text.contains("$180"), "Marketing must display acquisition spend.")
	panel.queue_free()
	if failures.is_empty():
		print("PASS: finite Marketing campaigns, zero leads, seeded results, conversion adjustments, and planning controls.")
	quit(0 if failures.is_empty() else 1)
