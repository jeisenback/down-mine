extends RefCounted
class_name TorchSite

## Where one wall torch stands (milestone 60).
var cell: Vector2i
## "shaft" (on the old shaft's timber), "cave" (on a cave floor), "gallery" (along a spine) or
## "mouth" (beside a connector's mouth).
var where: String

func _init(torch_cell: Vector2i, torch_where: String) -> void:
	cell = torch_cell
	where = torch_where

## The dictionary this class replaced, key for key (the golden mine fingerprints hash it).
func to_dict() -> Dictionary:
	return {"cell": cell, "where": where}
