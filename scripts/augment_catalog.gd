extends Resource
class_name AugmentCatalog

@export var augments: Array[Dictionary] = []
@export var rarity_weights: Dictionary = {
	"Common": 1,
	"Rare": 1,
	"Epic": 1,
	"Legendary": 1,
}
@export var standard_store_rarity_weights: Dictionary = {
	"Common": 60,
	"Uncommon": 30,
	"Rare": 10,
}
@export var premium_store_rarity_weights: Dictionary = {
	"Epic": 85,
	"Legendary": 15,
}
@export var store_reroll_cost := 100


func profile(augment_id: String) -> Dictionary:
	for augment in augments:
		if augment["id"] == augment_id:
			return augment
	return {}
