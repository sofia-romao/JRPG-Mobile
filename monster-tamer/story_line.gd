# StoryLine.gd
extends Resource
class_name StoryLine

@export var character: CharacterData
@export var expression: CharacterData.Expressions = CharacterData.Expressions.DEFAULT
@export_multiline var text: String = ""

@export var shake_screen: bool = false
@export var flash_screen: Color = Color(0, 0, 0, 0)
