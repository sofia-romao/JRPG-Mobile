# save_game_data.gd
class_name SaveGameData
extends Resource

@export var is_mission_in_progress: bool = false
@export var active_mission_id: String = ""
@export var completed_missions: Array[String] = []
@export var active_party: Array[String] = []
@export var unlocked_altria_kits: Array[String] = []
@export var unlocked_mash_kits: Array[String] = []
@export var unlocked_hero3_kits: Array[String] = []
# Guardamos um dicionário simples de ID : Atributos dinâmicos dos heróis
# Agora focado estritamente em: {"current_hp": int, "current_mp": int}
@export var hero_stats: Dictionary = {}
