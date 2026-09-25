extends Node

enum CombatState { INITIALIZING, HERO_TURN, ENEMY_TURN, VICTORY, DEFEAT }

@export var damage_popup_scene: PackedScene 

var current_state: CombatState = CombatState.INITIALIZING
var combat_data: CombatData
var spawned_enemy: EnemyState

# Rastreamento estático de turnos
var active_party_ids: Array[String] = []
var current_hero_index: int = 0
var input_blocked: bool = false

# Referências de nós da UI (Arraste todos no painel Inspetor)
@export var enemy_sprite: TextureRect
@export var background_texture: TextureRect
@export var ui_heroes_container: VBoxContainer  
@export var ui_command_buttons: Control         
@export var ui_skill_announcer: Control         # Painel contendo a Label da Skill
@export var enemy_hp_bar: ProgressBar           # Arraste o seu 'EnemyHPBar' aqui

func start_combat(data: CombatData) -> void:
	combat_data = data
	current_state = CombatState.INITIALIZING
	input_blocked = false
	current_hero_index = 0 
	
	if ui_skill_announcer:
		ui_skill_announcer.hide()
	
	if background_texture and combat_data.background:
		background_texture.texture = combat_data.background
	
	# Instancia e inicializa o monstro único
	spawned_enemy = EnemyState.new()
	spawned_enemy.inicializar(combat_data.enemy)
	enemy_sprite.texture = spawned_enemy.blueprint.sprite_combate
	
	# Conecta os sinais nativos que você criou no seu EnemyState
	spawned_enemy.morreu.connect(_on_enemy_died)
	spawned_enemy.hp_alterado.connect(_on_enemy_hp_changed)
	
	# Configura os valores iniciais da barra de vida do monstro
	if enemy_hp_bar:
		enemy_hp_bar.max_value = spawned_enemy.get_max_hp()
		enemy_hp_bar.value = spawned_enemy.hp_atual
	
	# Mapeia a party ativa e inicializa os cards visuais
	_update_active_party_list()
	for hero_id in active_party_ids:
		_update_hero_ui_display(hero_id)
		
	_next_hero_turn()

# --- REGRAS DE FLUXO DE TURNO ESTÁTICO ---

func _next_hero_turn() -> void:
	_check_end_conditions()
	if current_state == CombatState.VICTORY or current_state == CombatState.DEFEAT:
		return
		
	if current_hero_index >= active_party_ids.size():
		_start_enemy_turn()
		return
		
	current_state = CombatState.HERO_TURN
	var hero_id = active_party_ids[current_hero_index]
	
	_manage_ui_highlight(hero_id)
	
	input_blocked = false
	ui_command_buttons.exibir_comandos_para(hero_id)

func _finish_current_hero_turn() -> void:
	input_blocked = true
	current_hero_index += 1 
	
	await get_tree().create_timer(0.4).timeout
	_next_hero_turn()

func _start_enemy_turn() -> void:
	current_state = CombatState.ENEMY_TURN
	ui_command_buttons.hide_commands()
	
	await get_tree().create_timer(0.4).timeout
	_execute_enemy_attack()

func _finish_enemy_turn() -> void:
	current_hero_index = 0
	_next_hero_turn()

# --- LÓGICA DE AÇÃO DO JOGADOR (HERÓI) ---

func execute_hero_basic_attack() -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
		
	input_blocked = true
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_heroi(hero_id)
	
	var damage_dealt: int = hero_state.get_ataque()
	var element: String = "PHYSICAL"
	
	# Executa o dano usando o método do seu EnemyState
	var _hit_weakness: bool = spawned_enemy.receber_dano_combate(damage_dealt, element)
	_trigger_enemy_damage_popup(damage_dealt, element)
	
	_finish_current_hero_turn()

func execute_hero_skill(skill: SkillData) -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
		
	input_blocked = true
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_heroi(hero_id)
	
	var damage_base: int = int(hero_state.get_ataque() * skill.damage_multiplier)
	var _hit_weakness: bool = spawned_enemy.receber_dano_combate(damage_base, skill.element_type)
	_trigger_enemy_damage_popup(damage_base, skill.element_type)
	
	_finish_current_hero_turn()

# --- LÓGICA DE AÇÃO DO INIMIGO ---

func _execute_enemy_attack() -> void:
	if active_party_ids.is_empty():
		_check_end_conditions()
		return
		
	var random_index: int = randi() % active_party_ids.size()
	var target_hero_id: String = active_party_ids[random_index]
	var target_hero = PlayerData.get_heroi(target_hero_id)
	
	if not target_hero or target_hero.hp_atual <= 0:
		_finish_enemy_turn()
		return
		
	var is_magical: bool = randf() > 0.5
	var damage_dealt: int = 0
	var element_type: String = "PHYSICAL"
	var skill_name_to_show: String = "Attack"
	
	if is_magical:
		var elements: Array[String] = ["FIRE", "ICE", "ELEC"]
		element_type = elements[randi() % elements.size()]
		damage_dealt = int(spawned_enemy.get_ataque() * 1.3)
		
		match element_type:
			"FIRE": skill_name_to_show = "Agi"
			"ICE": skill_name_to_show = "Bufu"
			"ELEC": skill_name_to_show = "Zio"
	else:
		damage_dealt = spawned_enemy.get_ataque()

	# Mostra o painel com o nome do golpe acima do inimigo
	if ui_skill_announcer:
		if ui_skill_announcer is Label:
			ui_skill_announcer.text = skill_name_to_show
		elif ui_skill_announcer.has_node("Label"):
			ui_skill_announcer.get_node("Label").text = skill_name_to_show
			
		ui_skill_announcer.show()
		await get_tree().create_timer(0.8).timeout
		ui_skill_announcer.hide()

	# Aplica o dano no herói selecionado
	var _hit_weakness: bool = target_hero.take_damage_combat(damage_dealt, element_type)
	
	_trigger_damage_popup(target_hero_id, damage_dealt, element_type)
	_update_hero_ui_display(target_hero_id)
	
	if target_hero.hp_atual <= 0:
		active_party_ids.remove_at(random_index)
		if random_index <= current_hero_index and current_hero_index > 0:
			current_hero_index -= 1
	
	_finish_enemy_turn()

