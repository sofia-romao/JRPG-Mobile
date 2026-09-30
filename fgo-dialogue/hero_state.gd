class_name HeroState
extends Resource

@export var blueprint: HeroData
@export var current_hp: int = 0
@export var current_mp: int = 0 

# Agora a chave é o Resource do Status e o valor é o turno restante
# Ex: { [StatusEffect:Poison]: 3 }
var active_status: Dictionary = {}

signal changed_hp(new_hp: int, max_hp: int, change: int)
signal changed_mp(new_mp: int, max_mp: int, change: int)
signal status_updated() # Avisa a UI mobile que os ícones de buffs/debuffs mudaram

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

# --- Gerenciamento de Status (Novo Sistema) ---

func apply_status(effect_resource: StatusEffect, duration: int) -> void:
	# Duplicamos o resource para que modificações em runtime (como acumular stacks) 
	# não alterem o arquivo original .tres salvo no disco
	var effect_instance = effect_resource.duplicate()
	
	active_status[effect_instance] = duration
	effect_instance.on_apply(self) # Dispara o gatilho de entrada
	
	# Emite o sinal correto dependendo se é herói ou inimigo
	status_updated.emit() 

func has_status(status_id: String) -> bool:
	for effect in active_status.keys():
		if effect.id == status_id:
			return true
	return false

## Called by the Combat Manager to tick down statuses, ignoring permanent passives (-1 duration)
func tick_status() -> void:
	var to_remove: Array = []
	
	for status in active_status.keys():
		# 🌟 REGRA NOVA: Se a duração for -1, é uma passiva permanente. 
		# Ignoramos o decréscimo e rodamos apenas o comportamento de turno dela!
		if active_status[status] == -1:
			status.on_turn_tick(self, -1)
			continue
			
		# Comportamento normal para status temporários (Veneno, Sono, etc.)
		status.on_turn_tick(self, active_status[status])
		active_status[status] -= 1
		
		if active_status[status] <= 0:
			to_remove.append(status)
			
	for status in to_remove:
		status.on_remove(self)
		active_status.erase(status)
		
	if to_remove.size() > 0:
		status_updated.emit()

func clear_all_status() -> void:
	active_status.clear()
	status_updated.emit()

# --- Getters simplificados do Blueprint Fixo ---

func get_max_hp() -> int:
	return blueprint.max_hp if blueprint else 100

func get_max_mp() -> int:
	return blueprint.max_mp if blueprint else 20

func get_attack() -> int:
	return blueprint.attack if blueprint else 10

func get_speed() -> int:
	return blueprint.speed if blueprint else 5
	
func get_available_skills() -> Array[String]:
	return blueprint.skills if blueprint else []

## Full recovery
func full_heal() -> void:
	current_hp = get_max_hp()
	current_mp = get_max_mp()
	clear_all_status()

## Retorna TRUE se o inimigo hit a weakness (multiplier > 1.0).
# Dentro de hero_state.gd

## Calculates incoming combat damage, evaluates defensive status effects, and updates HP bounds.
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
	
	# 🌟 NOVO: O herói varre seus status ativos para aplicar modificadores modulares
	# Isso permite que status como "SHIELD" reduzam o dano recebido automaticamente!
	for effect in active_status.keys():
		if effect.has_method("modify_damage"):
			final_damage = effect.modify_damage(final_damage, element_type, false)
	
	# Aplica o dano real computado pós-modificadores
	modify_hp(-final_damage) 
	
	print("⚔️ [HeroState] %s received %d damage (%s). Elemental Multiplier: %f" % [blueprint.character_name, final_damage, element_type, multiplier])
	
	return multiplier > 1.0
