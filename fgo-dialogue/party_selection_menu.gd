# party_selection_menu.gd
extends Control
class_name ExplorationUnifiedMenu

enum MenuTab { HEROES, MISSIONS }

@export_category("Scene Configuration")
@export var hero_card_prefab: PackedScene 
@export var mission_card_prefab: PackedScene # Seu novo prefab de cartão de missão

@export_category("UI Nodes")
@export var grid_container: GridContainer
@export var locked_warning_label: Label
@export var action_button: Button # Botão inferior (ex: "Start Mission" ou "Confirm Party")
@export var tab_heroes_button: Button
@export var tab_missions_button: Button
var current_tab: MenuTab = MenuTab.HEROES
var available_missions: Dictionary = {} # Armazena as missões carregadas do disco

func _ready() -> void:
	_load_missions_from_folder()
	
	if tab_heroes_button:
		tab_heroes_button.pressed.connect(func(): switch_tab(0)) # 0 = Heroes
		
	if tab_missions_button:
		tab_missions_button.pressed.connect(func(): switch_tab(1)) # 1 = Missions
	
	# Conexão do botão de ação contextual
	if action_button and not action_button.pressed.is_connected(_on_action_button_pressed):
		action_button.pressed.connect(_on_action_button_pressed)
		
	# --- 📑 MUDANÇA DE INICIALIZAÇÃO AQUI ---
	# Força o menu a iniciar exibindo a lista de missões logo no primeiro frame!
	current_tab = MenuTab.MISSIONS
	# ----------------------------------------
	
	update_menu_ui()

## Função principal que reconstrói a lista dependendo da aba ativa
func update_menu_ui() -> void:
	for child in grid_container.get_children():
		child.queue_free()
		
	var is_locked: bool = PlayerData.is_mission_in_progress
	
	if locked_warning_label:
		locked_warning_label.visible = is_locked
		locked_warning_label.text = "⚠️ MISSION IN PROGRESS - CONTROLS LOCKED"
	
	match current_tab:
		MenuTab.HEROES:
			_render_heroes_tab(is_locked)
		MenuTab.MISSIONS:
			_render_missions_tab(is_locked)

# --- RENDERS DE ABA ---

func _render_heroes_tab(is_locked: bool) -> void:
	if action_button:
		if is_locked:
			action_button.text = "Party Locked"
			action_button.disabled = true
		elif PlayerData.selected_mission_data != null:
			# Se veio da aba de missões com um contrato, vira o botão de Deploy!
			action_button.text = "[ DEPLOY TEAM ]"
			# TRAVA: Fica desativado se o jogador tentar entrar na luta sem heróis selecionados!
			action_button.disabled = PlayerData.active_party.is_empty()
		else:
			# Se o jogador está apenas navegando na tela sem missão selecionada
			action_button.text = "Select a Mission First"
			action_button.disabled = true
		
	for hero_id in PlayerData.hero_collection:
		var hero_state: HeroState = PlayerData.hero_collection[hero_id]
		var is_in_party: bool = PlayerData.active_party.has(hero_id)
		
		var new_card = hero_card_prefab.instantiate()
		grid_container.add_child(new_card)
		
		if new_card.has_method("initialize_card"):
			new_card.initialize_card(hero_id, hero_state, is_in_party, is_locked)
			
		if new_card.has_signal("card_clicked"):
			new_card.card_clicked.connect(_on_hero_card_selected)

func _render_missions_tab(is_locked: bool) -> void:
	if action_button:
		if is_locked:
			action_button.text = "Continue Mission"
			action_button.disabled = false
		else:
			# Na aba de missões o botão inferior serve apenas como um aviso visual de instrução
			action_button.text = "Click a Mission Card Above"
			action_button.disabled = true

	if is_locked:
		return

	for mission_id in available_missions:
		var mission: MissionData = available_missions[mission_id]
		
		if PlayerData.completed_missions.has(mission.id):
			continue
			
		if mission.required_mission_id != "" and not PlayerData.completed_missions.has(mission.required_mission_id):
			continue
			
		var new_card = mission_card_prefab.instantiate()
		grid_container.add_child(new_card)
		
		if new_card.has_method("initialize_mission_card"):
			var is_selected = (PlayerData.selected_mission_data == mission)
			new_card.initialize_mission_card(mission, is_selected)
			
		if new_card.has_signal("mission_card_clicked"):
			new_card.mission_card_clicked.connect(_on_mission_card_selected)

# --- SINAIS DE SELEÇÃO DE CARTÕES ---

func _on_hero_card_selected(hero_id: String) -> void:
	if PlayerData.is_mission_in_progress: return
		
	if PlayerData.active_party.has(hero_id):
		PlayerData.active_party.erase(hero_id)
	else:
		if PlayerData.active_party.size() < PlayerData.MAX_PARTY_SIZE:
			PlayerData.active_party.append(hero_id)
			
	update_menu_ui()

func _on_mission_card_selected(mission: MissionData) -> void:
	if PlayerData.is_mission_in_progress: return
	
	# Seleciona ou desmarca a missão na memória
	if PlayerData.selected_mission_data == mission:
		PlayerData.selected_mission_data = null
	else:
		PlayerData.selected_mission_data = mission
		print("🎯 Menu: Mission selected: ", mission.title, ". Redirecting to Party Setup...")
		switch_tab(0) # ◄ JOGA O JOGADOR DIRETO PARA A SELEÇÃO DE HERÓIS!
		return # Interrompe aqui para o switch_tab atualizar a tela sozinho
		
	update_menu_ui()

# --- INPUT E ALTERNÂNCIA DE ABAS ---

## Chame esta função via botões de Aba (Ex: clicou no botão "Missions" da UI)
func switch_tab(tab_index: int) -> void:
	print("🔄 [MENU] switch_tab foi chamada! Mudando para a aba: ", tab_index)
	current_tab = tab_index as MenuTab
	update_menu_ui()

## Comportamento do botão de confirmação inferior
func _on_action_button_pressed() -> void:
	# Se a missão já está em andamento (retornando da dungeon)
	if PlayerData.is_mission_in_progress:
		print("🚀 Menu: Returning to active mission zone.")
		return
		
	# Caso Geral: O jogador montou a party na aba de heróis e clicou em [ DEPLOY TEAM ]
	if PlayerData.selected_mission_data != null:
		# PROTEÇÃO BRUTA: Impede o avanço se a lista de heróis ativos estiver vazia na memória
		if PlayerData.active_party.is_empty():
			print("❌ Menu: Deploy aborted! Active party is empty.")
			return
			
		var mission = PlayerData.selected_mission_data
		PlayerData.active_mission_id = mission.id
		
		# Cura e enche o MP/HP da equipe ativa antes de entrar na arena
		PlayerData.heal_active_party()
		
		print("🚀 Menu: Team deployed successfully! Starting mission: ", mission.title)
		
		var main = get_tree().root.get_node_or_null("MainController")
		if main and main.has_method("_on_exploration_requested_dialogue"):
			main._on_exploration_requested_dialogue(mission.start_event)
	else:
		print("⚠️ Menu: No mission selected to deploy.")

# --- CARREGADOR AUTOMÁTICO DE RECURSOS ---

func _load_missions_from_folder() -> void:
	var folder_path = "res://resources/missions/"
	var dir = DirAccess.open(folder_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var mission = load(folder_path + file_name) as MissionData
				if mission:
					available_missions[mission.id] = mission
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("⚠️ Menu: Pasta resources/missions/ não encontrada.")
