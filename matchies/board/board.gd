class_name Board
extends Node2D

# Represents the game board, responsible for the grid of matchies.

enum MatchDirection { LEFT, UP }

const matchie_scene: PackedScene = preload("res://matchies/matchie.tscn")
const tile_scene: PackedScene = preload("res://board/tile.tscn")

export (int) var columns: int
export (int) var rows: int
export (int) var separation: int

var matchie_grid := Array()
var tiles_grid := Array()
var user_is_dragging := false
var drag_start_pos := Vector2(-1, -1)
var action_queue := Array()

# when true, check_for_matches will undo the last move if there are no matches
var undo_if_no_matches := false
var last_match_from: Vector2
var last_match_to: Vector2

onready var tiles := $tiles
onready var matchies := $matchies
onready var block_timer := $block_timer
onready var pop_target := $pop_target

class Match:
	var start: Vector2
	var length: int
	var direction: int
	
	func _init(start_: Vector2, length_: int, direction_: int) -> void:
		self.start = start_
		self.length = length_
		self.direction = direction_

func _ready() -> void:
	randomize()
	populate_grid()

func _process(_delta: float) -> void:
	# we ignore input while the block timer is running.
	if block_timer.time_left <= 0:
		handle_input()

func handle_input() -> void:
	# checks for mouse input and adjusts the board state accordingly
	
	var pressed := Input.is_action_just_pressed("click")
	var released := Input.is_action_just_released("click")
	var mouse := get_viewport().get_mouse_position()
	var in_bounds := is_in_bounds(mouse)
	
	# out of bounds presses are ignored
	if pressed and not in_bounds:
		return
		
	# any release cancels current drag
	if user_is_dragging and released:
		end_drag(Vector2(-1, -1))
		return
	
	var grid_pos := world_to_grid(mouse)
	
	# in bounds presses start a drag
	if not user_is_dragging and pressed and in_bounds:
		start_drag(grid_pos)
	
	# in bounds movement off drag tile ends a drag
	if user_is_dragging and in_bounds and grid_pos != drag_start_pos:
		# but only if it's not diagonal
		if grid_pos.x == drag_start_pos.x or grid_pos.y == drag_start_pos.y:
			end_drag(grid_pos)
		else:
			end_drag(Vector2(-1, -1))

func start_drag(start_pos: Vector2) -> void:
	# starts a drag action from a position on the grid
	
	user_is_dragging = true
	drag_start_pos = start_pos

func end_drag(end_pos: Vector2) -> void:
	# finishes a drag action on a grid position
	
	if end_pos.x >= 0 and end_pos.y >= 0 and end_pos != drag_start_pos:
		swap_and_check_matches(drag_start_pos, end_pos)
	
	user_is_dragging = false
	drag_start_pos = Vector2(-1, -1)

func is_in_bounds(check: Vector2) -> bool:
	# checks if the given world position is on the board
	
	var width := columns * separation
	var height := rows * separation
	return (
		check.x >= position.x and
		check.y >= position.y and
		check.x < position.x + width and
		check.y < position.y + height
	)

func perform_swap(from: Vector2, to: Vector2) -> void:
	var from_matchie: Matchie = matchie_grid[from.x][from.y]
	var to_matchie: Matchie = matchie_grid[to.x][to.y]
	
	matchie_grid[to.x][to.y] = from_matchie
	matchie_grid[from.x][from.y] = to_matchie
	
	if from_matchie:
		from_matchie.move(grid_to_local(to))
	
	if to_matchie:
		to_matchie.move(grid_to_local(from))
	
	UIAudio.get_node("swap").play()

