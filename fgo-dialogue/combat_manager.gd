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
	spawned_enemy.hp_changed.connect(_on_enemy_hp_changed)
	# Escuta as transformações para rodar VFX na UI Mobile
	spawned_enemy.phase_changed.connect(_on_enemy_phase_changed)
	
	if enemy_hp_bar:
		enemy_hp_bar.max_value = spawned_enemy.get_max_hp()
		enemy_hp_bar.value = spawned_enemy.current_hp
		
	if ui_dialogue_box: 
		ui_dialogue_box.hide()
		
	_update_active_party_list()
	
	# 🚨 NOVO: Checagem de "Frame Zero" passando a party ativa para os gatilhos do BossPhaseData
	var initial_context = {"active_party_ids": active_party_ids}
	spawned_enemy.evaluate_triggers("on_combat_start", initial_context)
	
	for hero_id in active_party_ids:
		_update_hero_ui_display(hero_id)
		
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
	
	# ⏳ [NOVO] PROCESSA OS STATUS DO HERÓI NO INÍCIO DO TURNO DELE
	# Se ele tiver um veneno, toma dano aqui. Se tiver passiva de MP (como o tanque híbrido), regenera aqui!
	if hero_state:
		_processar_passivas_e_status_inicio_heroi(hero_id, hero_state)
		
	_manage_ui_highlight(hero_id)
	input_blocked = false
	_alternar_interface_combate(true, hero_id)
func _processar_passivas_e_status_inicio_heroi(hero_id: String, hero_state: HeroState) -> void:
	# 1. Roda o decréscimo natural de buffs/debuffs
	hero_state.tick_status() 
	
	# 2. [EXEMPLO DE DESIGN] Passiva do Tanque Híbrido: Regenerar MP de todos no início do turno
	if hero_state.blueprint.passive_id == "PARTY_MANA_REGEN" and hero_state.current_hp > (hero_state.get_max_hp() * 0.5):
		for p_id in active_party_ids:
			var member = PlayerData.get_hero(p_id)
			if member:
				member.modify_mp(5)
				_update_hero_ui_display(p_id)
		print("🔮 Passiva Ativada: Regenerado 5 MP para a equipe!")
		
	# 3. Garante que qualquer alteração de barra seja redesenhada na UI mobile
	_update_hero_ui_display(hero_id)

func _finish_current_hero_turn() -> void:
	input_blocked = true
	current_hero_index += 1 
	await get_tree().create_timer(0.4).timeout
	_next_hero_turn()

func _start_enemy_turn() -> void:
	current_state = CombatState.ENEMY_TURN
	_alternar_interface_combate(false)
	
	# ⏳ [NOVO] PROCESSA OS STATUS DO INIMIGO NO INÍCIO DO TURNO DELE
	if spawned_enemy and spawned_enemy.has_method("tick_status"):
		spawned_enemy.tick_status() # Diminui os turnos de buffs/debuffs dele
		# Aqui você também pode aplicar dano de veneno se o inimigo tiver
	
	if ui_dialogue_box:
		var label = ui_dialogue_box.get_node_or_null("DialogueLabel") as RichTextLabel
		if label: 
			label.text = "[center]Turno do Inimigo...[/center]"
		
	await get_tree().create_timer(0.6).timeout
	_execute_enemy_attack()
	
func _finish_enemy_turn() -> void:
	current_hero_index = 0
	_next_hero_turn()

# --- AÇÕES DE ATAQUE ---

func execute_hero_basic_attack() -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
	input_blocked = true
	
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_hero(hero_id)
	
	var damage_dealt: int = hero_state.get_attack()
	var element: String = "PHYSICAL"
	
	# 1. Aplica as alterações numéricas brutas
	spawned_enemy.receive_combat_damage(damage_dealt, element)
	_trigger_enemy_damage_popup(damage_dealt, element)
	
	_flash_enemy_color(element)
	_trigger_enemy_shake(10.0)
	# 2. Roda a State-Based Action para verificar mortes ANTES de avançar o turno
	_run_state_based_actions()
	
	# 3. Só continua o fluxo normal se a SBA não tiver decretado fim de jogo
	if current_state == CombatState.HERO_TURN:
		_finish_current_hero_turn()

