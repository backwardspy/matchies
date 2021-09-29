extends Node2D
class_name Matchie

enum MatchieType {
	BABY_CHICK,
	CRAB,
	SAUROPOD,
	SNAKE,
	WHALE,
}

export (MatchieType) var matchie_type: int

const matchie_type_sprites := {
	MatchieType.BABY_CHICK: preload("res://matchies/sprites/baby-chick.png"),
	MatchieType.CRAB: preload("res://matchies/sprites/crab.png"),
	MatchieType.SAUROPOD: preload("res://matchies/sprites/sauropod.png"),
	MatchieType.SNAKE: preload("res://matchies/sprites/snake.png"),
	MatchieType.WHALE: preload("res://matchies/sprites/whale.png"),
}

onready var sprite := $sprite_node/sprite


func _ready() -> void:
	sprite.texture = matchie_type_sprites[matchie_type]
