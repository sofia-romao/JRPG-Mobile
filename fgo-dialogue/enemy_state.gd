# enemy_state.gd
class_name EnemyState
extends Resource

# Sinais para sincronização com a UI Mobile do CombatManager
signal hp_changed(new_hp: int, max_hp: int, change: int)
signal mp_changed(new_mp: int, max_mp: int, change: int)
signal enemy_status_updated() # Alerta a interface para redesenhar buffs/debuffs
signal phase_changed(new_phase_id: String) # Avisa a troca de blueprint/fase
signal died()

# Registro de fases guardado estritamente na memória em runtime
var phase_registry: Array[BossPhaseData] = []
# O "cérebro" ativo no momento (pode ser substituído em tempo real!)
var active_blueprint: EnemyData

var current_phase_id: String = "INITIAL"
var is_currently_stunned: bool = false

# Dicionário de Status Temporários aplicados pela Party. Ex: {"MOLHADO": 2}
var active_status: Dictionary = {}

var current_hp: int = 0:
	set(valor):
		var antigo_hp = current_hp
		current_hp = clamp(valor, 0, get_max_hp())
		var change = current_hp - antigo_hp
		if change != 0:
			hp_changed.emit(current_hp, get_max_hp(), change)
		if current_hp == 0:
			died.emit()

var current_mp: int = 0

## Inicializa o Boss apontando para a sua ficha EnemyData inicial
## Inicializa o Boss recebendo a Estrutura do Puzzle
## Inicializa o Boss recebendo o Gerenciador do Puzzle
func initialize(structure_data: BossStructureData) -> void:
	if not structure_data:
		print("❌ [DEBUG - EnemyState] ERRO: O combate iniciou com um BossStructureData NULO!")
		return
		
	active_blueprint = structure_data.initial_enemy_blueprint
	phase_registry = structure_data.possible_phases
	
	current_phase_id = "INITIAL"
	is_currently_stunned = false
	active_status.clear()
	
	current_hp = get_max_hp()
	current_mp = get_max_mp()
	
	print("🟢 [DEBUG - EnemyState] BOSS INICIALIZADO COM SUCESSO!")
	print("   | ID do Chefe: %s" % structure_data.boss_id)
	print("   | Forma Inicial: %s (ID da Ficha: %s)" % [active_blueprint.name, active_blueprint.id])
	print("   | Status Iniciais -> HP: %d/%d | MP: %d" % [current_hp, get_max_hp(), current_mp])
	print("   | Fases Registradas em Runtime: %d detectadas." % phase_registry.size())

func get_max_hp() -> int: 
	return active_blueprint.base_hp if active_blueprint else 100

func get_max_mp() -> int: 
	return active_blueprint.base_mp if active_blueprint else 20

func get_attack() -> int: 
	return active_blueprint.base_atk if active_blueprint else 10

func get_speed() -> int: 
	return active_blueprint.speed if active_blueprint else 15

func get_current_skill_list() -> Array[String]: 
	return active_blueprint.skill_list if active_blueprint else []

func get_current_sprite() -> Texture2D: 
	return active_blueprint.combat_sprite if active_blueprint else null

func is_stunned() -> bool: 
	return is_currently_stunned

# --- VULNERABILIDADES E GERENCIAMENTO DE STATUS ---

func apply_status(effect_resource: StatusEffect, duration: int) -> void:
	# Duplicamos o resource para que modificações em runtime (como acumular stacks) 
	# não alterem o arquivo original .tres salvo no disco
	var effect_instance = effect_resource.duplicate()
	
	active_status[effect_instance] = duration
	effect_instance.on_apply(self) # Dispara o gatilho de entrada
	
	# Emite o sinal correto dependendo se é herói ou inimigo
	enemy_status_updated.emit() 

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
		enemy_status_updated.emit()
# --- SISTEMA DE GATILHOS E TRANSFORMAÇÃO POLIMÓRFICA ---

## Chamado sempre que um evento relevante acontece no combate
## Avalia os gatilhos lendo a array local que está na memória de runtime
func evaluate_triggers(event_type: String, context_data: Dictionary = {}) -> void:
	if phase_registry.is_empty(): 
		return
		
	print("🔍 [DEBUG - EnemyState] Avaliando Gatilhos de Fase (Evento: %s)..." % event_type)
	
	for i in range(phase_registry.size()):
		var phase = phase_registry[i]
		if not phase or not phase.phase_blueprint: 
			print("   | ⚠️ Slot de Fase %d está vazio ou sem EnemyData atrelado!" % i)
			continue
			
		# Evita reativar a fase que já está ativa
		if phase.phase_blueprint.id == active_blueprint.id: 
			continue
			
		print("   | Verificando Fase Candidata: %s (Blueprint: %s)" % [phase.phase_blueprint.name, phase.phase_blueprint.id])
		
		var all_conditions_met = true
		if phase.activation_triggers.is_empty():
			print("   | -> ❌ Rejeitada: Esta fase não possui nenhum recurso de gatilho configurado.")
			all_conditions_met = false
			
		for t_idx in range(phase.activation_triggers.size()):
			var trigger = phase.activation_triggers[t_idx]
			if trigger:
				var is_met = trigger.is_condition_met(self, context_data)
				print("   |   -> Gatilho [%s] respondeu: %s" % [trigger.get_custom_class(), "✔️ ATIVADO" if is_met else "❌ NEGADO"])
				if not is_met:
					all_conditions_met = false
					break # Uma falha já quebra a cadeia lógica AND
					
		if all_conditions_met:
			print("⚡ [DEBUG - EnemyState] GATILHOS VALIDADOS! Iniciando rito de transformação...")
			_transform_into_phase(phase)
			break # Sofre apenas uma mutação por checagem

