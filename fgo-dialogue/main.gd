# main.gd
extends Node
class_name MainController

@export_category("Containers")
@export var scene_container: Node

const EXPLORATION_SCENE_PATH = "res://test_exploration_scene.tscn"
const DIALOGUE_SCENE_PATH = "res://scenes/dialogue_box.tscn"
const COMBAT_SCENE_PATH = "res://scenes/combat_arena.tscn"

var _current_active_scene: Node = null
var _current_combat_data: CombatData = null

func _ready() -> void:
	if scene_container == null:
		push_error("Main: The 'scene_container' node was not assigned in the Inspector!")
		return
	_transition_to_scene(EXPLORATION_SCENE_PATH)

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
	# 1. Exploration Scene
	if scene.has_signal("mission_started"):
		scene.connect("mission_started", _on_exploration_requested_dialogue)
		
	# 2. Dialogue Manager
	if scene is DialogueManager:
		scene.dialogue_finished.connect(_on_dialogue_finished)
		scene.game_event_triggered.connect(_on_dialogue_triggered_event)
		
	# 3. Combat Manager
	if scene is CombatManager:
		scene.combat_finished.connect(_on_combat_finished)

# --- SIGNAL RECEIVERS ---

func _on_exploration_requested_dialogue(event: GameEvent) -> void:
	var dialogue_box = _transition_to_scene(DIALOGUE_SCENE_PATH) as DialogueManager
	if dialogue_box:
		dialogue_box.start_dialogue(event)

<<<<<<< Updated upstream
# O Diálogo acabou normalmente (sem lutas) -> Devolve o jogador para a Exploração
func _on_dialogue_terminou() -> void:
	# 🔴 O SEGREDO ESTÁ AQUI: Espera um frame para garantir que os sinais 
	# de GameEvent atualizaram o PlayerData antes de renderizar o mapa!
	await get_tree().process_frame
	
	print("\n📊 [STATUS DO TIME SALVO NO AUTOLOAD]")
	for heroi_id in PlayerData.party_ativa:
		var dados = PlayerData.get_dados_heroi(heroi_id)
		print("👤 %s -> HP Atual: %d/100" % [dados.get("nome"), dados.get("hp_atual")])
	print("📌 Estado da Missão Em Andamento: ", PlayerData.missao_em_andamento)
	print("-----------------------------------------\n")
	
	_transicionar_para_cena(EXPLORATION_SCENE_PATH)
# O Diálogo fez uma escolha que gerou um GameEvent (ex: Iniciar Batalha)
func _on_dialogue_disparou_evento(event: GameEvent) -> void:
	if event == null: return
	
	PlayerData.missao_em_andamento = event.set_missao_em_andamento
	if event.heroi_id != "" and event.hp_modifier != 0:
		if PlayerData.colecao_herois.has(event.heroi_id):
			var hp_velho = PlayerData.colecao_herois[event.heroi_id]["hp_atual"]
			# Executa a matemática cega pura baseada no Resource
			PlayerData.atualizar_hp(event.heroi_id, hp_velho + event.hp_modifier)

# O Combate acabou -> Devolve o jogador para a Exploração
func _on_combate_terminou(vitoria: bool) -> void:
	print("🏁 Main: Batalha encerrada! Vitória: ", vitoria, ". Voltando para a Exploração...")
	_transicionar_para_cena(EXPLORATION_SCENE_PATH)
=======
func _on_dialogue_finished() -> void:
	await get_tree().process_frame
	_transition_to_scene(EXPLORATION_SCENE_PATH)

func _on_dialogue_triggered_event(event: GameEvent) -> void:
	if event == null: return
	
	PlayerData.missao_em_andamento = event.is_mission_in_progress
	
	match event.action_type:
		GameEvent.ActionType.START_COMBAT:
			if event.combat_data == null:
				push_error("Main: START_COMBAT triggered but combat_data is null!")
				return
				
			print("⚔️ Main: Dialogue event triggered combat! Transitioning...")
			_current_combat_data = event.combat_data
			
			var combat_arena = _transition_to_scene(COMBAT_SCENE_PATH) as CombatManager
			if combat_arena:
				combat_arena.initialize_combat(_current_combat_data)
			
		GameEvent.ActionType.COMPLETE_MISSION:
			PlayerData.missao_em_andamento = false
			PlayerData.curar_party_ativa()
			
		GameEvent.ActionType.MODIFY_ATTRIBUTE:
			if event.hero_id != "":
				if event.hp_modifier != 0: 
					PlayerData.atualizar_hp_por_id(event.hero_id, event.hp_modifier)
			else:
				if event.hp_modifier != 0:
					for id in PlayerData.party_ativa: 
						PlayerData.atualizar_hp_por_id(id, event.hp_modifier)
						
		GameEvent.ActionType.FULL_HEAL:
			if event.hero_id != "":
				var hero = PlayerData.get_heroi(event.hero_id)
				if hero: hero.curar_total()
			else:
				PlayerData.heal_active_party()

func _on_combat_finished(victory: bool) -> void:
	print("🏁 Main: Combat finished! Victory: ", victory)
	
	if victory:
		if _current_combat_data and _current_combat_data.victory_event != null:
			var post_combat_event = _current_combat_data.victory_event
			_current_combat_data = null
			_on_dialogue_triggered_event(post_combat_event)
			return
			
		if not PlayerData.missao_em_andamento:
			PlayerData.curar_party_ativa()
			
		_current_combat_data = null
		_transition_to_scene(EXPLORATION_SCENE_PATH)
	else:
		print("☠️ Main: Player defeated! Game Over logic goes here.")
		_current_combat_data = null
>>>>>>> Stashed changes
