# effect_shield.gd
extends StatusEffect

@export var reduction_percentage: float = 0.5 # 50% de redução

func modify_damage(base_damage: int, is_inflicting: bool) -> int:
	# Se o alvo está RECEBENDO dano, reduz o dano
	if not is_inflicting:
		return int(base_damage * (1.0 - reduction_percentage))
	return base_damage
