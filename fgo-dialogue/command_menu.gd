# CommandMenu.gd (VERSÃO DE DIAGNÓSTICO ROBUSTO)
extends PanelContainer

@export var combat_manager: Node

@onready var main_buttons = $MenuContexts/MainButtons
@onready var skills_sub_menu = $MenuContexts/SkillsSubMenu
@onready var skills_list_container: VBoxContainer = $MenuContexts/SkillsSubMenu/SkillsList

@export_group("Skill Info Popup (FGO Style)")
@export var skill_info_popup: Control          
@export var skill_info_name: Label             
@export var skill_info_desc: Label             
@export var close_popup_button: Button         

var _current_selected_skill: SkillData = null

func _ready() -> void:
	print("🔍 [DEBUG-UI] CommandMenu inicializado no _ready.")
	
	# Monitora nativamente se o nó de skills mudar de visibilidade por forças externas
	if skills_sub_menu:
		skills_sub_menu.visibility_changed.connect(func():
			print("🚨 [DEBUG-UI] GATILHO NATIVO: 'skills_sub_menu.visible' mudou para: ", skills_sub_menu.visible, " | Stack: ", get_stack())
		)

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
				print("ℹ️ [DEBUG-UI] Fechando popup do FGO via botão.")
				skill_info_popup.hide()
		)
	mostrar_menu_principal()

func mostrar_menu_principal() -> void:
	print("ℹ️ [DEBUG-UI] Função 'mostrar_menu_principal()' chamada.")
	show() 
	if main_buttons: main_buttons.show()
	if skills_sub_menu: skills_sub_menu.hide()

func show_commands_for(hero_id: String) -> void:
	print("ℹ️ [DEBUG-UI] 'show_commands_for()' chamada para o herói: ", hero_id)
	mostrar_menu_principal()
	var hero_state = PlayerData.get_hero(hero_id)
	if hero_state and hero_state.blueprint:
		modulate = hero_state.blueprint.theme_color

func hide_commands() -> void:
	print("ℹ️ [DEBUG-UI] 'hide_commands()' executada.")
	pass

# --- INTERAÇÃO DOS BOTÕES PRINCIPAIS ---

func _on_attack_pressed() -> void:
	print("🕹️ [DEBUG-UI] Botão de Ataque físico pressionado.")
	hide_commands()
	combat_manager.execute_hero_basic_attack()

func _on_skills_menu_opened() -> void:
	print("🕹️ [DEBUG-UI] Botão de abrir menu de SKILLS pressionado.")
	if skills_sub_menu: 
		skills_sub_menu.show()
	if main_buttons: 
		main_buttons.hide()
		
	_populate_skills_list()

func _on_items_pressed() -> void:
	print("🕹️ [DEBUG-UI] Botão de Itens pressionado.")
	if main_buttons: main_buttons.hide()

# --- GERENCIAMENTO DINÂMICO DE HABILIDADES ---

func _populate_skills_list() -> void:
	print("⚙️ [DEBUG-UI] Iniciando o '_populate_skills_list()'. Estado visível do sub-menu: ", skills_sub_menu.visible if skills_sub_menu else "null")
	
	if not skills_sub_menu or not skills_sub_menu.visible:
		print("⚠️ [DEBUG-UI] Abortando popular lista: sub-menu não está visível.")
		return
		
	for child in skills_list_container.get_children():
		child.free()
		
	var current_hero_id = combat_manager.active_party_ids[combat_manager.current_hero_index]
	var hero_state = PlayerData.get_hero(current_hero_id)
	
	if not hero_state or not hero_state.blueprint:
		print("⚠️ [DEBUG-UI] Abortando popular lista: herói atual inválido.")
		return
		
	print("📋 [DEBUG-UI] Populando skills para o herói: ", current_hero_id, " | Quantidade: ", hero_state.get_available_skills().size())
	
	for skill_id in hero_state.get_available_skills():
		var skill_data: SkillData = SkillsDatabase.get_skill(skill_id)

		if skill_data:
			var button = Button.new()
			button.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_NONE
			skills_list_container.add_child(button)
			
			var hold_timer_tween: Tween = null
			var popup_opened_this_touch: bool = false
			
			button.tree_exiting.connect(func():
				if hold_timer_tween and hold_timer_tween.is_valid():
					hold_timer_tween.kill()
			)
			
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
				
			button.gui_input.connect(func(event: InputEvent):
				if button.disabled or not skills_sub_menu.visible: return
				
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
					if event.pressed:
						print("🎯 [DEBUG-UI] 'button_down' legítimo detectado na skill: ", skill_data.name)
						popup_opened_this_touch = false
						
						if hold_timer_tween and hold_timer_tween.is_valid():
							hold_timer_tween.kill()
							
						hold_timer_tween = create_tween()
						hold_timer_tween.tween_interval(0.4)
						hold_timer_tween.tween_callback(func():
							if not is_instance_valid(button) or not skills_sub_menu.visible: return
							print("💥 [DEBUG-UI] Tempo de Toque Longo estourou! Abrindo popup do FGO para: ", skill_data.name)
							popup_opened_this_touch = true
							if skill_info_popup and skill_info_name and skill_info_desc:
								skill_info_name.text = skill_data.name
								skill_info_desc.text = skill_data.description
								skill_info_popup.show()
								button.release_focus()
						)
			)
			
			button.pressed.connect(func():
				print("🎯 [DEBUG-UI] Evento 'pressed' disparado no botão da skill: ", skill_data.name, " | Popup aberto neste toque? ", popup_opened_this_touch)
				if not skills_sub_menu.visible: return
				
				if hold_timer_tween and hold_timer_tween.is_valid():
					hold_timer_tween.kill()
					
				if popup_opened_this_touch:
					print("ℹ️ [DEBUG-UI] Clique curto bloqueado porque o popup do FGO está ativo.")
					return 
					
				_on_skill_clicked(skill_data)
			)
			
			button.mouse_exited.connect(func():
				if hold_timer_tween and hold_timer_tween.is_valid():
					hold_timer_tween.kill()
			)
				
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	back_btn.focus_mode = Control.FOCUS_NONE
	skills_list_container.add_child(back_btn)
	back_btn.pressed.connect(mostrar_menu_principal)
	print("⚙️ [DEBUG-UI] Fim do '_populate_skills_list()' com sucesso.")

func _on_skill_clicked(skill: SkillData) -> void:
	print("🎬 [DEBUG-UI] '_on_skill_clicked' validada para: ", skill.name)
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

func _open_alliance_target_menu() -> void:
	print("⚙️ [DEBUG-UI] Abrindo lista de alvos aliados.")
	for child in skills_list_container.get_children():
		child.free()
		
	for hero_id in combat_manager.active_party_ids:
		var hero_state = PlayerData.get_hero(hero_id)
		if hero_state:
			var btn = Button.new()
			btn.text = "%-12s (HP: %d)" % [hero_state.blueprint.character_name, hero_state.current_hp]
			btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE
			skills_list_container.add_child(btn)
			
			btn.pressed.connect(func():
				hide_commands()
				combat_manager.execute_hero_single_ally_action(hero_state, _current_selected_skill)
			)
			
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	back_btn.focus_mode = Control.FOCUS_NONE
	skills_list_container.add_child(back_btn)
	back_btn.pressed.connect(_on_skills_menu_opened)
