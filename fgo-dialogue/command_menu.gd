# CommandMenu.gd
extends PanelContainer

@export var combat_manager: Node

@onready var main_buttons = $MenuContexts/MainButtons
@onready var skills_sub_menu = $MenuContexts/SkillsSubMenu
@onready var skills_list_container: VBoxContainer = $MenuContexts/SkillsSubMenu/SkillsList
@onready var items_sub_menu = $MenuContexts/ItemsSubMenu
@onready var items_list = $MenuContexts/ItemsSubMenu/ItemsList

var _current_selected_skill: SkillData = null

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
	hide()

# --- INTERAÇÃO DOS BOTÕES PRINCIPAIS ---

func _on_attack_pressed() -> void:
	hide_commands()
	combat_manager.execute_hero_basic_attack()

func _on_skills_menu_opened() -> void:
	if main_buttons: main_buttons.hide()
	if skills_sub_menu: skills_sub_menu.show()
	_populate_skills_list()

func _on_items_pressed() -> void:
	if main_buttons: main_buttons.hide()
	if items_sub_menu: items_sub_menu.show()

# --- GERENCIAMENTO DINÂMICO DE HABILIDADES ---

func _populate_skills_list() -> void:
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
			
			# Formatação Monocromática Clássica de NES para Custos
			var cost_text = ""
			if skill_data.element_type == "PHYSICAL":
				cost_text = str(skill_data.mp_cost) + "% HP"
			else:
				cost_text = str(skill_data.mp_cost) + " MP"
				
			button.text = "%-12s %6s" % [skill_data.name, cost_text]
			
			# VALIDAÇÃO DE CUSTO: Desativa o botão se o herói não puder pagar em tempo real
			if skill_data.element_type == "PHYSICAL":
				var hp_cost = int(hero_state.get_max_hp() * (skill_data.mp_cost / 100.0))
				if hero_state.current_hp <= hp_cost:
					button.disabled = true
			else:
				if hero_state.current_mp < skill_data.mp_cost:
					button.disabled = true
			
			# Vincula o clique direcionando para o avaliador de alvos
			button.pressed.connect(func(): _on_skill_clicked(skill_data))
			
	# 4. Adiciona o botão de voltar no fim da lista
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	skills_list_container.add_child(back_btn)
	back_btn.pressed.connect(mostrar_menu_principal)

## Avalia quem a skill atinge antes de mandar fechar o menu
func _on_skill_clicked(skill: SkillData) -> void:
	_current_selected_skill = skill
	
	match skill.target_type:
		SkillData.TargetType.ENEMY:
			# Ofensiva? Fecha a UI e ataca o inimigo único imediatamente
			hide_commands()
			combat_manager.execute_hero_skill(skill)
			
		SkillData.TargetType.ALLY_ALL:
			# Em área? Cura todo mundo de uma vez e encerra o turno
			hide_commands()
			combat_manager.execute_hero_party_heal(skill)
			
		SkillData.TargetType.ALLY_SINGLE:
			# Alvo único aliado? Abre a sub-lista de heróis no mesmo contêiner!
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
			
			# Executa a cura focada no herói escolhido
			btn.pressed.connect(func():
				hide_commands()
				combat_manager.execute_hero_single_heal(hero_state, _current_selected_skill)
			)
			
	# Botão de voltar para a lista de skills
	var back_btn = Button.new()
	back_btn.text = "[ BACK ]"
	skills_list_container.add_child(back_btn)
	back_btn.pressed.connect(_on_skills_menu_opened)