# --- SINAIS DE EVENTO DE UI ---

## Escuta o sinal 'hp_alterado' emitido automaticamente pelo EnemyState
func _on_enemy_hp_changed(novo_hp: int, _max_hp: int, _mudanca: int) -> void:
	if not enemy_hp_bar:
		return
	# Cria uma animação paralela suave de esvaziamento da barra
	var tween = create_tween()
	tween.tween_property(enemy_hp_bar, "value", novo_hp, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- VISUAL FEEDBACK & POPUPS ---

func _trigger_enemy_damage_popup(damage_amount: int, element_type: String) -> void:
	if not damage_popup_scene or not enemy_sprite: return
	var popup_instance = damage_popup_scene.instantiate() as Label
	if not popup_instance: return
	
	popup_instance.text = str(damage_amount)
	match element_type:
		"PHYSICAL": popup_instance.modulate = Color.WHITE
		"FIRE": popup_instance.modulate = Color.DARK_RED
		"ICE": popup_instance.modulate = Color.DEEP_SKY_BLUE
		"ELEC": popup_instance.modulate = Color.YELLOW
			
	add_child(popup_instance)
	popup_instance.global_position = enemy_sprite.global_position + Vector2(enemy_sprite.size.x / 2, -30)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup_instance, "global_position:y", popup_instance.global_position.y - 40, 0.6)
	tween.tween_property(popup_instance, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup_instance.queue_free)

func _trigger_damage_popup(target_id: String, damage_amount: int, element_type: String) -> void:
	if not damage_popup_scene: return
	var popup_instance = damage_popup_scene.instantiate() as Label
	if not popup_instance: return
	
	popup_instance.text = str(damage_amount)
	match element_type:
		"PHYSICAL": popup_instance.modulate = Color.WHITE
		"FIRE": popup_instance.modulate = Color.DARK_RED
		"ICE": popup_instance.modulate = Color.DEEP_SKY_BLUE
		"ELEC": popup_instance.modulate = Color.YELLOW
			
	add_child(popup_instance)
	
	var hero_ui_node = ui_heroes_container.get_node_or_null(target_id)
	if hero_ui_node and hero_ui_node is Control:
		popup_instance.global_position = hero_ui_node.global_position + Vector2(50, -20)
	else:
		popup_instance.global_position = get_viewport().get_visible_rect().size / 2

	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup_instance, "global_position:y", popup_instance.global_position.y - 40, 0.6)
	tween.tween_property(popup_instance, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup_instance.queue_free)

# --- REGRAS DE ATUALIZAÇÃO DA PARTY E CONDICIONAIS DE FIM ---

func _update_active_party_list() -> void:
	active_party_ids.clear()
	for hero_id in PlayerData.party_ativa:
		var hero_state = PlayerData.get_heroi(hero_id)
		if hero_state and hero_state.hp_atual > 0:
			active_party_ids.append(hero_id)
	print("⚔️ [CombatManager] Party carregada. Heróis vivos: ", active_party_ids)

func _check_end_conditions() -> void:
	if spawned_enemy and spawned_enemy.hp_atual <= 0:
		current_state = CombatState.VICTORY
		_on_enemy_died()
		return
		
	if active_party_ids.is_empty():
		current_state = CombatState.DEFEAT
		_on_player_defeat()
		return

## Faz o cartão de status do herói da vez deslizar suavemente para o lado!
func _manage_ui_highlight(hero_id: String) -> void:
	if not ui_heroes_container: return
	for card in ui_heroes_container.get_children():
		if card.has_method("animar_selecao"):
			var selecionado: bool = (card.name == hero_id)
			card.animar_selecao(selecionado)

## Força o cartão do herói a se conectar com o Autoload
func _update_hero_ui_display(hero_id: String) -> void:
	if not ui_heroes_container: return
	var hero_card = ui_heroes_container.get_node_or_null(hero_id)
	if hero_card and hero_card.has_method("configurar_card"):
		var hero_state = PlayerData.get_heroi(hero_id)
		if hero_state:
			hero_card.configurar_card(hero_state)

func _on_enemy_died() -> void:
	current_state = CombatState.VICTORY
	ui_command_buttons.hide_commands()
	print("🎉 Vitória! O monstro foi derrotado.")

func _on_player_defeat() -> void:
	ui_command_buttons.hide_commands()
	print("☠️ Game Over! Toda a equipe caiu em batalha.")
