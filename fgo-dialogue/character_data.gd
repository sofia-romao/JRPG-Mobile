# character_data.gd
extends Resource
class_name CharacterData

enum Expressions { DEFAULT, HAPPY, SAD, ANGRY, SURPRISED }

@export var character_name: String = ""
## Mapeia a expressão (Enum) para a sua respectiva imagem (Texture2D)
@export var portraits: Dictionary = {
	Expressions.DEFAULT: null,
	Expressions.HAPPY: null,
	Expressions.SAD: null,
	Expressions.ANGRY: null,
	Expressions.SURPRISED: null
}
