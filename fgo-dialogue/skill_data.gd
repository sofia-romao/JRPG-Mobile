class_name SkillData
extends Resource

enum TargetType { ENEMY, ALLY_SINGLE, ALLY_ALL }

@export var id: String = ""
@export var name: String = "Agi"
@export var mp_cost: int = 4

# Tipo do elemento: "PHYSICAL", "FIRE", "ICE", "ELEC", "HEAL"
@export_enum("PHYSICAL", "FIRE", "ICE", "ELEC", "HEAL") var element_type: String = "PHYSICAL"

# 🎯 NOVO: Diz para o motor quem essa skill atinge por padrão
@export var target_type: TargetType = TargetType.ENEMY

# O multiplicador de dano/cura (ex: 1.5 significa 150% do ataque/magia)
@export var damage_multiplier: float = 1.0

@export_group("Audio Elements")
@export var sound_cast: AudioStream   # Som tocado na conjuração
@export var sound_impact: AudioStream # Som tocado no impacto do dano/cura
