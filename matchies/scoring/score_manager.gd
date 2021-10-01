extends Node

signal score_changed

const SCORE_TRIPLET := 100
const SCORE_QUADRUPLET:= 300
const SCORE_QUINTUPLET := 500

var _score := 0

func _add_score(amount: int) -> void:
	_score += amount
	emit_signal("score_changed", _score)

func add_triplet():
	_add_score(SCORE_TRIPLET)

func add_quadruplet():
	_add_score(SCORE_QUADRUPLET)

func add_quintuplet():
	_add_score(SCORE_QUINTUPLET)
