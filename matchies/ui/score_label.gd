extends Label

onready var tween := $tween

var displayed_value := 0

func _ready() -> void:
	var err := ScoreManager.connect("score_changed", self, "update_score")
	if err:
		push_error("failed to connect score_changed to score label")

func _process(_delta: float) -> void:
	text = "%08d" % displayed_value

func update_score(score: int) -> void:
	tween.interpolate_property(
		self, "displayed_value",
		displayed_value, score,
		1.0,
		Tween.TRANS_SINE, Tween.EASE_OUT
	)
	tween.start()
