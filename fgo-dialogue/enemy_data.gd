# EnemyData.gd
class_name EnemyData
extends Resource

@export var id: String = ""
@export var nome: String = ""
@export var cor_tema: Color = Color.WHITE
@export var sprite_combate: Texture2D

@export_category("Atributos Base")
@export var hp_base: int = 50
@export var ataque_base: int = 10
@export var xp_recompensa: int = 20

@export_category("Resistências Elementais")
@export var res_fire: float = 1.0
@export var res_ice: float = 1.0
@export var res_elec: float = 1.0
@export var res_physical: float = 1.0