# 🎭 A TRANSFORMAÇÃO DEFINITIVA (MUTAÇÃO DE BLUEPRINTS)
## A Transformação Definitiva com Clamp Seguro
func _transform_into_phase(new_phase: BossPhaseData) -> void:
	is_currently_stunned = new_phase.is_stunned
	var old_blueprint_name = active_blueprint.name
	var old_max_hp = get_max_hp()
	var old_hp = current_hp
	
	# Transiciona o cérebro do monstro
	active_blueprint = new_phase.phase_blueprint
	current_phase_id = active_blueprint.id
	
	# 🔒 O CLAMP DO SEU DESIGN:
	current_hp = clamp(old_hp, 0, get_max_hp())
	
	print("🎭 [DEBUG - EnemyState] === MUTAÇÃO EXECUTADA ===")
	print("   | De: %s  ──>  Para: %s" % [old_blueprint_name, active_blueprint.name])
	print("   | Comportamento Turno: %s" % ("⚠️ VAI PULAR TURNO (Stunned)" if is_currently_stunned else "✔️ Age normalmente"))
	print("   | Transição de HP Máximo: %d  ──>  %d" % [old_max_hp, get_max_hp()])
	print("   | Ajuste Tático de HP Atual: %d  ──>  %d (Clamp Seguro Aplicado)" % [old_hp, current_hp])
	print("   =========================================")
	
	# Dispara os sinais para redesenhar a HUD
	hp_changed.emit(current_hp, get_max_hp(), (current_hp - old_hp))
	phase_changed.emit(active_blueprint.id)
# --- RESOLUÇÃO DE COMBATE ---

## Receives damage, rolls hidden d100 for Evasion/Criticals, and returns the combat outcome string
func receive_combat_damage(base_dmg: int, element_type: String) -> String:
	if not active_blueprint: 
		return "Miss!"
	
	# 🎲 ROLAGEM OCULTA: Sorteia um número secreto de 1 a 100 nos bastidores
	var hidden_roll = randi_range(1, 100)
	
	# --- 💨 1. CHECAGEM DE EVASÃO (Apenas para ataques do elemento PHYSICAL) ---
	if element_type == "PHYSICAL":
		# Se a rolagem oculta cair abaixo ou igual à velocidade do monstro, ele DESVIA!
		if hidden_roll <= get_speed():
			print("💨 [Combat Oculto] Rolou %d (Speed do monstro: %d) -> EVADED!" % [hidden_roll, get_speed()])
			return "Miss!"
			
	# --- SE O ATAQUE CONECTAR: CALCULA O DANO BASE COM MULTIPLICADORES ELEMENTAIS ---
	var multiplier: float = 1.0
	match element_type:
		"FIRE": multiplier = active_blueprint.res_fire
		"ICE": multiplier = active_blueprint.res_ice
		"ELEC": multiplier = active_blueprint.res_elec
		"PHYSICAL": multiplier = active_blueprint.res_physical
		
	# --- 🔒 CHECAGEM DE IMUNIDADE ELEMENTAL ---
	if multiplier == 0.0:
		print("🛡️ [Combat Oculto] Alvo é imune ao elemento: %s" % element_type)
		return "Immune!"
		
	var final_dmg: int = int(base_dmg * multiplier)
	
	# Aplica modificadores dos status modulares (como o Buff/Debuff ou Escudo)
	for effect in active_status.keys():
		if effect.has_method("modify_damage"):
			final_dmg = effect.modify_damage(final_dmg, element_type, false)
			
	# --- 🎯 2. CHECAGEM DO TEXTO DE RETORNO (CRÍTICO, FRAQUEZA OU RESISTÊNCIA) ---
	var outcome_text = "Hit!"
	
	if element_type == "PHYSICAL" and hidden_roll >= 91:
		# Rolou entre 91 e 100 no físico? CRITICAL! (Dano multiplicado por 1.5x)
		final_dmg = int(final_dmg * 1.5)
		outcome_text = "Critical Hit!"
	elif multiplier > 1.0:
		# Acertou fraqueza elemental em magia? WEAKNESS!
		outcome_text = "Weakness!"
	elif multiplier < 1.0:
		# Multiplicador menor que 1 e maior que 0? RESIST!
		outcome_text = "Resist!"
		
	# Reduz o HP real do Boss por trás dos panos
	current_hp -= final_dmg
	
	# Mantém seus gatilhos polimórficos de fase rodando normalmente
	var context = {
		"event_type": "on_damage",
		"element_type": element_type, 
		"active_party_ids": PlayerData.active_party
	}
	evaluate_triggers("on_damage", context)
	
	return outcome_text
func modify_mp(amount: int) -> void:
	var old_mp = current_mp
	current_mp = clamp(current_mp + amount, 0, get_max_mp())
	var change = current_mp - old_mp
	if change != 0:
		mp_changed.emit(current_mp, get_max_mp(), change)
