# skill_data.gd
class_name SkillData
extends Resource

# Dentro de skill_data.gd
enum TargetType { 
	ENEMY,          # Alvo: O monstro
	ALLY_SINGLE,    # Alvo: Um herói específico da equipe
	ALLY_ALL,       # Alvo: A equipe inteira de uma vez só
	EVERYONE,       # 🌟 NOVO: Afeta o inimigo E todos os aliados ao mesmo tempo
	SELF            # 🌟 NOVO: Aplica o status puramente no herói que conjurou
}


@export var id: String = ""
@export var name: String = "Agi"
@export var mp_cost: int = 4

@export_enum("PHYSICAL", "FIRE", "ICE", "ELEC", "HEAL", "SUPPORT") var element_type: String = "PHYSICAL"
@export var target_type: TargetType = TargetType.ENEMY
@export var damage_multiplier: float = 1.0

# 🌟 NOVO: Referência direta ao Resource modular de Status Effect
@export_group("Status Effect")
@export var status_to_apply: StatusEffect = null
@export_range(0.0, 1.0) var status_chance: float = 0.0
@export var status_duration: int = 0

@export_group("Audio Elements")
@export var sound_cast: AudioStream   
@export var sound_impact: AudioStream 
