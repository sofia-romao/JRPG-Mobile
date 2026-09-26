# EnemyData.gd
class_name EnemyData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var color_theme: Color = Color.WHITE
@export var combat_sprite: Texture2D

@export_category("Atributos Base")
@export var base_hp: int = 50
@export var base_mp: int = 30  
@export var base_atk: int = 10
@export var xp_reward: int = 20

@export_category("Resistências Elementais")
@export var res_fire: float = 1.0
@export var res_ice: float = 1.0
@export var res_elec: float = 1.0
@export var res_physical: float = 1.0

@export_category("Habilidades do Inimigo")
@export var skill_list: Array[String] = []
