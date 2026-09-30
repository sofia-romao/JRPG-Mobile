# effect_poison.gd
extends StatusEffect

@export var damage_per_tick: int = 5

func on_turn_tick(target: Object, elapsed_turn: int) -> void:
	if target.has_method("modify_hp"):
		target.modify_hp(-damage_per_tick)
		print("🧪 %s sofreu %d de dano por Veneno!" % [target.name, damage_per_tick])
