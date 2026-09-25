class_name SkillData
extends Resource

@export var id: String = ""
@export var name: String = "Agi"
@export var mp_cost: int = 4

# Tipo do elemento: "PHYSICAL", "FIRE", "ICE", "ELEC"
@export_enum("PHYSICAL", "FIRE", "ICE", "ELEC") var element_type: String = "PHYSICAL"

# O multiplicador de dano da habilidade (ex: 1.5 significa que dá 150% do ataque do herói)
@export var damage_multiplier: float = 1.0
