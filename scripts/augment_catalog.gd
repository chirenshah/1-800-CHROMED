extends Resource
class_name AugmentCatalog

@export var augments: Array[Dictionary] = []


func profile(augment_id: String) -> Dictionary:
	for augment in augments:
		if augment["id"] == augment_id:
			return augment
	return {}
