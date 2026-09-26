class_name HeroState
extends Resource # Usamos Resource para facilitar o sistema de Save/Load no futuro

@export var blueprint: HeroData
@export var current_exp: int = 0
@export var current_hp: int = 0

signal changed_hp(new_hp: int, max_hp: int, change: int)

## Atualiza o HP garantindo os limites e emite o sinal para a UI mobile
func modify_hp(amount: int) -> void:
	var old_hp = current_hp
	current_hp = clamp(current_hp + amount, 0, get_max_hp())
	var change = current_hp - old_hp
	
	if change != 0:
		changed_hp.emit(current_hp, get_max_hp(), change)

## Calcula o nível atual baseado na XP
func get_nivel() -> int:
	return int(current_exp / 1000) + 1

## Busca o HP base no Blueprint e soma o ganho por nível dinamicamente (100% em Português)
## Busca o HP base no Blueprint e soma o ganho por nível dinamicamente
## Busca o HP base no Blueprint e soma o ganho por nível dinamicamente
func get_max_hp() -> int:
	if not blueprint: return 0
	
	# Proteção estática para o HP Base
	var hp_base_val = 100
	if "hp_base" in blueprint: hp_base_val = blueprint.hp_base
	elif "base_hp" in blueprint: hp_base_val = blueprint.base_hp
	
	# Proteção estática para o Ganho por Nível
	var hp_por_nivel_val = 15
	if "hp_por_nivel" in blueprint: hp_por_nivel_val = blueprint.hp_por_nivel
	elif "hp_per_level" in blueprint: hp_por_nivel_val = blueprint.hp_per_level
		
	return hp_base_val + (hp_por_nivel_val * (get_nivel() - 1))

## Busca o Ataque dinamicamente
func get_ataque() -> int:
	if not blueprint: return 0
	
	# Proteção estática para o Ataque Base
	var ataque_base_val = 10
	if "ataque_base" in blueprint: ataque_base_val = blueprint.ataque_base
	elif "base_attack" in blueprint: ataque_base_val = blueprint.base_attack
	
	# Proteção estática para o Ganho por Nível
	var ataque_por_nivel_val = 3
	if "ataque_por_nivel" in blueprint: ataque_por_nivel_val = blueprint.ataque_por_nivel
	elif "attack_per_level" in blueprint: ataque_por_nivel_val = blueprint.attack_per_level
	
	return ataque_base_val + (ataque_por_nivel_val * (get_nivel() - 1))

## Cura total (usado ao limpar missões)
func total_recovery() -> void:
	current_hp = get_max_hp()

# --- MÉTODOS DE COMPATIBILIDADE COM O COMBAT MANAGER ---

## Aplica o dano de combate calculando as resistências elementais do HeroData.
## Retorna TRUE se o inimigo acertou uma fraqueza (multiplicador > 1.0).
func take_damage_combat(damage_base: int, element_type: String) -> bool:
	if not blueprint: return false
	
	var multiplier: float = 1.0
	
	match element_type:
		"FIRE": multiplier = blueprint.res_fire
		"ICE": multiplier = blueprint.res_ice
		"ELEC": multiplier = blueprint.res_elec
		"PHYSICAL": multiplier = blueprint.res_physical
	
	var final_damage: int = int(damage_base * multiplier)
	
	# O dano reduz o HP, por isso passamos o valor negativo para a nossa função
	modify_hp(-final_damage) 
	
	print("⚔️ [HeroState] %s recebeu %d de dano (%s). Multiplicador: %f" % [blueprint.character_name, final_damage, element_type, multiplier])
	
	return multiplier > 1.0
