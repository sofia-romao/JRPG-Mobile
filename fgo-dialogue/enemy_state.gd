# EnemyState.gd
class_name EnemyState
extends Resource

signal hp_changed(new_hp: int, max_hp: int, change: int)
signal died()

@export var blueprint: EnemyData

var current_hp: int = 0:
	set(valor):
		var antigo_hp = current_hp
		current_hp = clamp(valor, 0, get_max_hp())
		var change = current_hp - antigo_hp
		
		if change != 0:
			hp_changed.emit(current_hp, get_max_hp(), change)
		
		if current_hp == 0:
			died.emit()

func initialize(base_data: EnemyData) -> void:
	blueprint = base_data
	current_hp = get_max_hp()

func get_max_hp() -> int:
	if not blueprint: return 0
	return blueprint.base_hp # Sincronizado com o EnemyData em português!

func get_attack() -> int:
	if not blueprint: return 0
	return blueprint.base_atk # Sincronizado com o EnemyData em português!

## Recebe o dano base e o elemento enviado pelo herói.
func receive_combat_damage(base_dmg: int, element_type: String) -> bool:
	if not blueprint: return false
	
	var multiplier: float = 1.0
	
	match element_type:
		"FIRE": multiplier = blueprint.res_fire
		"ICE": multiplier = blueprint.res_ice
		"ELEC": multiplier = blueprint.res_elec
		"PHYSICAL": multiplier = blueprint.res_physical
		
	var final_dmg: int = int(base_dmg * multiplier)
	current_hp -= final_dmg
	
	print("👹 [EnemyState] Monstro tomou %d de dano (%s). HP: %d/%d" % [final_dmg, element_type, current_hp, get_max_hp()])
	
	return multiplier > 1.0