func execute_hero_skill(skill: SkillData) -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
	input_blocked = true
	
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_hero(hero_id)
	
	# --- 🧠 SMT SYSTEM: CÁLCULO E VALIDAÇÃO DE CUSTOS ---
	if skill.element_type == "PHYSICAL":
		# Skills físicas custam uma porcentagem do HP Máximo (ex: mp_cost = 15 significa 15% do Max HP)
		var hp_cost: int = int(hero_state.get_max_hp() * (skill.mp_cost / 100.0))
		
		# Regra de SMT: Você precisa ter mais HP do que o custo exige para conjurar (não pode se matar pagando custo)
		if hero_state.current_hp <= hp_cost:
			print("❌ [Combat] %s doesn't have enough HP to use %s! Cost: %d HP" % [hero_state.blueprint.character_name, skill.name, hp_cost])
			input_blocked = false # Libera a UI para o jogador escolher outra coisa
			return
			
		# Paga o custo em HP
		hero_state.modify_hp(-hp_cost)
		print("🩸 [Combat] %s paid %d HP to cast %s." % [hero_state.blueprint.character_name, hp_cost, skill.name])
		_update_hero_ui_display(hero_id) # Atualiza a barrinha de HP do herói na tela imediatamente
		
	else:
		# Habilidades mágicas (Agi, Bufu, Zio) custam MP fixo comum
		if hero_state.current_mp < skill.mp_cost:
			print("❌ [Combat] %s doesn't have enough MP to use %s! Needs: %d MP" % [hero_state.blueprint.character_name, skill.name, skill.mp_cost])
			input_blocked = false
			return
			
		# Paga o custo em MP
		hero_state.modify_mp(-skill.mp_cost)
		print("🔮 [Combat] %s paid %d MP to cast %s." % [hero_state.blueprint.character_name, skill.mp_cost, skill.name])
		_update_hero_ui_display(hero_id) # Atualiza o status na tela
	# ----------------------------------------------------
	# 🔊 1. Toca o som de conjuração se ele existir
	if skill.sound_cast:
		AudioManager.play_sfx(skill.sound_cast)
	
	# Executa o rito de dano normal contra o monstro
	var damage_base: int = int(hero_state.get_attack() * skill.damage_multiplier)
	
	# 🔥 [NOVO] SISTEMA DE COMBO DE STATUS (Estilo Monster Hunter)
	# Checa se o inimigo tem o status e se a skill atual reage com ele
	if spawned_enemy.has_method("has_status"):
		if spawned_enemy.has_status("MOLHADO") and skill.element_type == "ELEC":
			damage_base = int(damage_base * 2.0) # Dano dobra!
			print("⚡ COMBO DE STATUS: Choque em alvo molhado causou o dobro de dano!")
			
		elif spawned_enemy.has_status("EXAUTO") and skill.element_type == "PHYSICAL":
			damage_base = int(damage_base * 1.5) # Bate mais forte em alvo caído
			print("💥 IMPACTO: Dano extra em inimigo exausto!")

	# Executa o rito de dano normal contra o monstro
	spawned_enemy.receive_combat_damage(damage_base, skill.element_type)
	
	# ➕ [NOVO] APLICAÇÃO DE STATUS AO INIMIGO VIA SKILL (Se a habilidade tiver um efeito atrelado)
	if "status_to_apply" in skill and skill.status_to_apply != "NONE":
		if randf() <= skill.status_chance and spawned_enemy.has_method("apply_status"):
			spawned_enemy.apply_status(skill.status_to_apply, skill.status_duration)

	_trigger_enemy_damage_popup(damage_base, skill.element_type)
	_flash_enemy_color(skill.element_type)
	_trigger_enemy_shake(10.0)
	
	# 🔊 2. Toca o som de impacto no momento exato do popup de dano
	if skill.sound_impact:
		AudioManager.play_sfx(skill.sound_impact)
	_run_state_based_actions()
	
	# CORRIGIDO: Removida a duplicidade do '_finish_current_hero_turn()' que estava duplicando turnos fantasmas [9]
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

func _execute_enemy_attack() -> void:
	if active_party_ids.is_empty():
		_run_state_based_actions()
		return

	# 🛡️ TOTALMENTE GENÉRICO: O inimigo avisa se o BossPhaseData atual dele impede ações!
	if spawned_enemy.has_method("is_stunned") and spawned_enemy.is_stunned():
		if dialogue_label:
			dialogue_label.text = "[center][color=gray]%s está incapacitado na fase atual![/color][/center]" % spawned_enemy.active_blueprint.name
		await get_tree().create_timer(1.2).timeout
		_finish_enemy_turn()
		return
		
	var random_index: int = randi() % active_party_ids.size()
	var target_hero_id: String = active_party_ids[random_index]
	var target_hero = PlayerData.get_hero(target_hero_id)
	
	if not target_hero or target_hero.current_hp <= 0:
		_finish_enemy_turn()
		return

	var choice_roll = randf()
	var used_skill: SkillData = null
	
	# Puxa as habilidades exclusivas do blueprint ativo na rodada
	var available_skills = spawned_enemy.get_current_skill_list()

	if not available_skills.is_empty() and choice_roll < 0.75:
		var random_skill_id = available_skills.pick_random()
		var candidate_skill = SkillsDatabase.get_skill(random_skill_id)
		if candidate_skill and spawned_enemy.current_mp >= candidate_skill.mp_cost:
			used_skill = candidate_skill

	# Configuração dinâmica baseada na fase em runtime
	var damage_base = spawned_enemy.get_attack() 
	var element = "PHYSICAL"
	var action_name = "Ataque Básico"

	if used_skill != null:
		spawned_enemy.modify_mp(-used_skill.mp_cost)
		damage_base = int(spawned_enemy.get_attack() * used_skill.damage_multiplier)
		element = used_skill.element_type
		action_name = used_skill.name
		if used_skill.sound_cast:
			AudioManager.play_sfx(used_skill.sound_cast)

	if dialogue_label:
		dialogue_label.text = "[center][b]%s[/b]: [b]%s[/b]![/center]" % [spawned_enemy.active_blueprint.name.to_upper(), action_name.to_upper()]

	await get_tree().create_timer(0.6).timeout

	if used_skill != null:
		target_hero.take_damage_combat(damage_base, element)
	else:
		target_hero.take_damage_combat(damage_base, "PHYSICAL")
		
	_trigger_damage_popup(target_hero_id, damage_base, element)
	_trigger_screen_flash(element)
	_trigger_screen_shake(15.0)

	if used_skill != null and used_skill.sound_impact:
		AudioManager.play_sfx(used_skill.sound_impact)

	_update_hero_ui_display(target_hero_id)
	
	if target_hero.current_hp <= 0:
		active_party_ids.remove_at(random_index)

	await get_tree().create_timer(1.0).timeout 
	_run_state_based_actions()
	
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
		
	# Se ninguém morreu, devolve o estado para o fluxo continuar de onde parou
	current_state = original_state

