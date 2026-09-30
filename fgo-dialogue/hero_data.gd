class_name HeroData
extends Resource

@export_group("Identity & Visuals")
@export var id: String = ""
@export var character_name: String = ""
@export var theme_color: Color = Color.WHITE
@export var avatar_icon: Texture2D

@export_group("Fixed Stats (Kit Completo)")
@export var max_hp: int = 100
@export var max_mp: int = 20
@export var attack: int = 10
@export var speed: int = 5

@export_group("Elemental Resistances")
# SMT System: 1.0 = Normal | 0.5 = Resist | 2.0 = Weakness
@export var res_fire: float = 1.0   # Agi
@export var res_ice: float = 1.0    # Bufu
@export var res_elec: float = 1.0   # Zio
@export var res_physical: float = 1.0

@export_group("Kit - Passivas e Ativas")
@export var passive_resource: StatusEffect = null
@export var skills: Array[String] = [] # Lista das habilidades fixas e ativas do herói
