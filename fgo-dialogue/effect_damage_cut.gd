class_name EffectDamageCut
extends StatusEffect

@export_group("Damage Cut Settings")
## O valor fixo de dano que será reduzido de cada ataque recebido.
@export var reduction_value: int = 50

# Sobrescrevemos o método para aplicar o corte estático
func modify_damage(base_damage: int, _element_type: String, is_inflicting: bool) -> int:
	# Só queremos reduzir o dano se o alvo ESTIVER RECEBENDO dano (is_inflicting = false)
	if not is_inflicting:
		# Reduz o dano pelo valor estático, mas garante que o dano não seja menor que zero 
		# (para o boss não acabar curando o personagem se o dano for menor que o shield)
		var final_damage = base_damage - reduction_value
		return max(0, final_damage)
	
	# Se for o personagem causando dano, não altera nada
	return base_damage
