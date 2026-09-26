extends Node
class_name CombatManager

# O sinal que a MainController vai escutar para desinstanciar o combate
signal combat_finished(victory: bool)

# CHECKING_SBA impede que qualquer herói avance ou ataque enquanto processamos mortes
enum CombatState { INITIALIZING, HERO_TURN, ENEMY_TURN, CHECKING_SBA, VICTORY, DEFEAT }

@export var damage_popup_scene: PackedScene 

# 📦 Arraste o seu 'HeroStatusCard.tscn' aqui pelo painel Inspector!
@export var hero_status_card_prefab: PackedScene 

var current_state: CombatState = CombatState.INITIALIZING
var combat_data: CombatData
var spawned_enemy: EnemyState

var active_party_ids: Array[String] = []
var current_hero_index: int = 0
var input_blocked: bool = false

@export_group("Componentes de UI")
@export var enemy_sprite: TextureRect
@export var background_texture: TextureRect
@export var ui_heroes_container: VBoxContainer  
@export var ui_command_buttons: Control         
@export var ui_skill_announcer: Control         
@export var enemy_hp_bar: ProgressBar           

## Injeção de Dependência: A Main vai chamar esta função passando os dados do monstro!
func initialize_combat(data: CombatData) -> void:
	combat_data = data
	current_state = CombatState.INITIALIZING
	input_blocked = false
	current_hero_index = 0 
	
	if ui_skill_announcer:
		ui_skill_announcer.hide()
	
	if background_texture and combat_data.background:
		background_texture.texture = combat_data.background
	
	spawned_enemy = EnemyState.new()
	spawned_enemy.initialize(combat_data.enemy)
	enemy_sprite.texture = spawned_enemy.blueprint.combat_sprite
	spawned_enemy.hp_changed.connect(_on_enemy_hp_changed)
	
	if enemy_hp_bar:
		enemy_hp_bar.max_value = spawned_enemy.get_max_hp()
		enemy_hp_bar.value = spawned_enemy.current_hp
	
	# 1. Filtra a equipe viva e instancia os nós dos cartões na árvore (PartyContainer)
	_update_active_party_list()
	
	# 2. ATUALIZAÇÃO VISUAL: Garante que cada cartão instanciado desenhe o texto de HP e Nível!
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
	
	_manage_ui_highlight(hero_id)
	input_blocked = false
	ui_command_buttons.show_commands_for(hero_id)

func _finish_current_hero_turn() -> void:
	input_blocked = true
	current_hero_index += 1 
	await get_tree().create_timer(0.4).timeout
	_next_hero_turn()

func _start_enemy_turn() -> void:
	current_state = CombatState.ENEMY_TURN
	if ui_command_buttons: ui_command_buttons.hide_commands()
	await get_tree().create_timer(0.4).timeout
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
	
	var damage_base: int = int(hero_state.get_attack() * skill.damage_multiplier)
	spawned_enemy.receive_combat_damage(damage_base, skill.element_type)
	_trigger_enemy_damage_popup(damage_base, skill.element_type)
	
	_run_state_based_actions()
	
	if current_state == CombatState.HERO_TURN:
		_finish_current_hero_turn()

func _execute_enemy_attack() -> void:
	if active_party_ids.is_empty():
		_run_state_based_actions()
		return
		
	var random_index: int = randi() % active_party_ids.size()
	var target_hero_id: String = active_party_ids[random_index]
	var target_hero = PlayerData.get_hero(target_hero_id)
	
	if not target_hero or target_hero.current_hp <= 0:
		_finish_enemy_turn()
		return
		
	var damage_dealt = spawned_enemy.get_attack()
	target_hero.take_damage_combat(damage_dealt, "PHYSICAL")
	
	_trigger_damage_popup(target_hero_id, damage_dealt, "PHYSICAL")
	_update_hero_ui_display(target_hero_id)
	
	if target_hero.current_hp <= 0:
		active_party_ids.remove_at(random_index)
	
	_run_state_based_actions()
	
	if current_state == CombatState.ENEMY_TURN:
		_finish_enemy_turn()

# --- 🃏 STATE-BASED ACTIONS (ESTILO MTG) ---

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
func _on_combat_settled(victory: bool) -> void:
	input_blocked = true
	if ui_command_buttons: 
		ui_command_buttons.hide_commands()
		
	print("🏁 [SBA System] Combat strictly settled. Victory: ", victory)
	combat_finished.emit(victory)

# --- SISTEMAS DE UI ---

func _on_enemy_hp_changed(new_hp: int, _max_hp: int, _change: int) -> void:
	if enemy_hp_bar:
		var tween = create_tween()
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
		if hero_state: hero_card.configurar_card(hero_state)

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
