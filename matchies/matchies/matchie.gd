class_name Matchie
extends Node2D

# represents a matchie, one creature on the board that can be matched.

enum MatchieType {
	BABY_CHICK,
	CRAB,
	SAUROPOD,
	SNAKE,
	WHALE,
	OCTOPUS,
}

const SLIDE_ANIM_DURATION = 1.0
const SWAP_ANIM_DURATION = 0.6
const POP_ANIM_DURATION = 0.3
const MATCHIE_TYPE_SPRITES := {
	MatchieType.BABY_CHICK: preload("res://matchies/sprites/baby-chick.png"),
	MatchieType.CRAB: preload("res://matchies/sprites/crab.png"),
	MatchieType.SAUROPOD: preload("res://matchies/sprites/sauropod.png"),
	MatchieType.SNAKE: preload("res://matchies/sprites/snake.png"),
	MatchieType.WHALE: preload("res://matchies/sprites/whale.png"),
	MatchieType.OCTOPUS: preload("res://matchies/sprites/octopus.png"),
}

export (MatchieType) var matchie_type: int

onready var sprite := $sprite_node/sprite
onready var tween := $tween

func _ready() -> void:
	sprite.texture = MATCHIE_TYPE_SPRITES[matchie_type]

func move(to: Vector2, sequence: int = 0) -> void:
	# smoothly move to a new position.
	# sequence delays the transition for a rippling effect.
	
	var delay := sequence * 0.02
	
	tween.interpolate_property(
		self, "position",
		position, to,
		SWAP_ANIM_DURATION,
		Tween.TRANS_ELASTIC, Tween.EASE_OUT,
		delay
	)
	tween.start()

func slide(to: Vector2, fade_in: bool = false, sequence: int = 0) -> void:
	# smoothly slide to a new position, with a bounce.
	# like a bouncy slower version of move.
	# sequence delays the transition for a rippling effect.
	
	var delay := sequence * 0.02
	
	if fade_in:
		modulate.a = 0
	
	tween.interpolate_property(
		self, "position",
		position, to,
		SLIDE_ANIM_DURATION,
		Tween.TRANS_BOUNCE, Tween.EASE_OUT,
		delay
	)
	if fade_in:
		tween.interpolate_property(
			self, "modulate",
			Color(1, 1, 1, 0), Color(1, 1, 1, 1),
			SLIDE_ANIM_DURATION / 2,
			Tween.TRANS_LINEAR, Tween.EASE_OUT,
			delay
		)
	tween.start()

func pop(sequence: int = 0) -> void:
	# expand & fade out the matchie, then disappear.
	# sequence delays the transition for a rippling effect.
	
	var delay := sequence * 0.05
	
	tween.interpolate_property(
		sprite, "scale",
		sprite.scale, Vector2(2, 2),
		POP_ANIM_DURATION,
		Tween.TRANS_LINEAR, Tween.EASE_OUT,
		delay
	)
	tween.interpolate_property(
		self, "modulate",
		Color(1, 1, 1, 1), Color(1, 1, 1, 0),
		POP_ANIM_DURATION,
		Tween.TRANS_LINEAR, Tween.EASE_OUT,
		delay
	)
	tween.interpolate_callback(UIAudio.get_node("pop"), delay, "play")
	tween.start()
