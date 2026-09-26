class_name HeroState
extends Resource

@export var blueprint: HeroData
@export var current_exp: int = 0
@export var current_hp: int = 0
@export var current_mp: int = 0 # 🔮 Agora oficializado!

signal changed_hp(new_hp: int, max_hp: int, change: int)
signal changed_mp(new_mp: int, max_mp: int, change: int) # 🔮 UI de batalha vai escutar este sinal

## Updates HP, clamping to bounds and emitting signal for Mobile UI
func modify_hp(amount: int) -> void:
	var old_hp = current_hp
	current_hp = clamp(current_hp + amount, 0, get_max_hp())
	var change = current_hp - old_hp
	
	if change != 0:
		changed_hp.emit(current_hp, get_max_hp(), change)

## Updates MP, clamping to bounds and emitting signal for Mobile UI
func modify_mp(amount: int) -> void:
	var old_mp = current_mp
	current_mp = clamp(current_mp + amount, 0, get_max_mp())
	var change = current_mp - old_mp
	
	if change != 0:
		changed_mp.emit(current_mp, get_max_mp(), change)

## Calculates current level based on EXP
func get_level() -> int:
	return int(current_exp / 1000) + 1

## Gets Max HP dynamically from the blueprint scaling
func get_max_hp() -> int:
	if not blueprint: return 100
	return blueprint.get_max_hp(get_level())

## Gets Max MP dynamically from the blueprint scaling
func get_max_mp() -> int:
	if not blueprint: return 20
	return blueprint.get_max_mp(get_level())

## Gets Attack dynamically from the blueprint scaling
func get_attack() -> int:
	if not blueprint: return 10
	return blueprint.get_attack(get_level())

## Gets Speed dynamically from the blueprint scaling
func get_speed() -> int:
	if not blueprint: return 5
	return blueprint.get_speed(get_level())

## Full recovery (used on mission clears or full heals)
func full_heal() -> void:
	current_hp = get_max_hp()
	current_mp = get_max_mp() # Restaura o MP totalmente também!

## Applies combat damage calculating elemental resistances from HeroData.
## Returns TRUE if the enemy hit a weakness (multiplier > 1.0).
func take_damage_combat(damage_base: int, element_type: String) -> bool:
	if not blueprint: return false
	
	var multiplier: float = 1.0
	
	match element_type:
		"FIRE": multiplier = blueprint.res_fire
		"ICE": multiplier = blueprint.res_ice
		"ELEC": multiplier = blueprint.res_elec
		"PHYSICAL": multiplier = blueprint.res_physical
	
	var final_damage: int = int(damage_base * multiplier)
	modify_hp(-final_damage) 
	
	print("⚔️ [HeroState] %s received %d damage (%s). Multiplier: %f" % [blueprint.character_name, final_damage, element_type, multiplier])
	
	return multiplier > 1.0
