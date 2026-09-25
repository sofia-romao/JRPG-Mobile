# CommandMenu.gd
extends PanelContainer

signal acao_selecionada(tipo_acao, detalhe)

@export var combat_manager: Node

@onready var main_buttons = $MenuContexts/MainButtons
@onready var skills_sub_menu = $MenuContexts/SkillsSubMenu
@onready var skills_list_container: VBoxContainer = $MenuContexts/SkillsSubMenu/SkillsList
@onready var items_sub_menu = $MenuContexts/ItemsSubMenu
@onready var items_list = $MenuContexts/ItemsSubMenu/ItemsList

func _ready() -> void:
	# Conecta os botões principais da UI mobile
	$MenuContexts/MainButtons/AttackButton.pressed.connect(_on_attack_pressed)
	$MenuContexts/MainButtons/SkillsButton.pressed.connect(_on_skills_menu_opened) # Ajustado aqui!
	$MenuContexts/MainButtons/ItemsButton.pressed.connect(_on_items_pressed)
	
	# Se o botão RunButton ainda existir fisicamente na sua cena, você pode esconder ou desconectar:
	if has_node("MenuContexts/MainButtons/RunButton"):
		$MenuContexts/MainButtons/RunButton.hide()
	
	# Garante o estado inicial limpo ao carregar a cena
	mostrar_menu_principal()

func mostrar_menu_principal() -> void:
	show()
	main_buttons.show()
	skills_sub_menu.hide()
	items_sub_menu.hide()

## Chamado pelo CombatManager quando o turno do herói começa
func display_commands_for(hero_id: String) -> void:
	var hero_state = PlayerData.get_heroi(hero_id)
	mostrar_menu_principal()
	
	# Feedback visual tátil maravilhoso para Mobile usando a cor do herói!
	if hero_state and hero_state.blueprint:
		modulate = hero_state.blueprint.cor_tema

## Esconde todo o painel de comandos (usado no turno do inimigo)
func hide_commands() -> void:
	hide()

# --- INTERAÇÃO DOS BOTÕES PRINCIPAIS ---

func _on_attack_pressed() -> void:
	# Desativa a UI e avisa o gerenciador para desferir o golpe físico
	hide_commands()
	combat_manager.execute_hero_basic_attack()

func _on_skills_menu_opened() -> void:
	# Transiciona o menu para o contexto de magias e popula a lista
	main_buttons.hide()
	skills_sub_menu.show()
	_populate_skills_list()

func _on_items_pressed() -> void:
	main_buttons.hide()
	items_sub_menu.show()
	# _popular_lista_itens() # Para implementar futuramente

# --- GERENCIAMENTO DINÂMICO DE HABILIDADES ---

func _populate_skills_list() -> void:
	# 1. Limpa os botões de magia da rodada anterior para não acumular na tela
	for child in skills_list_container.get_children():
		child.queue_free()
		
	# 2. Resgata o herói atual direto da linha do tempo estável do combate
	var current_hero_id = combat_manager.active_party_ids[combat_manager.current_hero_index]
	var hero_state = PlayerData.get_heroi(current_hero_id)
	
	if not hero_state or not hero_state.blueprint:
		return
		
	# 3. Varre os IDs de texto e gera os botões físicos no celular
	for skill_id in hero_state.blueprint.skill_list:
		var skill_data: SkillData = SkillsDatabase.get_skill(skill_id)
		
		if skill_data:
			var button = Button.new()
			button.text = "%s (%d MP)" % [skill_data.name, skill_data.mp_cost]
			button.alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			
			skills_list_container.add_child(button)
			
			# Passa a função anônima injetando os dados da magia correta no clique
			button.pressed.connect(func(): _on_skill_selected(skill_data))

## Função disparada exclusivamente quando o jogador escolhe uma magia da lista
func _on_skill_selected(skill: SkillData) -> void:
	hide_commands()
	combat_manager.execute_hero_skill(skill)
