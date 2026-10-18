# effect_attribute_buff.gd
class_name EffectAttributeBuff
extends StatusEffect

@export_enum("attack", "speed", "max_hp", "max_mp") var target_attribute: String = "attack"
@export var multiplier: float = 1.30 # Aumenta o atributo em 30%

## Automatically intercepts and updates the stat value when getters are called
func modify_attribute(attribute_name: String, current_value: int) -> int:
	# Se o getter estiver consultando o atributo que este buff altera
	if attribute_name == target_attribute:
		var boosted_value = int(current_value * multiplier)
		print("🔥 [Buff] %s dynamically boosted %s! From %d to %d" % [name, attribute_name, current_value, boosted_value])
		return boosted_value
		
	return current_value
