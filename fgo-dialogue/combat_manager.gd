extends Node
class_name CombatManager

# O sinal que a MainController vai escutar para desinstanciar o combate
signal combat_finished(victory: bool)

# CHECKING_SBA impede que qualquer herói avance ou ataque enquanto processamos mortes
enum CombatState { INITIALIZING, HERO_TURN, ENEMY_TURN, CHECKING_SBA, VICTORY, DEFEAT }
# --- DEFINIÇÃO DE CORES FORTES POR ELEMENTO (FLASH INTENSO) ---
const ELEMENT_COLORS = {
	"PHYSICAL": Color(1.8, 1.8, 1.8, 1.0), # Branco estourado (Brilho HDR)
	"FIRE": Color(2.5, 0.4, 0.1, 1.0),     # Vermelho brasa incandescente
	"ICE": Color(0.2, 1.5, 2.5, 1.0),      # Azul glacial brilhante
	"ELEC": Color(2.5, 2.2, 0.2, 1.0),     # Amarelo relâmpago super forte
	"HEAL": Color(0.2, 2.5, 0.5, 1.0)      # Verde cura radiante
}
# Renomeie a sua constante de cores atual para ENEMY_FLASH_COLORS
const ENEMY_FLASH_COLORS = {
	"PHYSICAL": Color(1.8, 1.8, 1.8, 1.0), 
	"FIRE": Color(2.5, 0.4, 0.1, 1.0),     
	"ICE": Color(0.2, 1.5, 2.5, 1.0),      
	"ELEC": Color(2.5, 2.2, 0.2, 1.0),     
	"HEAL": Color(0.2, 2.5, 0.5, 1.0)
	}
# Cores transparentes e suaves para o clarão de impacto na TELA INTEIRA (Primeira pessoa)
const SCREEN_FLASH_COLORS = {
	"PHYSICAL": Color(1.0, 1.0, 1.0, 0.5), # Clarão Branco translúcido
	"FIRE": Color(1.0, 0.2, 0.0, 0.4),     # Clarão Avermelhado
	"ICE": Color(0.0, 0.6, 1.0, 0.4),      # Clarão Azulado
	"ELEC": Color(1.0, 0.9, 0.0, 0.5),     # Clarão Amarelado
	"HEAL": Color(0.2, 1.0, 0.4, 0.3)      # Clarão Esverdeado
}
@export var damage_popup_scene: PackedScene 

# 📦 Arraste o seu 'HeroStatusCard.tscn' aqui pelo painel Inspector!
@export var hero_status_card_prefab: PackedScene 

var current_state: CombatState = CombatState.INITIALIZING
var combat_data: CombatData
var spawned_enemy: EnemyState

var active_party_ids: Array[String] = []
var current_hero_index: int = 0
var input_blocked: bool = false
# Guarda os tweens de flash ativos indexados pelo ID do herói para evitar duplicidade
var _active_hero_flash_tweens: Dictionary = {}
var _visual_area_original_position: Vector2 = Vector2.ZERO

@export_group("Componentes de UI")
@export var enemy_sprite: TextureRect
@export var background_texture: TextureRect
@export var ui_heroes_container: VBoxContainer  
@export var ui_command_buttons: Control                
@export var enemy_hp_bar: ProgressBar           
@export var dialogue_label: RichTextLabel
@export var ui_dialogue_box: PanelContainer
@export var visual_area_node: Control
@export var screen_flash_effect: ColorRect 
@export var enemy_status_icons_container: HBoxContainer
func _ready() -> void:
	if visual_area_node:
		_visual_area_original_position = visual_area_node.position


## Injeção de Dependência: A Main vai chamar esta função passando os dados do monstro!
func initialize_combat(data: CombatData) -> void:
	combat_data = data
	current_state = CombatState.INITIALIZING
	input_blocked = false
	current_hero_index = 0 
	
	if background_texture and combat_data.background:
		background_texture.texture = combat_data.background
	if combat_data.bgm:
		AudioManager.play_bgm(combat_data.bgm)
		
	spawned_enemy = EnemyState.new()
	# 🚨 CORRIGIDO: Inicializa passando a estrutura completa do puzzle configurada na missão
	spawned_enemy.initialize(combat_data.boss_structure) 
	
	enemy_sprite.texture = spawned_enemy.get_current_sprite()
	
	# Conexões de Sinais
	# Dentro de initialize_combat(data: CombatData) no combat_manager.gd
	spawned_enemy.hp_changed.connect(_on_enemy_hp_changed)
	
	# 🛡️ BLINDAGEM: Comentamos o popup numérico antigo para não conflitar com o minimalismo de palavras!
	#spawned_enemy.hp_changed.connect(func(new_hp, max_hp, change):
		#if change < 0:
			#_trigger_enemy_damage_popup(abs(change), "PHYSICAL")
	#)

	# Escuta as transformações para rodar VFX na UI Mobile
	spawned_enemy.phase_changed.connect(_on_enemy_phase_changed)
	
	if enemy_hp_bar:
		enemy_hp_bar.max_value = spawned_enemy.get_max_hp()
		enemy_hp_bar.value = spawned_enemy.current_hp
		
	if ui_dialogue_box: 
		ui_dialogue_box.hide()
		
	_update_active_party_list()
	
	# 🚨 NOVO: Checagem de "Frame Zero" passando a party ativa para os gatilhos do BossPhaseData
	var initial_context = {
	"event_type": "on_combat_start", 
	"active_party_ids": active_party_ids}
	spawned_enemy.evaluate_triggers("on_combat_start", initial_context)
	
	for hero_id in active_party_ids:
		_update_hero_ui_display(hero_id)
	# Injeta as passivas permanentes na interface e no estado no Frame Zero
	for hero_id in active_party_ids:
		var hero_state = PlayerData.get_hero(hero_id)
	
		if hero_state and hero_state.blueprint and "passive_resource" in hero_state.blueprint:
			var passive_effect = hero_state.blueprint.passive_resource
			if passive_effect:
				# 🌟 Injeta com -1 para ativar o modo permanente protegido
				hero_state.apply_status(passive_effect, -1) 
	_next_hero_turn()

