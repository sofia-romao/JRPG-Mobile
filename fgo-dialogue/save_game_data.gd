# save_game_data.gd
class_name SaveGameData
extends Resource

@export var is_mission_in_progress: bool = false
@export var active_mission_id: String = ""
@export var completed_missions: Array[String] = []
@export var active_party: Array[String] = []

# Guardamos um dicionário simples de ID : Atributos dinâmicos dos heróis
@export var hero_stats: Dictionary = {}
