# main.gd
extends Node
class_name MainController

@export_category("Containers")
@export var scene_container: Node
@export_group("Web-Safe Core Resources")
## Arraste os seus 3 arquivos .tres iniciais de heróis aqui pelo Inspector da cena Main!
@export var starting_hero_resources: Array[HeroData] = []

# --- SCENE PATHS ---
const MAIN_MENU_PATH = "res://scenes/main_menu.tscn"
const HERO_DETAILS_PATH = "res://scenes/hero_details_menu.tscn"   # 🆕 Seu alojamento de heróis
const EXPLORATION_SCENE_PATH = "res://scenes/party_selection_menu.tscn"
const DIALOGUE_SCENE_PATH = "res://scenes/dialogue_box.tscn"
const COMBAT_SCENE_PATH = "res://scenes/combat_manager.tscn"

var _current_active_scene: Node = null
var _current_combat_data: CombatData = null
func _ready() -> void:
	if scene_container == null:
		push_error("Main: The 'scene_container' node was not assigned in the Inspector!")
		return
	# 🚀 O SEGREDO DA WEB: Injeta os arquivos carregados nativamente no Autoload global!
	if PlayerData.has_method("initialize_roster_statically"):
		PlayerData.initialize_roster_statically(starting_hero_resources)
		
	# Game starts mandatorily at Title Screen
	_transition_to_scene(MAIN_MENU_PATH)

func _transition_to_scene(scene_path: String) -> Node:
	if _current_active_scene != null:
		_current_active_scene.queue_free()
		_current_active_scene = null
		
	var scene_resource = load(scene_path)
	if scene_resource == null:
		push_error("Main: Failed to load scene at: " + scene_path)
		return null
		
	var new_instance = scene_resource.instantiate()
	scene_container.add_child(new_instance)
	_current_active_scene = new_instance
	
	_connect_active_scene_signals(new_instance)
	return new_instance

func _connect_active_scene_signals(scene: Node) -> void:
	# Usando conexões diretas para métodos fixos em vez de Lambdas anônimas
	if scene.has_signal("back_requested"):
		scene.connect("back_requested", _on_back_to_hub_requested)
		
	if scene.has_signal("missions_requested"):
		scene.connect("missions_requested", _on_missions_menu_requested)
		
	if scene.has_signal("barracks_requested"):
		scene.connect("barracks_requested", _on_barracks_menu_requested)
		
	if scene.has_signal("continue_pressed"):
		scene.connect("continue_pressed", _on_back_to_hub_requested)

	# 2. Exploration Scene (Menu Unificado)
	if scene.has_signal("mission_started"):
		scene.connect("mission_started", _on_exploration_requested_dialogue)
		
	# 3. Dialogue Manager
	if scene.has_signal("game_event_triggered"):
		scene.connect("dialogue_finished", _on_dialogue_finished)
		scene.connect("game_event_triggered", _on_dialogue_triggered_event)
		
	# 4. Combat Manager
	if scene.has_signal("combat_finished"):
		scene.connect("combat_finished", _on_combat_finished)
		print("🔗 Main: Connected Combat signals successfully!")

# --- SIGNAL RECEIVERS ---

func _on_exploration_requested_dialogue(event: GameEvent) -> void:
	var dialogue_box = _transition_to_scene(DIALOGUE_SCENE_PATH)
	if dialogue_box and dialogue_box.has_method("start_dialogue"):
		dialogue_box.start_dialogue(event)

func _on_dialogue_finished() -> void:
	await get_tree().process_frame
	if _current_combat_data != null: 
		return
		
	# Volta para o Hub Central em vez de empurrar direto para as missões
	_transition_to_scene(EXPLORATION_SCENE_PATH)

func _on_dialogue_triggered_event(event: GameEvent) -> void:
	if event == null: return
	
	match event.action_type:
		GameEvent.ActionType.START_COMBAT:
			if event.combat_data == null:
				push_error("Main: START_COMBAT triggered but combat_data is null!")
				return
				
			print("⚔️ Main: Dialogue event triggered combat! Transitioning...")
			_current_combat_data = event.combat_data
			
			var combat_arena = _transition_to_scene(COMBAT_SCENE_PATH)
			if combat_arena and combat_arena.has_method("initialize_combat"):
				combat_arena.initialize_combat(_current_combat_data)

		GameEvent.ActionType.MODIFY_ATTRIBUTE:
			if event.hero_id != "":
				if event.hp_modifier != 0: 
					PlayerData.update_hp_by_id(event.hero_id, event.hp_modifier)
			else:
				if event.hp_modifier != 0:
					for id in PlayerData.active_party: 
						PlayerData.update_hp_by_id(id, event.hp_modifier)
						
		GameEvent.ActionType.FULL_HEAL:
			if event.hero_id != "":
				var hero = PlayerData.get_hero(event.hero_id)
				if hero and hero.has_method("total_recovery"): 
					hero.total_recovery()
			else:
				PlayerData.heal_active_party()


func _on_combat_finished(victory: bool) -> void:
	print("🏁 Main: Combat finished! Victory: ", victory)
	
	if victory:
		if not PlayerData.active_mission_id.is_empty():
			if not PlayerData.completed_missions.has(PlayerData.active_mission_id):
				PlayerData.completed_missions.append(PlayerData.active_mission_id)
				print("🏅 [Main] Mission added to completed list: ", PlayerData.active_mission_id)
		
		if SaveManager.has_method("save_game"):
			SaveManager.save_game()
		
		# 🌟 Se houver um diálogo de história para tocar após a vitória (ex: cutscene de vitória)
		if _current_combat_data and _current_combat_data.victory_event != null:
			var post_combat_event = _current_combat_data.victory_event
			_current_combat_data = null
			
			# Dá um respiro de 1 frame para desvincular os sinais antigos com segurança
			await get_tree().process_frame
			_on_dialogue_triggered_event(post_combat_event)
			return
			
		# Se não houver diálogo pós-créditos, cura o time e volta direto para a navegação do Hub
		PlayerData.heal_active_party()
		_current_combat_data = null
		
		await get_tree().process_frame
		_transition_to_scene(EXPLORATION_SCENE_PATH)
	else:
		print("☠️ Main: Player defeated! Game Over logic goes here.")
		_current_combat_data = null
		# Se perder, você pode redirecionar para o menu principal ou hub
		_transition_to_scene(MAIN_MENU_PATH)

# --- NAVIGATOR CHANNELS ---

func _on_back_to_hub_requested() -> void:
	pass

func _on_missions_menu_requested() -> void:
	_transition_to_scene(EXPLORATION_SCENE_PATH)

func _on_barracks_menu_requested() -> void:
	_transition_to_scene(HERO_DETAILS_PATH)