# --- REGRAS DE FLUXO DE TURNO ---

func _next_hero_turn() -> void:
	
	if current_state == CombatState.VICTORY or current_state == CombatState.DEFEAT:
		return
		
	if current_hero_index >= active_party_ids.size():
		_start_enemy_turn()
		return
		
	current_state = CombatState.HERO_TURN
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_hero(hero_id)
	
	# PROCESSA OS STATUS DO HERÓI NO INÍCIO DO TURNO DELE
	# Se ele tiver um veneno, toma dano aqui. Se tiver passiva de MP (como o tanque híbrido), regenera aqui!
	if hero_state:
		_process_hero_passives_and_statuses_start(hero_id, hero_state)
		
	_manage_ui_highlight(hero_id)
	input_blocked = false
	_alternar_interface_combate(true, hero_id)
## Processes natural status ticks and triggers modular resource passives at the start of the hero's turn
func _process_hero_passives_and_statuses_start(hero_id: String, hero_state: HeroState) -> void:
	# 1. Ticks status reductions naturally and executes their on_turn_tick behaviors
	hero_state.tick_status() 
	
	# Every status or passive attached to the hero now handles its own execution 
	# inside its respective script via the 'tick_status' call above.
	
	# 3. Ensures the mobile UI draws the updated bars instantly
	_update_hero_ui_display(hero_id)
	
	# If any other party member's MP changed due to group passives, update their UI cards too
	for p_id in active_party_ids:
		if p_id != hero_id:
			_update_hero_ui_display(p_id)
func _finish_current_hero_turn() -> void:
	input_blocked = true
	
	# 🌟 RESOLVE O ESTADO DA UI PARA O PRÓXIMO PERSONAGEM:
	if ui_command_buttons:
		# 1. Força o menu a fechar as abas secundárias e voltar para os botões principais de forma síncrona
		if ui_command_buttons.has_method("mostrar_menu_principal"):
			ui_command_buttons.mostrar_menu_principal()
		
		# 2. Esconde o painel inteiro durante a transição rítmica dos 0.4 segundos
		ui_command_buttons.hide() 
	
	current_hero_index += 1 
	await get_tree().create_timer(0.4).timeout
	_next_hero_turn()

func _start_enemy_turn() -> void:
	current_state = CombatState.ENEMY_TURN
	_alternar_interface_combate(false)
	
	# ⏳ [UPDATED] Processes enemy status effects modularly at the start of their turn
	if spawned_enemy and spawned_enemy.has_method("tick_status"):
		# Isso vai rodar o 'on_turn_tick' de todos os Resources de status ativos no monstro
		# Sem nenhuma string ou cálculo manual de dano por veneno aqui dentro!
		spawned_enemy.tick_status() 
	
	if ui_dialogue_box:
		var label = ui_dialogue_box.get_node_or_null("DialogueLabel") as RichTextLabel
		if label: 
			label.text = "[center]Enemy Turn...[/center]"
		
	await get_tree().create_timer(0.6).timeout
	_execute_enemy_attack()

	
func _finish_enemy_turn() -> void:
	current_hero_index = 0
	_next_hero_turn()

# --- AÇÕES DE ATAQUE ---

# Dentro de combat_manager.gd

## Executes the hero's basic physical attack, applying dynamic buffs and handling text popups.
func execute_hero_basic_attack() -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
	input_blocked = true
	
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_hero(hero_id)
	
	# Usa o getter dinâmico de ataque (que já calcula o bônus de 30% do Tarukaja automaticamente!)
	var damage_dealt: int = hero_state.get_attack()
	var element: String = "PHYSICAL"
	
	# 🌟 ATUALIZADO: Captura o resultado em texto ("Miss!", "Hit!", "Critical Hit!") vindo do monstro
	var combat_outcome: String = spawned_enemy.receive_combat_damage(damage_dealt, element)
	
	# 🌟 NOVO: Dispara o popup textual correto no lugar do número antigo
	_trigger_enemy_damage_popup_text(combat_outcome, element)
	
	_flash_enemy_color(element)
	_trigger_enemy_shake(10.0)
	
	# Roda a State-Based Action para verificar mortes antes de avançar o turno
	_run_state_based_actions()
	
	if current_state == CombatState.HERO_TURN:
		_finish_current_hero_turn()

# Substitua inteiramente a função execute_hero_skill(skill: SkillData) por esta:

## Executes a hero skill, manages HP/MP costs, calculates damage, and targets status effects dynamically.
func execute_hero_skill(skill: SkillData) -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
	input_blocked = true
	
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_hero(hero_id)
	
	# --- 🧠 SMT SYSTEM: COST CALCULATION & VALIDATION ---
	if skill.element_type == "PHYSICAL":
		var hp_cost: int = int(hero_state.get_max_hp() * (skill.mp_cost / 100.0))
		if hero_state.current_hp <= hp_cost:
			print("❌ [Combat] %s doesn't have enough HP to use %s! Cost: %d HP" % [hero_state.blueprint.character_name, skill.name, hp_cost])
			input_blocked = false 
			return
		hero_state.modify_hp(-hp_cost)
		print("🩸 [Combat] %s paid %d HP to cast %s." % [hero_state.blueprint.character_name, hp_cost, skill.name])
		_update_hero_ui_display(hero_id)
	else:
		if hero_state.current_mp < skill.mp_cost:
			print("❌ [Combat] %s doesn't have enough MP to use %s! Needs: %d MP" % [hero_state.blueprint.character_name, skill.name, skill.mp_cost])
			input_blocked = false
			return
		hero_state.modify_mp(-skill.mp_cost)
		print("🔮 [Combat] %s paid %d MP to cast %s." % [hero_state.blueprint.character_name, skill.mp_cost, skill.name])
		_update_hero_ui_display(hero_id)
	# ----------------------------------------------------
	
	if skill.sound_cast:
		AudioManager.play_sfx(skill.sound_cast)
	
	var damage_base: int = int(hero_state.get_attack() * skill.damage_multiplier)
	
	# 🌟 CORRIGIDO: Captura o resultado textual da rolagem oculta vinda do EnemyState
	var combat_outcome: String = spawned_enemy.receive_combat_damage(damage_base, skill.element_type)
	
	# 🌟 NOVO: Instancia e dispara a label por palavra (Weakness!, Resist!, Hit!, Miss!) na cabeça do monstro
	_trigger_enemy_damage_popup_text(combat_outcome, skill.element_type)
	
	# 🎯 MODULAR STATUS EFFECT TARGETING SYSTEM (Só aplica status se o ataque não deu "Miss!" ou "Immune!")
	if combat_outcome != "Miss!" and combat_outcome != "Immune!" and skill.status_to_apply and randf() <= skill.status_chance:
		var duration = skill.status_to_apply.default_duration
		
		match skill.target_type:
			SkillData.TargetType.ENEMY:
				if spawned_enemy.has_method("apply_status"):
					spawned_enemy.apply_status(skill.status_to_apply, duration)
				
			SkillData.TargetType.ALLY_ALL:
				for p_id in active_party_ids:
					var member = PlayerData.get_hero(p_id)
					if member and member.has_method("apply_status"):
						member.apply_status(skill.status_to_apply, duration)
						
			SkillData.TargetType.EVERYONE:
				if spawned_enemy.has_method("apply_status"):
					spawned_enemy.apply_status(skill.status_to_apply, duration)
				for p_id in active_party_ids:
					var member = PlayerData.get_hero(p_id)
					if member and member.has_method("apply_status"):
						member.apply_status(skill.status_to_apply, duration)
			
			SkillData.TargetType.SELF:
				if hero_state.has_method("apply_status"):
					hero_state.apply_status(skill.status_to_apply, duration)

	_flash_enemy_color(skill.element_type)
	_trigger_enemy_shake(10.0)
	
	if skill.sound_impact:
		AudioManager.play_sfx(skill.sound_impact)
		
	_run_state_based_actions()
	
	if current_state == CombatState.HERO_TURN:
		_finish_current_hero_turn()

## Executa a cura em um único herói selecionado via menu textual [8]
func execute_hero_single_heal(target_hero: HeroState, skill: SkillData) -> void:
	var caster_id = active_party_ids[current_hero_index]
	var caster_state = PlayerData.get_hero(caster_id)
	
	# Cobra o custo de MP do conjurador
	caster_state.modify_mp(-skill.mp_cost)
	_update_hero_ui_display(caster_id)
	
	# Calcula o valor da cura baseado no ataque/magia do herói
	var heal_amount: int = int(caster_state.get_attack() * skill.damage_multiplier)
	target_hero.modify_hp(heal_amount) # Aplica a cura
	
	print("💚 [Combat] %s healed %s for %d HP." % [caster_state.blueprint.character_name, target_hero.blueprint.character_name, heal_amount])
	
	# Dispara o pop-up de cura (usando a mesma cena monocromática com texto adaptado)
	_trigger_damage_popup(target_hero.blueprint.id, heal_amount, "HEAL") 
	_update_hero_ui_display(target_hero.blueprint.id)
	# 🔊 2. Toca o som de impacto no momento exato do popup de dano
	if skill.sound_impact:
		AudioManager.play_sfx(skill.sound_impact)
	_finish_current_hero_turn()

## Executa a cura em toda a equipe ativa de uma vez só [8]
func execute_hero_party_heal(skill: SkillData) -> void:
	var caster_id = active_party_ids[current_hero_index]
	var caster_state = PlayerData.get_hero(caster_id)
	
	caster_state.modify_mp(-skill.mp_cost)
	_update_hero_ui_display(caster_id)
	
	var heal_amount: int = int(caster_state.get_attack() * skill.damage_multiplier)
	
	for hero_id in active_party_ids:
		var target_hero = PlayerData.get_hero(hero_id)
		if target_hero:
			target_hero.modify_hp(heal_amount)
			_trigger_damage_popup(hero_id, heal_amount, "HEAL")
			_update_hero_ui_display(hero_id)
			
	# 🔊 2. Toca o som de impacto no momento exato do popup de dano
	if skill.sound_impact:
		AudioManager.play_sfx(skill.sound_impact)
	print("💚 [Combat] %s healed the entire party for %d HP." % [caster_state.blueprint.character_name, heal_amount])
	_finish_current_hero_turn()

