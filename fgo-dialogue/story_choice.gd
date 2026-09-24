extends Resource
class_name StoryChoice

@export var choice_text: String = ""
@export var next_event: StoryEvent # Próxima conversa
@export var trigger_game_event: GameEvent # Ou dispara uma luta
