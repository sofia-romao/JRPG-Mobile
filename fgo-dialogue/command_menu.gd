# CommandMenu.gd
extends PanelContainer

@export var combat_manager: Node

@onready var main_buttons = $MenuContexts/MainButtons
@onready var skills_sub_menu = $MenuContexts/SkillsSubMenu
@onready var skills_list_container: VBoxContainer = $MenuContexts/SkillsSubMenu/SkillsList
@onready var items_sub_menu = $MenuContexts/ItemsSubMenu
@onready var items_list = $MenuContexts/ItemsSubMenu/ItemsList

@export_group("Skill Info Popup (FGO Style)")
@export var skill_info_popup: Control          # O painel de fundo que abre/fecha
@export var skill_info_name: Label             # Label para o título/nome da skill
@export var skill_info_desc: Label             # Label para o texto da descrição
@export var close_popup_button: Button         # O botão físico de fechar [X]

var _current_selected_skill: SkillData = null
var _input_guarded: bool = true # 🌟 TRAVA DE SEGURANÇA MÁXIMA

func _ready() -> void:
	# Conecta os botões principais da UI mobile de forma blindada
	if has_node("MenuContexts/MainButtons/AttackButton"):
		$MenuContexts/MainButtons/AttackButton.pressed.connect(_on_attack_pressed)
	if has_node("MenuContexts/MainButtons/SkillsButton"):
		$MenuContexts/MainButtons/SkillsButton.pressed.connect(_on_skills_menu_opened)
	if has_node("MenuContexts/MainButtons/ItemsButton"):
		$MenuContexts/MainButtons/ItemsButton.pressed.connect(_on_items_pressed)
	
	if has_node("MenuContexts/MainButtons/RunButton"):
		$MenuContexts/MainButtons/RunButton.hide()
		
	if close_popup_button:
		close_popup_button.pressed.connect(func():
			if skill_info_popup: 
				skill_info_popup.hide()
		)
	mostrar_menu_principal()

func mostrar_menu_principal() -> void:
	show() 
	if main_buttons: main_buttons.show()
	if skills_sub_menu: skills_sub_menu.hide()
	if items_sub_menu: items_sub_menu.hide()

## Chamado pelo CombatManager quando o turno do herói começa
func show_commands_for(hero_id: String) -> void:
	mostrar_menu_principal()
	var hero_state = PlayerData.get_hero(hero_id)
	
	# SMT Retro Style: Modula a cor do menu de texto baseado no herói da vez!
	if hero_state and hero_state.blueprint:
		modulate = hero_state.blueprint.theme_color

## Esconde todo o painel de comandos (usado no turno do inimigo)
func hide_commands() -> void:
	pass

# --- INTERAÇÃO DOS BOTÕES PRINCIPAIS ---

func _on_attack_pressed() -> void:
	hide_commands()
	combat_manager.execute_hero_basic_attack()

func _on_skills_menu_opened() -> void:
	if main_buttons: main_buttons.hide()
	if skills_sub_menu: skills_sub_menu.show()
	
	# 🧼 LIMPEZA: Abrimos direto e deixamos a trava do _populate_skills_list cuidar do frame fantasma
	_populate_skills_list()

func _on_items_pressed() -> void:
	if main_buttons: main_buttons.hide()
	if items_sub_menu: items_sub_menu.show()

# --- GERENCIAMENTO DINÂMICO DE HABILIDADES ---
# Substitua inteiramente a função _populate_skills_list() dentro de CommandMenu.gd