## Executes the enemy turn, querying the boss AI brain, and managing Single-Target, AoE, and Self actions.
func _execute_enemy_attack() -> void:
	if active_party_ids.is_empty():
		_run_state_based_actions()
		return

	# 🛡️ STUN GUARDRAIL: Check if the boss phase prevents them from acting right at turn start
	if spawned_enemy.has_method("is_stunned") and spawned_enemy.is_stunned():
		if dialogue_label:
			dialogue_label.text = "[center][color=gray]%s is incapacitated in this phase![/color][/center]" % spawned_enemy.active_blueprint.name
		# 🔓 THE RECOVERY SNAPSHOT:
		# He skipped his action for this round. We clear his stun status right now 
		# so that he can breathe and act normally on his NEXT turn cycle!
		if "is_currently_stunned" in spawned_enemy:
			spawned_enemy.is_currently_stunned = false
			print("🔓 [CombatManager] Stun Discharged: %s recovered and will act next round." % spawned_enemy.active_blueprint.name)
		
		
		
		await get_tree().create_timer(1.2).timeout
		_finish_enemy_turn()
		return
		
	# 📦 STEP 1: Pack the battle context data for the AI to read safely
	var combat_context = {
		"boss_state": spawned_enemy,
		"active_party_ids": active_party_ids.duplicate()
	}
	
	# 🧠 STEP 2: Query the specialist AI brain from the current active blueprint
	var ai_decision: Dictionary = { "skill": null, "target_id": "" }
	
	if spawned_enemy.active_blueprint and "ai_brain" in spawned_enemy.active_blueprint and spawned_enemy.active_blueprint.ai_brain:
		ai_decision = spawned_enemy.active_blueprint.ai_brain.choose_action(combat_context)
	else:
		ai_decision = { "skill": null, "target_id": active_party_ids.pick_random() }
		print("⚠️ [CombatManager] Warning: %s lacks an AI Brain resource. Using random attack." % spawned_enemy.active_blueprint.name)

	print("\n🔍 [ROBUST-DIAGNOSTIC] === INÍCIO DO ATAQUE DO INIMIGO ===")
	print("• Frame da Engine: ", Engine.get_frames_drawn())
	print("• Dicionário retornado pela IA: ", ai_decision)
	
	var used_skill: SkillData = ai_decision.get("skill")
	var target_hero_id: String = ai_decision.get("target_id")
	
	print("• used_skill extraído: ", used_skill.name if used_skill else "null (Ataque Básico)")
	print("• target_hero_id extraído: ", target_hero_id)

	var damage_base = spawned_enemy.get_attack() 
	var element = "PHYSICAL"
	var action_name = "Basic Attack"
	var target_type: SkillData.TargetType = SkillData.TargetType.ENEMY 

	if used_skill != null:
		spawned_enemy.modify_mp(-used_skill.mp_cost)
		damage_base = int(spawned_enemy.get_attack() * used_skill.damage_multiplier)
		element = used_skill.element_type
		action_name = used_skill.name
		target_type = used_skill.target_type
		if used_skill.sound_cast:
			AudioManager.play_sfx(used_skill.sound_cast)

	print("• Variáveis consolidadas -> action_name: '%s' | target_type ID: %d" % [action_name, target_type])
	print("• Estado visual ANTES do texto -> ui_dialogue_box.visible: ", ui_dialogue_box.visible if ui_dialogue_box else "null")
	print("• Estado visual ANTES do texto -> dialogue_label.visible: ", dialogue_label.visible if dialogue_label else "null")

	# Update Narrative Box based on Target Type
		# Update Narrative Box based on Target Type safely
	if dialogue_label:
		if used_skill != null and target_type == SkillData.TargetType.ALLY_ALL:
			dialogue_label.text = "[center][b]%s[/b] CASTED AOE [b]%s[/b] ON THE PARTY![/center]" % [spawned_enemy.active_blueprint.name.to_upper(), action_name.to_upper()]
		elif used_skill != null and target_type == SkillData.TargetType.SELF:
			dialogue_label.text = "[center][b]%s[/b] USED SELF SKILL [b]%s[/b]![/center]" % [spawned_enemy.active_blueprint.name.to_upper(), action_name.to_upper()]
		elif used_skill != null and target_type == SkillData.TargetType.EVERYONE:
			dialogue_label.text = "[center][b]%s[/b] UNLEASHED ULTIMATE [b]%s[/b] ON EVERYONE![/center]" % [spawned_enemy.active_blueprint.name.to_upper(), action_name.to_upper()]
		else:
			# 🛡️ THE SHIELD: Fallback safely if target_hero_id is blank or corrupted during basic attacks
			var target_name = "THE PARTY"
			
			if target_hero_id != "" and PlayerData.has_method("get_hero"):
				var target_hero = PlayerData.get_hero(target_hero_id)
				if target_hero and target_hero.blueprint:
					target_name = target_hero.blueprint.character_name.to_upper()
				else:
					# If the ID didn't exist in PlayerData, pick a live backup name safely from your active queue
					if not active_party_ids.is_empty():
						var backup_id = active_party_ids[0]
						var backup_hero = PlayerData.get_hero(backup_id)
						if backup_hero and backup_hero.blueprint:
							target_name = backup_hero.blueprint.character_name.to_upper()
			
			dialogue_label.text = "[center][b]%s[/b] USED [b]%s[/b] ON [b]%s[/b]![/center]" % [spawned_enemy.active_blueprint.name.to_upper(), action_name.to_upper(), target_name]

	print("• Texto injetado na Label: '%s'" % dialogue_label.text if dialogue_label else "null")
	print("🔍 [ROBUST-DIAGNOSTIC] === FIM DO TRATAMENTO DE TEXTO ===\n")
	await get_tree().create_timer(0.6).timeout

	# ⚔️ STEP 4: RESOLVE ACTIONS BASED ON MODULAR TARGET TYPES ⚔️
	
		# 🌟 CORRECTED INSTANT TRANSFORMATION OVERRIDE:
	if used_skill is InstantTransformationSkill:
		var transform_skill = used_skill as InstantTransformationSkill
		if transform_skill and transform_skill.target_enemy_blueprint:
			print("⚡ [CombatManager] INSTANT BLUEPRINT SWAP CAPTURED! Morfando via Skill...")
			
			if spawned_enemy:
				# 💾 HP PROTECTION CHAIN: Save his exact health before the swap
				var old_blueprint_name = spawned_enemy.active_blueprint.name
				var old_max_hp = spawned_enemy.get_max_hp()
				var old_hp = spawned_enemy.current_hp # Captures current health exactly
				
				# 🎭 Apply the mutation parameters directly
				spawned_enemy.active_blueprint = transform_skill.target_enemy_blueprint
				spawned_enemy.current_phase_id = transform_skill.target_enemy_blueprint.id
				spawned_enemy.is_currently_stunned = transform_skill.force_stun
				
				# 🛡️ THE BULLETPROOF CLAMP: Restores his HP safely bound by the new maximum
				spawned_enemy.current_hp = clamp(old_hp, 0, spawned_enemy.get_max_hp())
				
				print("🎭 [Instant Skill] === MUTAÇÃO EXECUTADA ===")
				print("   | De: %s  ──>  Para: %s" % [old_blueprint_name, spawned_enemy.active_blueprint.name])
				print("   | HP Atual Preservado Definitivamente: %d" % spawned_enemy.current_hp)
				print("   =========================================")
				
				# Emit the visual update signals to instantly repaint your mobile HUD
				spawned_enemy.hp_changed.emit(spawned_enemy.current_hp, spawned_enemy.get_max_hp(), 0)
				spawned_enemy.phase_changed.emit(spawned_enemy.active_blueprint.id)
			
			# Play screen juicing animations
			_trigger_screen_flash(element)
			_trigger_screen_shake(20.0)
			
			# Exit the turn cleanly right here
			await get_tree().create_timer(1.2).timeout
			_finish_enemy_turn()
			return

	# SCENARIO A: SELF SKILL (The Boss targets themselves / original implementation updated with ENUM reference)
	if used_skill != null and target_type == SkillData.TargetType.SELF:
		if element == "HEAL":
			var heal_amount = int(spawned_enemy.get_attack() * used_skill.damage_multiplier)
			spawned_enemy.current_hp += heal_amount 
			_trigger_enemy_damage_popup(heal_amount, "HEAL")
		
		if used_skill.status_to_apply:
			var duration = used_skill.status_to_apply.default_duration
			if spawned_enemy.has_method("apply_status"):
				spawned_enemy.apply_status(used_skill.status_to_apply, duration)
				
		_trigger_screen_flash(element)

	# SCENARIO B: AREA OF EFFECT (AoE attack hitting the entire live party)
	elif used_skill != null and target_type == SkillData.TargetType.ALLY_ALL:
		_trigger_screen_flash(element)
		_trigger_screen_shake(18.0)
		
		var current_squad = active_party_ids.duplicate()
		for hero_id in current_squad:
			var target_hero = PlayerData.get_hero(hero_id)
			if target_hero and target_hero.current_hp > 0:
				var hero_outcome: String = target_hero.take_damage_combat(damage_base, element)
				
				_trigger_hero_damage_popup_text(hero_id, hero_outcome, element)
				_update_hero_ui_display(hero_id)
				
				if target_hero.current_hp <= 0 and hero_outcome != "Miss!":
					var idx = active_party_ids.find(hero_id)
					if idx != -1: active_party_ids.remove_at(idx)

	# SCENARIO C: EVERYONE (Hits all live heroes AND executes boss-side modifications / filters)
	elif used_skill != null and target_type == SkillData.TargetType.EVERYONE:
		_trigger_screen_flash(element)
		_trigger_screen_shake(20.0)
		
		if used_skill.status_to_apply and spawned_enemy.has_method("apply_status"):
			var duration = used_skill.status_to_apply.default_duration
			spawned_enemy.apply_status(used_skill.status_to_apply, duration)
			
		var current_squad = active_party_ids.duplicate()
		for hero_id in current_squad:
			var target_hero = PlayerData.get_hero(hero_id)
			if target_hero and target_hero.current_hp > 0:
				var hero_outcome: String = target_hero.take_damage_combat(damage_base, element)
				
				_trigger_hero_damage_popup_text(hero_id, hero_outcome, element)
				_update_hero_ui_display(hero_id)
				
				if target_hero.current_hp <= 0 and hero_outcome != "Miss!":
					var idx = active_party_ids.find(hero_id)
					if idx != -1: active_party_ids.remove_at(idx)

	# SCENARIO D: CLASSIC SINGLE TARGET (Fallback path for ENEMY, ALLY_SINGLE, or basic strikes)
	else:
		if target_hero_id == "" or not active_party_ids.has(target_hero_id):
			target_hero_id = active_party_ids.pick_random()
			
		var target_hero = PlayerData.get_hero(target_hero_id)
		if target_hero and target_hero.current_hp > 0:
			var hero_outcome: String = target_hero.take_damage_combat(damage_base, element)
			
			_trigger_hero_damage_popup_text(target_hero_id, hero_outcome, element)
			_trigger_screen_flash(element)
			_trigger_screen_shake(15.0)
			_update_hero_ui_display(target_hero_id)
			
			if target_hero.current_hp <= 0 and hero_outcome != "Miss!":
				var dead_idx = active_party_ids.find(target_hero_id)
				if dead_idx != -1: active_party_ids.remove_at(dead_idx)

	if used_skill != null and used_skill.sound_impact:
		AudioManager.play_sfx(used_skill.sound_impact)

	# 1. ⚔️ RESOLVE REACTION DATA SEQUENCES:
	# Forces state-based checks to run immediately right after the damage is processed.
	_run_state_based_actions()
	
	# 2. 🛑 MID-TURN TURN SKIP INTERCEPTION:
	# If the reaction from your custom triggers mutated the boss into an incapacitated / stunned phase
	# mid-execution, we safely hijack the thread, show an alert text box, and exit to avoid animation stalls.
	if spawned_enemy.has_method("is_stunned") and spawned_enemy.is_stunned():
		print("🚨 [CombatManager] Stun Break Active: Turn cut short by phase collapse.")
		if dialogue_label:
			dialogue_label.text = "[center][b][color=orange]⚠️ FORCE BREAK: %s collapsed from exhaustion! Turn Interrupted! ⚠️[/color][/b][/center]" % spawned_enemy.active_blueprint.name.to_upper()
		
		await get_tree().create_timer(1.8).timeout
		_finish_enemy_turn()
		return

	# Pacing wait window for regular actions
	await get_tree().create_timer(1.5).timeout 
	
	if current_state == CombatState.ENEMY_TURN:
		_finish_enemy_turn()

