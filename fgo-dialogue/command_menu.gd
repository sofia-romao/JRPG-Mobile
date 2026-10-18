# CommandMenu.gd (VERSÃO INTEGRALMENTE BLINDADA E OTIMIZADA)
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

# Trava global de proteção contra popup ativo
var _popup_fgo_ativo: bool = false

func _ready() -> void:
	print("🔍 [DEBUG-UI] CommandMenu inicializado no _ready.")
	
	if skills_sub_menu:
		skills_sub_menu.visibility_changed.connect(func():
			print("🚨 [DEBUG-UI] GATILHO NATIVO: 'skills_sub_menu.visible' mudou para: ", skills_sub_menu.visible)
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
				await get_tree().create_timer(0.05).timeout
				_popup_fgo_ativo = false
		)
	mostrar_menu_principal()

func mostrar_menu_principal() -> void:
	print("ℹ️ [DEBUG-UI] Função 'mostrar_menu_principal()' chamada.")
	show() 
	if main_buttons: main_buttons.show()
	if skills_sub_menu: skills_sub_menu.hide()

func show_commands_for(hero_id: String, is_new_turn: bool = true) -> void:
	print("ℹ️ [DEBUG-UI] 'show_commands_for()' chamada para o herói: ", hero_id, " | Novo Turno: ", is_new_turn)
	
	var hero_state = PlayerData.get_hero(hero_id)
	if hero_state and hero_state.blueprint:
		modulate = hero_state.blueprint.theme_color
	
	if is_new_turn:
		mostrar_menu_principal()
	else:
		if skills_sub_menu and skills_sub_menu.visible:
			print("ℹ️ [DEBUG-UI] Dados atualizados no meio do turno. Repopulando skills...")
			_populate_skills_list()
		else:
			mostrar_menu_principal()

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
	var current_frame = Engine.get_frames_drawn()
	print("\n╔═══════════════════════════════════════════════════════════════════════════")
	print("║ 🛠️ [DEBUG-POPULATE] Iniciando montagem da lista de skills.")
	print("║ • Frame Atual da Engine: ", current_frame)
	print("╚═══════════════════════════════════════════════════════════════════════════")
	
	if not skills_sub_menu or not skills_sub_menu.visible:
		print("❌ [DEBUG] Abortado: Sub-menu não está visível.")
		return
		
	# Limpeza imediata síncrona dos nós antigos
	for child in skills_list_container.get_children():
		skills_list_container.remove_child(child)
		child.queue_free()
		
	var current_hero_id = combat_manager.active_party_ids[combat_manager.current_hero_index]
	var hero_state = PlayerData.get_hero(current_hero_id)
	
	if not hero_state or not hero_state.blueprint:
		print("❌ [DEBUG] Abortado: Dados do herói inválidos.")
		return
	
	for skill_id in hero_state.get_available_skills():
		var skill_data: SkillData = SkillsDatabase.get_skill(skill_id)

		if skill_data:
			var button = Button.new()
			button.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_NONE
			skills_list_container.add_child(button)
			
			var hold_timer_tween: Tween = null
			var popup_opened_this_touch: bool = false
			
			# Monitoramento rígido de destruição do nó
			button.tree_exiting.connect(func():
				var exit_frame = Engine.get_frames_drawn()
				var is_tween_alive = hold_timer_tween and hold_timer_tween.is_valid()
				print("🗑️ [NODE-EXIT] Botão da skill '%s' SAINDO da árvore. Frame: %d | Tween pendente e ativo? %s" % [skill_data.name, exit_frame, is_tween_alive])
				if is_tween_alive:
					print("   ↳ 🟥 [TWEEN-KILL] Interceptado! Forçando parada no temporizador assíncrono.")
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
					var event_frame = Engine.get_frames_drawn()
					print("🖱️ [SKILL-INPUT] Botão '%s' -> PRESSED: %s | Frame: %d" % [skill_data.name, event.pressed, event_frame])
					
					if event.pressed:
						popup_opened_this_touch = false
						
						if hold_timer_tween and hold_timer_tween.is_valid():
							hold_timer_tween.kill()
							
						hold_timer_tween = button.create_tween()
						hold_timer_tween.tween_interval(0.4)
						hold_timer_tween.tween_callback(func():
							var callback_frame = Engine.get_frames_drawn()
							print("💥 [TWEEN-CALLBACK] Temporizador estourou para '%s' | Frame: %d | Botão Válido na Árvore? %s" % [skill_data.name, callback_frame, is_instance_valid(button) and button.is_inside_tree()])
							
							if not is_instance_valid(button) or not skills_sub_menu.visible: 
								print("   ↳ 🟥 Ignorando estouro: Botão ou menu já se tornaram inválidos.")
								return
								
							popup_opened_this_touch = true
							_popup_fgo_ativo = true 
							
							if skill_info_popup and skill_info_name and skill_info_desc:
								skill_info_name.text = skill_data.name
								skill_info_desc.text = skill_data.description
								skill_info_popup.show()
								button.release_focus()
						)
					else:
						print("🛑 [SKILL-RELEASE] Soltou clique no botão '%s' | Frame: %d" % [skill_data.name, event_frame])
						if hold_timer_tween and hold_timer_tween.is_valid():
							hold_timer_tween.kill()
						
						if popup_opened_this_touch:
							return
						
						if not _popup_fgo_ativo:
							print("🎯 [SKILL-EXECUTE] Disparando ação da habilidade curta: ", skill_data.name)
							_on_skill_clicked(skill_data)
			)
			
			button.mouse_exited.connect(func():
				if hold_timer_tween and hold_timer_tween.is_valid():
					print("🚪 [MOUSE-EXIT] O mouse saiu dos limites físicos de '%s'. Cancelando timer." % skill_data.name)
					hold_timer_tween.kill()
			)
				
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	back_btn.focus_mode = Control.FOCUS_NONE
	skills_list_container.add_child(back_btn)
	
	# Monitoramento do clique fantasma de retorno
	back_btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var back_frame = Engine.get_frames_drawn()
			print("🔙 [BACK-INPUT] Botão [ BACK ] detectou evento -> PRESSED: %s | Frame: %d" % [event.pressed, back_frame])
	)
	
	back_btn.pressed.connect(func():
		print("🔙 [BACK-PRESSED] Sinal nativo '.pressed' do botão BACK disparado! Frame: ", Engine.get_frames_drawn())
		mostrar_menu_principal()
	)
	print("║ 🛠️ [DEBUG-POPULATE] Finalização do loop de montagem.\n")

func _open_alliance_target_menu() -> void:
	print("⚙️ [DEBUG-UI] Abrindo lista de alvos aliados.")
	
	for child in skills_list_container.get_children():
		skills_list_container.remove_child(child)
		child.queue_free()
		
	for hero_id in combat_manager.active_party_ids:
		var hero_state = PlayerData.get_hero(hero_id)
		if hero_state:
			var btn = Button.new()
			btn.text = "%-12s (HP: %d)" % [hero_state.blueprint.character_name, hero_state.current_hp]
			btn.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE
			skills_list_container.add_child(btn)
			
			btn.pressed.connect(func(target_hero = hero_state):
				if _popup_fgo_ativo: return
				hide_commands()
				combat_manager.execute_hero_single_ally_action(target_hero, _current_selected_skill)
			)
			
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	back_btn.focus_mode = Control.FOCUS_NONE
	skills_list_container.add_child(back_btn)
	back_btn.pressed.connect(_populate_skills_list)

func _on_skill_clicked(skill: SkillData) -> void:
	if _popup_fgo_ativo:
		print("🚫 [DEBUG-UI] _on_skill_clicked bloqueado preventivamente por trava de popup ativo.")
		return
		
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
