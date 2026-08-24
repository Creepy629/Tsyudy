extends Node

var p1_character: String = "Kung Lao"
var p2_character: String = "Scorpion"
var p1_wins: int = 0
var p2_wins: int = 0
var round_number: int = 1

func reset_match() -> void:
	p1_wins = 0
	p2_wins = 0
	round_number = 1