## Executa o encerramento da cena de forma estrita e isolada
## Executa o encerramento da cena de forma estrita e isolada
func _on_combat_settled(victory: bool) -> void:
	input_blocked = true
	if ui_command_buttons: 
		ui_command_buttons.hide_commands()
		
	AudioManager.stop_bgm(0.4)
	print("🏁 [SBA System] Combat strictly settled. Victory: ", victory)
	
	# 💀 SE FOR VITÓRIA: Roda a animação de morte do monstro antes de fechar a tela!
	if victory and enemy_sprite:
		await _animate_enemy_defeat()
		
	combat_finished.emit(victory)

# --- SISTEMAS DE UI ---

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
	if mostrar_comandos:
		# Esconde a sobreposição para revelar os botões por baixo
		if ui_dialogue_box: 
			ui_dialogue_box.hide()
		if ui_command_buttons: 
			ui_command_buttons.show_commands_for(hero_id)
	else:
		# Mostra a caixa de diálogo por cima de tudo, cobrindo os botões e bloqueando cliques
		if ui_dialogue_box: 
			ui_dialogue_box.show()
# Faz o monstro piscar intensamente na tela ao tomar um golpe do jogador

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
## Anima o monstro deslizando para baixo e virando uma silhueta preta ao morrer
func _animate_enemy_defeat() -> void:
	if not enemy_sprite: return
	
	# Cria um Tween paralelo (executa movimento e cor ao mesmo tempo)
	var tween = create_tween().set_parallel(true)
	
	# 📐 Calcula o ponto final (a posição atual + a altura dele para sumir da tela)
	var target_y = enemy_sprite.position.y + enemy_sprite.size.y + 50
	
	# ⏳ Configura as duas interpolações para durarem 0.6 segundos
	# Move para baixo suavemente
	tween.tween_property(enemy_sprite, "position:y", target_y, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	# Modula para o preto absoluto (Sombra)
	tween.tween_property(enemy_sprite, "modulate", Color(0, 0, 0, 1.0), 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# Aguarda o Tween terminar completamente antes de liberar a linha de execução
	await tween.finished

## Executa a mudança visual do Boss quando ele sofre mutação de blueprint via BossPhaseData
func _on_enemy_phase_changed(new_blueprint_id: String) -> void:
	if not enemy_sprite or not spawned_enemy: return
	
	# 1. Atualiza visualmente o sprite usando o getter seguro do EnemyState
	enemy_sprite.texture = spawned_enemy.get_current_sprite()
	
	# 2. Juice Visual de Impacto (Estilo SMT/Monster Hunter)
	_flash_enemy_color("PHYSICAL") # Dá um clarão estourado HDR no monstro
	_trigger_enemy_shake(25.0)     # Sacode o monstro fortemente pelo urro da transformação
	_trigger_screen_shake(15.0)    # Faz a tela mobile inteira tremer
	
	# 3. Anúncio textual dramático na caixa de diálogos com o nome do novo EnemyData
	if dialogue_label:
		_alternar_interface_combate(false)
		dialogue_label.text = "[center][b][color=yellow]⚠️ ADVERTÊNCIA: O INIMIGO MUDOU DE FORMA! -> %s ⚠️[/color][/b][/center]" % spawned_enemy.active_blueprint.name.to_upper()
		await get_tree().create_timer(1.5).timeout
		if current_state == CombatState.HERO_TURN:
			var active_hero_id = active_party_ids[current_hero_index]
			_alternar_interface_combate(true, active_hero_id)