func swap_and_check_matches(from: Vector2, to: Vector2) -> void:
	# swaps two matchies and queues up a match check
	
	if (
		from.x < 0 or to.x < 0 or from.x >= columns or to.x >= columns or
		from.y < 0 or to.y < 0 or from.y >= rows or to.y >= rows
	):
		return
	
	perform_swap(from, to)
	
	# signal that this match should be undone if there are no matches
	last_match_from = from
	last_match_to = to
	undo_if_no_matches = true
	
	# queue up a match check once the swap is mostly done
	block_timer.start(Matchie.SWAP_ANIM_DURATION / 2)
	action_queue.append("check_for_matches")

func populate_grid() -> void:
	# fills the board with random matchies
	
	for i in columns:
		matchie_grid.append(Array())
		tiles_grid.append(Array())
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
			
			# finalise the matchie node and add it to the scene
			matchie.name = Matchie.MatchieType.keys()[matchie.matchie_type]
			matchie.position = grid_to_local(Vector2(i, j))
			matchies.add_child(matchie)
			
			# add a corresponding background tile
			var tile: Node2D = tile_scene.instance()
			tiles_grid[i].append(tile)
			tile.position = matchie.position
			tiles.add_child(tile)

func has_match_at_position(i: int, j: int) -> bool:
	# checks for any match at the given grid position
	
	return horizontal_match_length(i, j) >= 3 or vertical_match_length(i, j) >= 3

func clear_match(m: Match, sequence: int) -> void:
	# removes a matched group of matchies from the grid
	
	var direction := Vector2(-1, 0) if m.direction == MatchDirection.LEFT else Vector2(0, -1)
	for i in m.length:
		var pos: Vector2 = m.start + direction * i
		
		var matchie: Matchie = matchie_grid[pos.x][pos.y]
		if matchie:
			matchie.pop(pop_target.global_position, sequence)
			matchie_grid[pos.x][pos.y] = null
			
			sequence += 1

func undo_last_match() -> void:
	if not undo_if_no_matches:
		return
	
	undo_if_no_matches = false
	perform_swap(last_match_to, last_match_from)

func check_for_matches() -> void:
	# find all matches on the board and clears them, then settles the grid.
	
	var matches := find_all_matches()
	
	if not matches:
		if undo_if_no_matches:
			undo_last_match()
		return
	
	undo_if_no_matches = false
	
	var sequence := 0
	for m in matches:
		clear_match(m, sequence)
		sequence += m.length
		
		match m.length:
			3: ScoreManager.add_triplet()
			4: ScoreManager.add_quadruplet()
			5: ScoreManager.add_quintuplet()
			_: push_error("unsupported match length %" % m.length)
		
		var dir := Vector2(-1, 0) if m.direction == MatchDirection.LEFT else Vector2(0, -1)
		for i in m.length:
			var pos: Vector2 = m.start + dir * i
			tiles_grid[pos.x][pos.y].get_node("score_particles").emitting = true
	
	# wait for matches to clear, then settle the grid
	block_timer.start(Matchie.POP_ANIM_DURATION)
	action_queue.append("settle_grid")

func settle_grid() -> void:
	# moves all matchies down until there is no empty space below
	
	var sequence := 0
	for i in columns:
		for j in range(rows - 1, 0, -1):
			var matchie: Matchie = matchie_grid[i][j]
			if not matchie:
				if not pull_matchie_down(i, j, sequence):
					# nothing left above, skip the rest of this column
					break
				sequence += 1
	
	spawn_new_matchies(sequence)

func pull_matchie_down(i: int, j: int, sequence: int) -> bool:
	# given a free space (i, j), try to find a matchie above to place in this slot.
	# returns true if this was possible
	
	# we can't pull anything down if this is the top row
	if j <= 0:
		return false
	
	for row in range(j - 1, -1, -1):
		var matchie: Matchie = matchie_grid[i][row]
		if matchie:
			matchie_grid[i][row] = null
			matchie_grid[i][j] = matchie
			matchie.slide(grid_to_local(Vector2(i, j)), false, sequence)
			return true
	
	return false

