# StoryChoice.gd
extends Resource
class_name StoryChoice

@export var choice_text: String = ""
@export var next_event: GameEvent 
@export var trigger_game_event: GameEvent 
