# StoryLine.gd
extends Resource
class_name StoryLine

@export var character_name: String = ""
@export_multiline var text: String = ""
@export var character_portrait: Texture2D

@export var shake_screen: bool = false
@export var flash_screen: Color = Color(0, 0, 0, 0)
