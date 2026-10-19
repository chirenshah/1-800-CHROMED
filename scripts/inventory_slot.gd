extends PanelContainer
class_name InventorySlot
## One drag-and-drop cell. It only reports intent; the game state lives in InventoryManager.

signal dropped(data: Dictionary, target_kind: String, target_index: int)

const VALID_COLOR := Color(0.29, 0.94, 0.82)
const INVALID_COLOR := Color(0.95, 0.3, 0.38)
const IDLE_COLOR := Color(0.16, 0.21, 0.29)

var kind := "item"
var index := 0
var editable := true
var drag_data: Dictionary = {}
var drop_validator := Callable()
var _style: StyleBoxFlat
var _title: Label
var _detail: Label


func _init() -> void:
	custom_minimum_size = Vector2(96, 64)
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.035, 0.05, 0.08)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(5)
	_style.border_color = IDLE_COLOR
	add_theme_stylebox_override("panel", _style)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	add_child(content)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 12)
	_title.clip_text = true
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_title)
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 10)
	_detail.add_theme_color_override("font_color", Color(0.62, 0.73, 0.79))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.clip_text = true
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_detail)


func show_contents(title: String, detail: String, tooltip: String, data: Dictionary, accent := Color(0.94, 0.96, 1)) -> void:
	_title.text = title if not title.is_empty() else "— empty —"
	_title.add_theme_color_override("font_color", accent if not title.is_empty() else Color(0.35, 0.42, 0.52))
	_detail.text = detail
	tooltip_text = tooltip
	drag_data = data
	mouse_default_cursor_shape = Control.CURSOR_DRAG if editable and not data.is_empty() else Control.CURSOR_ARROW


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not editable or drag_data.is_empty():
		return null
	var preview := Label.new()
	preview.text = _title.text
	preview.add_theme_color_override("font_color", VALID_COLOR)
	set_drag_preview(preview)
	return drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid: bool = editable and data is Dictionary and drop_validator.is_valid() and drop_validator.call(data, kind, index)
	_style.border_color = VALID_COLOR if valid else INVALID_COLOR
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_style.border_color = IDLE_COLOR
	dropped.emit(data, kind, index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		if _style != null:
			_style.border_color = IDLE_COLOR