func _populate_skills_list() -> void:
	_input_guarded = true
	
	# 1. Limpa os botões de magia anteriores
	for child in skills_list_container.get_children():
		child.queue_free()
		
	# 2. Resgata o herói atual direto da linha do tempo do combate
	var current_hero_id = combat_manager.active_party_ids[combat_manager.current_hero_index]
	var hero_state = PlayerData.get_hero(current_hero_id)
	
	if not hero_state or not hero_state.blueprint:
		return
		
	# 3. Varre os IDs de texto e gera os botões físicos no contêiner
	for skill_id in hero_state.get_available_skills():
		var skill_data: SkillData = SkillsDatabase.get_skill(skill_id)

		if skill_data:
			var button = Button.new()
			button.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			skills_list_container.add_child(button)
			
			var cost_text = ""
			if skill_data.element_type == "PHYSICAL":
				cost_text = str(skill_data.mp_cost) + "% HP"
			else:
				cost_text = str(skill_data.mp_cost) + " MP"
				
			button.text = "%-12s %6s" % [skill_data.name, cost_text]
			
			if skill_data.element_type == "PHYSICAL":
				var hp_cost = int(hero_state.get_max_hp() * (skill_data.mp_cost / 100.0))
				if hero_state.current_hp <= hp_cost: button.disabled = true
			else:
				if hero_state.current_mp < skill_data.mp_cost: button.disabled = true
				
			# 🌟 NOVO SISTEMA TÁTIL ISOLADO (ESTILO FGO)
			var hold_timer_tween: Tween = null
			var popup_opened_this_touch: bool = false
		
			# GATILHO A: O dedo encostou na tela do celular (Inicia o relógio do Toque Longo)
			button.button_down.connect(func():
				if _input_guarded: return
				
				popup_opened_this_touch = false
				
				hold_timer_tween = create_tween()
				hold_timer_tween.tween_interval(0.4)
				
				# Se segurar por 0.4s, o popup abre e a gente cancela a intenção de ataque rápido
				hold_timer_tween.tween_callback(func():
					popup_opened_this_touch = true
					if skill_info_popup and skill_info_name and skill_info_desc:
						skill_info_name.text = skill_data.name
						skill_info_desc.text = skill_data.description
						skill_info_popup.show()
						
						# 🛡️ TRUQUE DE DESIGN: Força o botão a perder o foco instantaneamente
						# Isso limpa qualquer clique pendente na fila do Godot!
						button.release_focus() 
				)
			)
			
			# GATILHO B: O clique foi solto (O sinal 'pressed' nativo é o mais seguro do Godot)
			button.pressed.connect(func():
				if _input_guarded: return
				
				# Se o relógio ainda estava correndo, mata ele porque o clique foi rápido
				if hold_timer_tween and hold_timer_tween.is_valid():
					hold_timer_tween.kill()
					
				# 🛡️ BLINDAGEM DE SINAL: Se o popup abriu enquanto segurava, bloqueia a execução da skill!
				if popup_opened_this_touch:
					return 
					
				# Se chegou aqui, foi um toque curto legítimo! Executa a habilidade normalmente
				_on_skill_clicked(skill_data)
			)
			
			# GATILHO C: Segurança extra caso o dedo deslize para fora do botão mobile
			button.mouse_exited.connect(func():
				if hold_timer_tween and hold_timer_tween.is_valid():
					hold_timer_tween.kill()
			)
				
	# 4. Adiciona o botão de voltar no fim da lista (Linha fantasma corrigida e removida!)
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	skills_list_container.add_child(back_btn)
	back_btn.pressed.connect(mostrar_menu_principal)
	
	# Força uma espera assíncrona limpa para desativar a proteção de abertura
	await get_tree().process_frame
	await get_tree().create_timer(0.06).timeout
	_input_guarded = false

## Avalia quem a skill atinge antes de mandar fechar o menu
func _on_skill_clicked(skill: SkillData) -> void:
	_current_selected_skill = skill
	
	match skill.target_type:
		SkillData.TargetType.ENEMY:
			hide_commands()
			combat_manager.execute_hero_skill(skill)
			
		SkillData.TargetType.ALLY_ALL:
			hide_commands()
			combat_manager.execute_hero_party_heal(skill)
			
		SkillData.TargetType.ALLY_SINGLE:
			_open_alliance_target_menu()

## Popula a lista dinamicamente com os heróis vivos para o jogador escolher o alvo
func _open_alliance_target_menu() -> void:
	for child in skills_list_container.get_children():
		child.queue_free()
		
	for hero_id in combat_manager.active_party_ids:
		var hero_state = PlayerData.get_hero(hero_id)
		if hero_state:
			var btn = Button.new()
			btn.text = "%-12s (HP: %d)" % [hero_state.blueprint.character_name, hero_state.current_hp]
			btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			skills_list_container.add_child(btn)
			
			btn.pressed.connect(func():
				hide_commands()
				combat_manager.execute_hero_single_ally_action(hero_state, _current_selected_skill)
			)
			
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	skills_list_container.add_child(back_btn)
	back_btn.pressed.connect(_on_skills_menu_opened)
