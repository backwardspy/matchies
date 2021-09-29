extends Node2D


export (int) var columns: int
export (int) var rows: int
export (int) var separation: int


const matchie_scene: PackedScene = preload("res://matchies/matchie.tscn")
const tile_scene: PackedScene = preload("res://board/tile.tscn")


onready var tiles := $tiles
onready var matchies := $matchies


var matchie_grid := Array()


func _ready():
	randomize()
	
	for i in columns:
		matchie_grid.append(Array())
		for j in rows:
			# make a new matchie and put it into the board grid
			var matchie: Matchie = matchie_scene.instance()
			matchie_grid[i].append(matchie)
			
			# try to pick a type that doesn't cause any matches
			matchie.matchie_type = random_matchie_type()
			var attempts := 100
			while has_match_at_position(i, j) and attempts > 0:
				matchie.matchie_type = random_matchie_type()
				attempts -= 1
			
			# position the matchie and add it to the scene
			matchie.position = grid_to_world(i, j)
			matchies.add_child(matchie)
			
			# add a corresponding background tile
			var tile: Node2D = tile_scene.instance()
			tile.position = matchie.position
			tiles.add_child(tile)


func has_match_at_position(i: int, j: int) -> bool:
	# we always search right to left, bottom to top as this allows us to find
	# matches even while the board is being generated
	var matchie_type: int = matchie_grid[i][j].matchie_type
	
	if (
		i >= 2 and
		has_type_at_position(i - 1, j, matchie_type) and
		has_type_at_position(i - 2, j, matchie_type)
	):
		return true
	
	if (
		j >= 2 and
		has_type_at_position(i, j - 1, matchie_type) and
		has_type_at_position(i, j - 2, matchie_type)
	):
		return true
	
	return false
	
	
func has_type_at_position(i: int, j: int, matchie_type: int) -> bool:
	# test if the given type is at the given position
	# silently ignores indexing errors (and returns false)
	if i < 0 or i >= columns or j < 0 or j >= rows:
		return false
	
	return matchie_grid[i][j].matchie_type == matchie_type


func grid_to_world(i: int, j: int) -> Vector2:
	return Vector2(i * separation, j * separation)


func random_matchie_type() -> int:
	var options := Matchie.MatchieType.values()
	return options[randi() % Matchie.MatchieType.size()]
