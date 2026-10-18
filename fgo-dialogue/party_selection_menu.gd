# party_selection_menu.gd
extends Control
class_name ExplorationUnifiedMenu

enum MenuTab { HEROES, MISSIONS }

@export_category("Scene Configuration")
@export var hero_card_prefab: PackedScene 
@export var mission_card_prefab: PackedScene 

@export_category("UI Nodes")
@export var grid_container: GridContainer
@export var action_button: Button 
@export var show_completed_toggle: CheckBox # 🔄 REPLAY TOGGLE CONTROL Added here!

var current_tab: MenuTab = MenuTab.HEROES
var available_missions: Dictionary = {} 
@export var mission_resources: Array[MissionData] = []

func _ready() -> void:
	_load_missions_from_folder()

	if action_button and not action_button.pressed.is_connected(_on_action_button_pressed):
		action_button.pressed.connect(_on_action_button_pressed)
		
	# 🔔 Hook up the checkbox signal so clicking it instantly rebuilds the view grid!
	if show_completed_toggle and not show_completed_toggle.toggled.is_connected(_on_toggle_completed_view):
		show_completed_toggle.toggled.connect(_on_toggle_completed_view)
		
	# Força o menu a iniciar exibindo a lista de missões logo no primeiro frame
	current_tab = MenuTab.MISSIONS
	update_menu_ui()

## Função principal que reconstrói a lista dependendo da aba ativa
func update_menu_ui() -> void:
	# Limpa os cartões antigos da tela
	for child in grid_container.get_children():
		child.queue_free()
		
	# Direciona para a renderização correta baseado na aba atual
	match current_tab:
		MenuTab.HEROES:
			_render_heroes_tab()
		MenuTab.MISSIONS:
			_render_missions_tab()

# --- RENDERS DE ABA ---

func _render_heroes_tab() -> void:
	# Esconde o checkbox quando navegando nas Barracks para manter o painel limpo
	if show_completed_toggle: show_completed_toggle.hide()
	
	if action_button:
		if PlayerData.selected_mission_data != null:
			action_button.text = "[ DEPLOY TEAM ]"
			action_button.disabled = PlayerData.active_party.is_empty()
		else:
			action_button.text = "Select a Mission First"
			action_button.disabled = true
		
	for hero_id in PlayerData.hero_collection:
		var hero_state: HeroState = PlayerData.get_hero(hero_id)
		var is_in_party: bool = PlayerData.active_party.has(hero_id)
		
		var new_card = hero_card_prefab.instantiate()
		grid_container.add_child(new_card)
		
		if new_card.has_method("initialize_card"):
			new_card.initialize_card(hero_id, hero_state, is_in_party)
			
		if new_card.has_signal("card_clicked"):
			new_card.card_clicked.connect(_on_hero_card_selected)

func _render_missions_tab() -> void:
	# Mostra o checkbox somente quando visualizando o mural de missões
	if show_completed_toggle: show_completed_toggle.show()
	
	if action_button:
		action_button.text = "Select Mission"
		action_button.disabled = true

	# ⚙️ DETECTOR DE ESTADO DO FILTRO
	var viewing_completed_only: bool = false
	if show_completed_toggle:
		viewing_completed_only = show_completed_toggle.button_pressed

	for mission_id in available_missions:
		var mission: MissionData = available_missions[mission_id]
		var is_mission_clear: bool = PlayerData.completed_missions.has(mission.id)
		
		# 🎛️ FILTRO DE EXCLUSÃO MÚTUA INTELIGENTE:
		# Se o checkbox está marcado, esconde as missões novas.
		# Se o checkbox está desmarcado, esconde as missões completas!
		if is_mission_clear != viewing_completed_only:
			continue
			
		# Regra de Progressão: Impede missões futuras bloqueadas de pularem a ordem
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

func _on_toggle_completed_view(_is_toggled: bool) -> void:
	print("🎛️ [Filter] Swapping mission list mode. Show Completed Only: ", _is_toggled)
	update_menu_ui()

func _on_hero_card_selected(hero_id: String) -> void:
	if PlayerData.active_party.has(hero_id):
		PlayerData.active_party.erase(hero_id)
	else:
		if PlayerData.active_party.size() < PlayerData.MAX_PARTY_SIZE:
			PlayerData.active_party.append(hero_id)
			
	update_menu_ui()

func _on_mission_card_selected(mission: MissionData) -> void:
	PlayerData.selected_mission_data = mission
	print("🎯 Missão Selecionada: ", mission.title, ". Indo para as Barracks...")
	
	var main = get_tree().root.get_node_or_null("MainController")
	if main and main.has_method("_transition_to_scene"):
		main._transition_to_scene(main.HERO_DETAILS_PATH)

# --- INPUT E ALTERNÂNCIA DE ABAS ---

func switch_tab(tab_index: int) -> void:
	print("🔄 [MENU] switch_tab foi chamada! Mudando para a aba: ", tab_index)
	current_tab = tab_index as MenuTab
	update_menu_ui()

func _on_action_button_pressed() -> void:
	if PlayerData.selected_mission_data != null:
		if PlayerData.active_party.is_empty():
			print("❌ Menu: Deploy aborted! Active party is empty.")
			return
			
		var mission = PlayerData.selected_mission_data
		PlayerData.active_mission_id = mission.id
		
		PlayerData.heal_active_party()
		print("🚀 Menu: Team deployed successfully! Starting mission: ", mission.title)
		
		var main = get_tree().root.get_node_or_null("MainController")
		if main and main.has_method("_on_exploration_requested_dialogue"):
			main._on_exploration_requested_dialogue(mission.start_event)
	else:
		print("⚠️ Menu: No mission selected to deploy.")

# --- CARREGADOR AUTOMÁTICO DE RECURSOS ---

func _load_missions_from_folder() -> void:
	available_missions.clear()
	
	for mission in mission_resources:
		if mission and not mission.id.is_empty():
			available_missions[mission.id] = mission
			
	print("📦 [Web Load] Loaded ", available_missions.size(), " missions securely.")
	
func _on_back_button_pressed() -> void:
	var main = get_tree().root.get_node_or_null("MainController")
	if main and main.has_method("_transition_to_scene"):
		main._transition_to_scene(main.HERO_DETAILS_PATH)