func spawn_new_matchies(sequence: int) -> void:
	# fills all free spaces with new random matchies
	for i in columns:
		for j in rows:
			if matchie_grid[i][j]:
				continue
			
			var matchie: Matchie = matchie_scene.instance()
			matchie_grid[i][j] = matchie
			matchie.matchie_type = random_matchie_type()
			
			var final_position := grid_to_local(Vector2(i, j))
			matchie.position = final_position - Vector2(0, separation)
			matchies.add_child(matchie)
			matchie.slide(final_position, true, sequence)
			sequence += 1
			
	# wait for grid to settle then check for new matches
	block_timer.start(Matchie.SLIDE_ANIM_DURATION)
	action_queue.append("check_for_matches")

func find_all_matches() -> Array:
	# find & return an array of matches on the board
	
	var matches := Array()
	matches.append_array(find_vertical_matches())
	matches.append_array(find_horizontal_matches())
	return matches
	
func find_vertical_matches() -> Array:
	# find and return all vertically aligned matches on the board
	
	var matches := Array()
	
	for i in columns:
		var skip := 0
		for j in range(rows - 1, 1, -1):
			if skip > 0:
				skip -= 1
				continue
			
			var match_length := vertical_match_length(i, j)
			
			if match_length >= 3:
				matches.append(Match.new(Vector2(i, j), match_length, MatchDirection.UP))
			
			# we can skip any remaining matched pieces, since we've already found the longest option
			skip = match_length - 1
	
	return matches

func find_horizontal_matches() -> Array:
	# find and return all horizontally aligned matches on the board
	
	var matches := Array()
	
	# used to skip checking tiles when a match is found
	
	for j in rows:
		var skip := 0
		for i in range(columns - 1, 1, -1):
			if skip > 0:
				skip -= 1
				continue
			
			var match_length := horizontal_match_length(i, j)
			
			if match_length >= 3:
				matches.append(Match.new(Vector2(i, j), match_length, MatchDirection.LEFT))
			
			# we can skip matched pieces, since we've already found the longest option
			skip = match_length - 1
	
	return matches

func horizontal_match_length(i: int, j: int) -> int:
	# starting at (i, j) move left and count instances of this tile
	
	var matchie: Matchie = matchie_grid[i][j]
	if not matchie:
		return 0
	
	var matchie_type: int = matchie.matchie_type
	var count := 1
	
	while i > 0:
		i -= 1
		if has_type_at_position(i, j, matchie_type):
			count += 1
		else:
			break
	
	return count

func vertical_match_length(i: int, j: int) -> int:
	# starting at (i, j) move up and count instances of this tile
	
	var matchie: Matchie = matchie_grid[i][j]
	if not matchie:
		return 0
	
	var matchie_type: int = matchie.matchie_type
	var count := 1
	
	while j > 0:
		j -= 1
		if has_type_at_position(i, j, matchie_type):
			count += 1
		else:
			break
	
	return count

func has_type_at_position(i: int, j: int, matchie_type: int) -> bool:
	# test if the given type is at the given position
	# silently ignores indexing errors (and returns false)
	
	if i < 0 or i >= columns or j < 0 or j >= rows:
		return false
	
	var matchie: Matchie = matchie_grid[i][j]
	if matchie:
		return matchie.matchie_type == matchie_type
		
	return false

func grid_to_local(grid: Vector2) -> Vector2:
	# convert a grid coordinate to a local space coordinate
	
	return Vector2(grid.x * separation, grid.y * separation)

func world_to_grid(world: Vector2) -> Vector2:
	# convert a world position to a grid coordinate
	
	return Vector2(
		int((world.x - position.x) / separation),
		int((world.y - position.y) / separation)
	)

func random_matchie_type() -> int:
	# pick a random matchie type
	
	var options := Matchie.MatchieType.values()
	return options[randi() % Matchie.MatchieType.size()]

func _on_block_timer_timeout():
	# execute actions in the action queue
	
	while action_queue.size() > 0:
		var action: String = action_queue.pop_front()
		call_deferred(action)