func _run_state_based_actions() -> void:
	# Guarda o estado original para saber se mudou
	var original_state = current_state
	current_state = CombatState.CHECKING_SBA
	
	# Condição de Vitória: Inimigo com 0 ou menos de HP
	if spawned_enemy and spawned_enemy.current_hp <= 0:
		current_state = CombatState.VICTORY
		_on_combat_settled(true)
		return
		
	# Condição de Derrota: Equipe ativa totalmente vazia
	if active_party_ids.is_empty():
		current_state = CombatState.DEFEAT
		_on_combat_settled(false)
		return
		
	# 🌟 O TOQUE DE MESTRE DO DESIGN (SBA SYSTEM)
	# Antes de devolver o fluxo para os turnos, a SBA força o monstro a reavaliar a mesa.
	# Enviamos a lista de quem sobrou vivo para que o 'TriggerHeroDeath' possa julgar em tempo real!
	if spawned_enemy:
		var context = {
			"active_party_ids": active_party_ids.duplicate()
		}
		# O próprio EnemyState vai processar os gatilhos, detectar a ausência da Altria
		# e disparar o rito de transformação (VFX, troca de sprite e diálogo) imediatamente!
		spawned_enemy.evaluate_triggers("on_damage", context)
		
	# Se ninguém ganhou ou perdeu o jogo por completo, devolve o estado para o fluxo continuar de onde parou
	current_state = original_state
	
