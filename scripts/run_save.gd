extends RefCounted
class_name RunSave

const SAVE_PATH := "user://quarter.save"
const SAVE_VERSION := 1
static var save_path := SAVE_PATH
static var session_active := false

# Set by the menu before changing to the workday scene; consumed exactly once.
static var pending_resume: Dictionary = {}


static func has_save() -> bool:
	return not RunSave.load().is_empty()


static func load() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = file.get_var(false)
	if not data is Dictionary or int(data.get("version", -1)) != SAVE_VERSION:
		return {}
	if int(data.get("day", 0)) < 1 or int(data.get("day", 0)) > 60 \
			or str(data.get("phase", "")) not in ["prepare", "report"]:
		return {}
	var saved_inventory: Variant = data.get("inventory", {})
	var saved_augments: Variant = data.get("augments", {})
	var saved_finance: Variant = data.get("finance", {})
	var saved_report: Variant = data.get("report", {})
	if not saved_inventory is Dictionary or not saved_augments is Dictionary \
			or not saved_finance is Dictionary or not saved_report is Dictionary:
		return {}
	if str(data["phase"]) == "report" and saved_report.is_empty():
		return {}
	var probe_inventory := InventoryManager.new()
	var probe_finance := FinancialLedger.new()
	var probe_augments := AugmentManager.new(probe_inventory)
	if not probe_inventory.load_dict(saved_inventory) or not probe_finance.load_dict(saved_finance) \
			or not probe_augments.load_state_dict(saved_augments):
		return {}
	if probe_augments.budget != probe_finance.company_cash:
		return {}
	return data


static func write(data: Dictionary) -> bool:
	var checkpoint := data.duplicate(true)
	checkpoint["version"] = SAVE_VERSION
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(checkpoint, false)
	file.flush()
	var write_ok := file.get_error() == OK and file.get_length() > 0
	file.close()
	if not write_ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path)
	)
	return error == OK
