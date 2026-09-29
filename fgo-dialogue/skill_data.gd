class_name SkillData
extends Resource

enum TargetType { ENEMY, ALLY_SINGLE, ALLY_ALL }

@export var id: String = ""
@export var name: String = "Agi"
@export var mp_cost: int = 4

@export_enum("PHYSICAL", "FIRE", "ICE", "ELEC", "HEAL", "SUPPORT") var element_type: String = "PHYSICAL"
@export var target_type: TargetType = TargetType.ENEMY
@export var damage_multiplier: float = 1.0

@export_group("Efeitos de Status (Novo)")
@export_enum("NONE", "POISON", "SHIELD", "MOLHADO", "RAGE") var status_to_apply: String = "NONE"
@export var status_duration: int = 0
@export var status_chance: float = 1.0 # 1.0 = 100% de chance de aplicar

@export_group("Audio Elements")
@export var sound_cast: AudioStream   
@export var sound_impact: AudioStream 