## Executa o encerramento da cena de forma estrita e isolada
func _on_combat_settled(victory: bool) -> void:
	input_blocked = true
	
	if ui_command_buttons: 
		ui_command_buttons.visible = false
	if ui_dialogue_box:
		ui_dialogue_box.visible = false
		
	AudioManager.stop_bgm(0.4)
	print("🏁 [SBA System] Combat strictly settled. Victory: ", victory)
	
	if victory and enemy_sprite:
		print("💀 [CombatManager] Iniciando esmaecimento do Boss...")
		await _animate_enemy_defeat()
		print("💀 [CombatManager] Animação concluída.")

	# Notifica a MainController para desinstanciar o combate
	combat_finished.emit(victory)


func _on_enemy_hp_changed(new_hp: int, max_hp: int, _change: int) -> void:
	if enemy_hp_bar:
		var tween = create_tween().set_parallel(true)
		# Sincroniza o novo valor máximo trazido pelo clamp da nova fase
		tween.tween_property(enemy_hp_bar, "max_value", max_hp, 0.1)
		tween.tween_property(enemy_hp_bar, "value", new_hp, 0.45)

func _update_active_party_list() -> void:
	active_party_ids.clear()
	
	# Limpa qualquer cartão que sobrou de lutas anteriores no contêiner
	if ui_heroes_container:
		for child in ui_heroes_container.get_children():
			child.queue_free()
	
	# Varre os heróis ativos do PlayerData
	for hero_id in PlayerData.active_party:
		var hero_state = PlayerData.get_hero(hero_id)
		# --- CONTINUAÇÃO DA FUNÇÃO _update_active_party_list ---
		if hero_state and hero_state.current_hp > 0:
			active_party_ids.append(hero_id)
			
			# INSTANCIAÇÃO DINÂMICA: Cria o cartão na hora!
			if hero_status_card_prefab and ui_heroes_container:
				var new_card = hero_status_card_prefab.instantiate()
				new_card.name = hero_id # Define o nome do nó como o ID (ex: "hero_01")
				ui_heroes_container.add_child(new_card)

func _manage_ui_highlight(hero_id: String) -> void:
	if not ui_heroes_container: return
	for card in ui_heroes_container.get_children():
		if card.has_method("animar_selecao"):
			card.animar_selecao(card.name == hero_id)

func _update_hero_ui_display(hero_id: String) -> void:
	if not ui_heroes_container: return
	var hero_card = ui_heroes_container.get_node_or_null(hero_id)
	if hero_card and hero_card.has_method("configurar_card"):
		var hero_state = PlayerData.get_hero(hero_id)
		if hero_state: 
			hero_card.configurar_card(hero_state)

func _trigger_enemy_damage_popup(damage_amount: int, _element_type: String) -> void:
	if not damage_popup_scene or not enemy_sprite: return
	var popup = damage_popup_scene.instantiate() as Label
	popup.text = str(damage_amount)
	add_child(popup)
	popup.global_position = enemy_sprite.global_position + Vector2(enemy_sprite.size.x / 2, -30)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - 40, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup.queue_free)
# Dentro de combat_manager.gd

## Cria o popup de texto puro (Miss!, Hit!, Critical Hit!, Resist!, Immune!) perto do monstro
func _trigger_enemy_damage_popup_text(outcome_text: String, _element_type: String) -> void:
	if not damage_popup_scene or not enemy_sprite: return
	
	var popup = damage_popup_scene.instantiate() as Label
	popup.text = outcome_text 
	add_child(popup)
	
	# 🛡️ SEGURANÇA VISUAL: Força o popup a renderizar na frente de qualquer outra imagem ou Sprite!
	popup.top_level = true
	
	popup.global_position = enemy_sprite.global_position + Vector2(enemy_sprite.size.x / 2, -30)
	
	match outcome_text:
		"Miss!":
			popup.modulate = Color(0.6, 0.6, 0.6) 
		"Immune!":
			popup.modulate = Color(0.4, 0.4, 0.5) 
		"Resist!":
			popup.modulate = Color(0.5, 0.7, 1.0) 
		"Critical Hit!":
			popup.modulate = Color(1.0, 0.9, 0.1) 
		"Weakness!":
			popup.modulate = Color(1.0, 0.4, 0.1) 
		_:
			popup.modulate = Color.WHITE 
			
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - 50, 0.7)
	tween.tween_property(popup, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(popup.queue_free)
func _trigger_damage_popup(target_id: String, damage_amount: int, _element_type: String) -> void:
	if not damage_popup_scene: return
	var popup = damage_popup_scene.instantiate() as Label
	popup.text = str(damage_amount)
	add_child(popup)
	
	var hero_ui_node = ui_heroes_container.get_node_or_null(target_id)
	popup.global_position = hero_ui_node.global_position + Vector2(50, -20) if hero_ui_node else get_viewport().get_visible_rect().size / 2
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - 40, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup.queue_free)
	
# --- FUNÇÕES DE JUICE VISUAL (TWEEN DE CORES) ---

