extends Node

signal score_changed(value: int)
signal game_over

var score := 0
var best := 0

func reset():
	score = 0
	score_changed.emit(score)

func add_score(amount: int):
	score += amount
	if score > best:
		best = score
	score_changed.emit(score)
