extends Resource
class_name OpeningSequence
## Narrative copy and pacing, editable on the sequence resource in the Inspector.

@export_group("Establishing moment")
@export var archive_heading := "CIVILIZATION / CONTINUITY REPORT"
@export var year_title := "THE YEAR IS 2189."
@export var archive_footer := "A BRIEF HISTORY OF PROGRESS"
@export_range(0.1, 30.0, 0.1) var establish_seconds := 4.5

@export_group("Crawl")
@export_multiline var crawl_paragraphs: PackedStringArray = []
@export var accent_paragraphs := PackedInt32Array([1, 6, 8])
@export_range(1.0, 180.0, 0.5) var crawl_seconds := 58.0

@export_group("Corporate boot")
@export var boot_heading := "HISTORICAL CONTEXT COMPLETE"
@export var boot_messages := PackedStringArray([
	"Connecting to your better future...",
	"Loading independent sales intermediary...",
	"Restoring managerial privileges: GRADE C-7",
	"Welcome back. This is your first day."
])
@export_range(0.1, 30.0, 0.1) var boot_seconds := 3.2

@export_group("Title reveal")
@export var welcome := "WELCOME TO"
@export var company_title := "1-800-CHROMED"
@export var motto := "Your body. Our business."
@export_multiline var appointment := "REGIONAL SALES FLOOR MANAGER\nGRADE C-7  /  9 WORKSTATIONS"
@export_multiline var predecessor_notice := "PREDECESSOR: TERMINATED — PERFORMANCE BELOW EXPECTATIONS\nClarification request: closed without clarification."
@export var directive := "YOUR QUARTER BEGINS NOW."
@export_range(0.1, 30.0, 0.1) var reveal_seconds := 9.0

@export_group("Transition")
@export_range(0.1, 5.0, 0.1) var fade_seconds := 0.65