# Faz o sprite do inimigo mudar de cor ao receber dano do jogador
func _flash_enemy_color(element_type: String) -> void:
	if not enemy_sprite: return
	var target_color = ENEMY_FLASH_COLORS.get(element_type, Color(1.5, 1.5, 1.5, 1.0))
	var tween = create_tween()
	enemy_sprite.modulate = target_color
	tween.tween_property(enemy_sprite, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Faz o Card de Status do Herói dar um Flash Intenso ao receber o golpe do monstro
func _flash_hero_card_color(hero_id: String, element_type: String) -> void:
	if not ui_heroes_container: return
	var hero_card = ui_heroes_container.get_node_or_null(hero_id)
	
	if hero_card:
		# 1. Resgata a cor original base do herói (SMT Style)
		var hero_state = PlayerData.get_hero(hero_id)
		var original_color = Color.WHITE
		if hero_state and hero_state.blueprint and "theme_color" in hero_state.blueprint:
			original_color = hero_state.blueprint.theme_color
		
		# 2. 🛡️ SE JÁ EXISTIR UM TWEEN RODANDO NESSE HERÓI, MATA ELE IMEDIATAMENTE!
		if _active_hero_flash_tweens.has(hero_id) and _active_hero_flash_tweens[hero_id] is Tween:
			if _active_hero_flash_tweens[hero_id].is_valid():
				_active_hero_flash_tweens[hero_id].kill() # Interrompe o processo duplicado
		
		# 3. Cria o novo gerenciador de interpolação
		var tween = create_tween()
		_active_hero_flash_tweens[hero_id] = tween
		
		# 4. Define a cor estourada do elemento
		var target_color = ELEMENT_COLORS.get(element_type, Color(1.5, 1.5, 1.5, 1.0))
		
		# ⚡ FRAME ZERO: Força o card a assumir o brilho elemental puro
		hero_card.modulate = target_color
		
		# ⏳ 1 SEGUNDO: Esmaece de volta para a identidade visual exata do personagem
		tween.tween_property(hero_card, "modulate", original_color, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# 🔒 GARANTIA: Remove a referência do dicionário quando a animação concluir com sucesso
		tween.tween_callback(func():
			hero_card.modulate = original_color
			_active_hero_flash_tweens.erase(hero_id)
		)

## Alterna de forma segura entre a interface do jogador e o anúncio de texto
func _alternar_interface_combate(mostrar_comandos: bool, hero_id: String = "") -> void:
	# 🌟 PROTEÇÃO ARQUITETURAL: 
	# Se o jogo está estritamente no turno do inimigo, a caixa de diálogos NÃO PODE
	# ser escondida por atualizações residuais de dados ou sinais de MP/HP em background.
	if current_state == CombatState.ENEMY_TURN:
		if ui_dialogue_box: 
			ui_dialogue_box.show()
		if ui_command_buttons: 
			ui_command_buttons.hide()
		return

	# Fluxo normal para o turno dos heróis
	if mostrar_comandos:
		if ui_dialogue_box: 
			ui_dialogue_box.hide()
		if ui_command_buttons: 
			var novo_turno = (current_hero_index == 0 and not ui_dialogue_box.visible)
			ui_command_buttons.show_commands_for(hero_id, novo_turno)
	else:
		if ui_dialogue_box: 
			ui_dialogue_box.show()

# Faz a tela mobile inteira piscar com a cor do elemento do ataque recebido
func _trigger_screen_flash(element_type: String) -> void:
	if not screen_flash_effect: return
	var flash_color = SCREEN_FLASH_COLORS.get(element_type, Color(1, 1, 1, 0.4))
	
	var tween = create_tween()
	screen_flash_effect.color = flash_color
	
	var transparent_color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	tween.tween_property(screen_flash_effect, "color", transparent_color, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Sacode o container de arte visual em primeira pessoa (Monstro + Background)
func _trigger_screen_shake(intensity: float) -> void:
	if not visual_area_node: return
	var original_pos = _visual_area_original_position
	
	var tween = create_tween().set_loops(4)
	var offset_1 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	var offset_2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	
	tween.tween_property(visual_area_node, "position", original_pos + offset_1, 0.02)
	tween.tween_property(visual_area_node, "position", original_pos + offset_2, 0.02)
	tween.chain().tween_property(visual_area_node, "position", original_pos, 0.04)

# Sacode especificamente o sprite do monstro quando ele recebe um golpe do jogador
func _trigger_enemy_shake(intensity: float) -> void:
	if not enemy_sprite: return
	
	# No Godot, para nós de Control dentro de containers, usamos 'position' ou 'offset' 
	# Como o seu EnemySprite é um TextureRect, vamos mexer temporariamente no seu offset de posição
	var original_pos = enemy_sprite.position
	
	var tween = create_tween().set_loops(4) # Repete o balanço rápido 4 vezes
	var offset_1 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	var offset_2 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	
	tween.tween_property(enemy_sprite, "position", original_pos + offset_1, 0.02)
	tween.tween_property(enemy_sprite, "position", original_pos + offset_2, 0.02)
	
	# Garante que o monstro volta exatamente para o seu lugar de origem no layout
	tween.chain().tween_property(enemy_sprite, "position", original_pos, 0.04)
## Anima o monstro desaparecendo suavemente (Fade-out seguro em containers)
func _animate_enemy_defeat() -> void:
	if not enemy_sprite: return
	
	var tween = create_tween().set_parallel(true)
	
	# Modula a opacidade para 0 e escurece os canais RGB ao mesmo tempo
	# Funciona perfeitamente independente das amarras do MarginContainer/PanelContainer!
	tween.tween_property(enemy_sprite, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_sprite, "modulate:r", 0.0, 0.6)
	tween.tween_property(enemy_sprite, "modulate:g", 0.0, 0.6)
	tween.tween_property(enemy_sprite, "modulate:b", 0.0, 0.6)
		
	await tween.finished
	print("🎬 [Juice Visual] Inimigo totalmente invisível.")
## Executa a mudança visual do Boss quando ele sofre mutação de blueprint via BossPhaseData
func _on_enemy_phase_changed(new_blueprint_id: String) -> void:
	if not enemy_sprite or not spawned_enemy: return
	
	input_blocked = true
	enemy_sprite.texture = spawned_enemy.get_current_sprite()
	
	_flash_enemy_color("PHYSICAL")
	_trigger_enemy_shake(25.0)
	_trigger_screen_shake(15.0)
	
	if dialogue_label:
		_alternar_interface_combate(false)
		dialogue_label.text = "[center][b][color=yellow]⚠️ ADVERTÊNCIA: O INIMIGO MUDOU DE FORMA! -> %s ⚠️[/color][/b][/center]" % spawned_enemy.active_blueprint.name.to_upper()
		
		await get_tree().create_timer(1.5).timeout
		input_blocked = false
		
		if current_state == CombatState.HERO_TURN:
			var active_hero_id = active_party_ids[current_hero_index]
			# 🌟 O FALSE AQUI impede o menu de resetar na mudança de fase do Boss
			_alternar_interface_combate(true, active_hero_id)

## Clears and reconstructs status effect icons for the Boss on the main HUD
func _update_enemy_status_icons() -> void:
	if not enemy_status_icons_container or not spawned_enemy:
		return
		
	# Clear previous enemy icons safely
	for child in enemy_status_icons_container.get_children():
		child.queue_free()
		
	# Instantiates a TextureRect for each active resource effect on the monster
	for effect in spawned_enemy.active_status.keys():
		if effect and effect.icon:
			var texture_rect = TextureRect.new()
			texture_rect.texture = effect.icon
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# 📱 Friendly size for the boss display (slightly bigger than heroes)
			texture_rect.custom_minimum_size = Vector2(28, 28) 
			
			# Visual cue: tint it slightly purple or green if it's a poison/debuff on the enemy
			if "is_debuff" in effect and effect.is_debuff:
				texture_rect.modulate = Color(0.8, 0.5, 1.0) # Tom arroxeado para debuffs aplicados no Boss
				
			enemy_status_icons_container.add_child(texture_rect)
## Executa a aplicação de um buff/status em um único herói selecionado via clique no card
func execute_hero_single_support(target_hero: HeroState, skill: SkillData) -> void:
	var caster_id = active_party_ids[current_hero_index]
	var caster_state = PlayerData.get_hero(caster_id)
	
	# Cobra o custo de MP do conjurador (assim como na sua cura)
	caster_state.modify_mp(-skill.mp_cost)
	_update_hero_ui_display(caster_id)
	
	# 🌟 NOVO & MODULAR: Aplica o status effect diretamente no herói alvo clicado
	if skill.status_to_apply and target_hero.has_method("apply_status"):
		# Injeta o resource (.tres) e a duração vinda do SkillData
		target_hero.apply_status(skill.status_to_apply, skill.status_duration)
	
	print("🔮 [Combat] %s applied %s to %s for %d turns." % [
		caster_state.blueprint.character_name, 
		skill.name, 
		target_hero.blueprint.character_name, 
		skill.status_duration
	])
	
	# Mostra o popup flutuante de texto (ex: adaptando a label para o nome do buff se quiser)
	_trigger_damage_popup(target_hero.blueprint.id, 0, "SUPPORT") 
	
	# Força o card do herói alvo a se redesenhar (o que já vai instanciar o novo ícone no ContentLayout!)
	_update_hero_ui_display(target_hero.blueprint.id)
	
	if skill.sound_impact:
		AudioManager.play_sfx(skill.sound_impact)
		
	# Finaliza o turno do herói atual de forma limpa
	_finish_current_hero_turn()
## ✅ PONTE DE SEGURANÇA: Direciona o clique do menu para a cura antiga ou o novo sistema de status
func execute_hero_single_ally_action(target_hero: HeroState, skill: SkillData) -> void:
	# 1. Se for uma magia de cura tradicional, roda o seu código antigo e original!
	if skill.element_type == "HEAL":
		execute_hero_single_heal(target_hero, skill)
		return
		
	# 2. Se for uma habilidade com o novo sistema de status (Buffs, Suportes, Proteções)
	var caster_id = active_party_ids[current_hero_index]
	var caster_state = PlayerData.get_hero(caster_id)
	
	# Cobra o custo de MP do conjurador
	caster_state.modify_mp(-skill.mp_cost)
	_update_hero_ui_display(caster_id)
	
	# Aplica o status effect modular de forma segura
	if skill.status_to_apply and target_hero.has_method("apply_status"):
	# 🌟 AJUSTE AQUI: Lê do default_duration do Resource
		var duration = skill.status_to_apply.default_duration
		target_hero.apply_status(skill.status_to_apply, duration)
	
		print("🔮 [Support] %s applied %s to %s for %d turns." % [
	caster_state.blueprint.character_name, 
	skill.name, 
	target_hero.blueprint.character_name, # 👈 O nome do herói entra no terceiro %s
	duration                              # 👈 A duração numérica entra no %d
])
	
	# Dispara efeitos visuais e sonoros na UI mobile
	_trigger_damage_popup(target_hero.blueprint.id, 0, "SUPPORT") 
	_update_hero_ui_display(target_hero.blueprint.id)
	
	if skill.sound_impact:
		AudioManager.play_sfx(skill.sound_impact)
		
	# Passa o turno de forma regulamentar
	_finish_current_hero_turn()
## 🌟 NOVO: Cria o popup de texto puro (Miss!, Hit!, Weakness!) em cima do card do herói alvejado
func _trigger_hero_damage_popup_text(target_id: String, outcome_text: String, _element_type: String) -> void:
	if not damage_popup_scene: return
	
	var popup = damage_popup_scene.instantiate() as Label
	popup.text = outcome_text # Injeta a palavra mágica
	add_child(popup)
	
	var hero_ui_node = ui_heroes_container.get_node_or_null(target_id)
	popup.global_position = hero_ui_node.global_position + Vector2(50, -20) if hero_ui_node else get_viewport().get_visible_rect().size / 2
	
	# Cores combinando com o padrão do monstro para o mobile
	match outcome_text:
		"Miss!":
			popup.modulate = Color(0.6, 0.6, 0.6)
		"Immune!":
			popup.modulate = Color(0.4, 0.4, 0.5)
		"Resist!":
			popup.modulate = Color(0.5, 0.7, 1.0)
		"Critical Hit!":
			popup.modulate = Color(1.0, 0.9, 0.1)
		"Weakness!":
			popup.modulate = Color(1.0, 0.4, 0.1) # Cor de alerta para fraqueza atingida no herói!
		_:
			popup.modulate = Color.WHITE
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - 40, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup.queue_free)
