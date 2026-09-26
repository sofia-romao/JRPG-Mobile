extends Node
class_name CombatManager

# O sinal que a MainController vai escutar para desinstanciar o combate
signal combat_finished(victory: bool)

enum CombatState { INITIALIZING, HERO_TURN, ENEMY_TURN, VICTORY, DEFEAT }

@export var damage_popup_scene: PackedScene 

var current_state: CombatState = CombatState.INITIALIZING
var combat_data: CombatData
var spawned_enemy: EnemyState

var active_party_ids: Array[String] = []
var current_hero_index: int = 0
var input_blocked: bool = false

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
	spawned_enemy.died.connect(_on_enemy_died)
	spawned_enemy.hp_changed.connect(_on_enemy_hp_changed)
	
	if enemy_hp_bar:
		enemy_hp_bar.max_value = spawned_enemy.get_max_hp()
		enemy_hp_bar.value = spawned_enemy.current_hp
	
	_update_active_party_list()
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
	ui_command_buttons.hide_commands()
	await get_tree().create_timer(0.4).timeout
	_execute_enemy_attack()

func _finish_enemy_turn() -> void:
	current_hero_index = 0
	_next_hero_turn()

# --- AÇÕES ---

func execute_hero_basic_attack() -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
	input_blocked = true
	
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_heroi(hero_id)
	
	var damage_dealt: int = hero_state.get_ataque()
	var element: String = "PHYSICAL"
	
	spawned_enemy.receber_dano_combate(damage_dealt, element)
	_trigger_enemy_damage_popup(damage_dealt, element)
	
	_check_end_conditions()
	if current_state == CombatState.INITIALIZING or current_state == CombatState.HERO_TURN:
		_finish_current_hero_turn()

func execute_hero_skill(skill: SkillData) -> void:
	if input_blocked or current_state != CombatState.HERO_TURN:
		return
	input_blocked = true
	
	var hero_id = active_party_ids[current_hero_index]
	var hero_state = PlayerData.get_heroi(hero_id)
	
	var damage_base: int = int(hero_state.get_ataque() * skill.damage_multiplier)
	spawned_enemy.receber_dano_combate(damage_base, skill.element_type)
	_trigger_enemy_damage_popup(damage_base, skill.element_type)
	
	_check_end_conditions()
	if current_state == CombatState.INITIALIZING or current_state == CombatState.HERO_TURN:
		_finish_current_hero_turn()

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
		
	var damage_dealt = spawned_enemy.get_ataque()
	target_hero.take_damage_combat(damage_dealt, "PHYSICAL")
	
	_trigger_damage_popup(target_hero_id, damage_dealt, "PHYSICAL")
	_update_hero_ui_display(target_hero_id)
	
	if target_hero.hp_atual <= 0:
		active_party_ids.remove_at(random_index)
	
	_check_end_conditions()
	if current_state == CombatState.ENEMY_TURN:
		_finish_enemy_turn()

# --- CONDICIONAIS DE FIM (AVISA A MAIN) ---

func _check_end_conditions() -> void:
	if spawned_enemy and spawned_enemy.hp_atual <= 0:
		current_state = CombatState.VICTORY
		_on_enemy_died()
	elif active_party_ids.is_empty():
		current_state = CombatState.DEFEAT
		_on_player_defeat()

func _on_enemy_died() -> void:
	ui_command_buttons.hide_commands()
	combat_finished.emit(true) # Emitindo o sinal nativo do Godot 4!

func _on_player_defeat() -> void:
	ui_command_buttons.hide_commands()
	combat_finished.emit(false) # Perdeu a batalha

# --- SISTEMAS DE UI (IGUAIS AO SEU ORIGINAL) ---
func _on_enemy_hp_changed(novo_hp: int, _max_hp: int, _mudanca: int) -> void:
	if enemy_hp_bar:
		var tween = create_tween()
		tween.tween_property(enemy_hp_bar, "value", novo_hp, 0.45)

func _update_active_party_list() -> void:
	active_party_ids.clear()
	for hero_id in PlayerData.active_party:
		var hero_state = PlayerData.get_hero(hero_id)
		if hero_state and hero_state.current_hp > 0:
			active_party_ids.append(hero_id)

func _manage_ui_highlight(hero_id: String) -> void:
	if not ui_heroes_container: return
	for card in ui_heroes_container.get_children():
		if card.has_method("animar_selecao"):
			card.animar_selecao(card.name == hero_id)

func _update_hero_ui_display(hero_id: String) -> void:
	if not ui_heroes_container: return
	var hero_card = ui_heroes_container.get_node_or_null(hero_id)
	if hero_card and hero_card.has_method("configurar_card"):
		var hero_state = PlayerData.get_heroi(hero_id)
		if hero_state: hero_card.configurar_card(hero_state)

func _trigger_enemy_damage_popup(damage_amount: int, element_type: String) -> void:
	if not damage_popup_scene or not enemy_sprite: return
	var popup = damage_popup_scene.instantiate() as Label
	popup.text = str(damage_amount)
	add_child(popup)
	popup.global_position = enemy_sprite.global_position + Vector2(enemy_sprite.size.x / 2, -30)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "global_position:y", popup.global_position.y - 40, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup.queue_free)

func _trigger_damage_popup(target_id: String, damage_amount: int, element_type: String) -> void:
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
