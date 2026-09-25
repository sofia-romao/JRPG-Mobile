# EnemyState.gd
class_name EnemyState
extends Resource

signal hp_alterado(novo_hp: int, max_hp: int, mudanca: int)
signal morreu()

@export var blueprint: EnemyData

var hp_atual: int = 0:
	set(valor):
		var antigo_hp = hp_atual
		hp_atual = clamp(valor, 0, get_max_hp())
		var mudanca = hp_atual - antigo_hp
		
		if mudanca != 0:
			hp_alterado.emit(hp_atual, get_max_hp(), mudanca)
		
		if hp_atual == 0:
			morreu.emit()

func inicializar(dados_base: EnemyData) -> void:
	blueprint = dados_base
	hp_atual = get_max_hp()

func get_max_hp() -> int:
	if not blueprint: return 0
	return blueprint.hp_base # Sincronizado com o EnemyData em português!

func get_ataque() -> int:
	if not blueprint: return 0
	return blueprint.ataque_base # Sincronizado com o EnemyData em português!

## Recebe o dano base e o elemento enviado pelo herói.
func receber_dano_combate(dano_base: int, element_type: String) -> bool:
	if not blueprint: return false
	
	var multiplicador: float = 1.0
	
	match element_type:
		"FIRE": multiplicador = blueprint.res_fire
		"ICE": multiplicador = blueprint.res_ice
		"ELEC": multiplicador = blueprint.res_elec
		"PHYSICAL": multiplicador = blueprint.res_physical
		
	var dano_final: int = int(dano_base * multiplicador)
	hp_atual -= dano_final
	
	print("👹 [EnemyState] Monstro tomou %d de dano (%s). HP: %d/%d" % [dano_final, element_type, hp_atual, get_max_hp()])
	
	return multiplicador > 1.0
