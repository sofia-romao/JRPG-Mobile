# test_exploration_scene.gd
extends Control

signal mission_started(event: GameEvent)
signal mission_aborted

@export var mission_button: Button
@export var abort_button: Button

# ❄️ Arraste seu arquivo 'jack_frost.tres' aqui pelo painel Inspector!
@export var test_enemy: EnemyData 

func _ready() -> void:
	_update_map_ui()
	if test_enemy == null:
		push_warning("Exploration: Don't forget to assign 'jack_frost.tres' in the Inspector!")

func _update_map_ui() -> void:
	if PlayerData.mission_in_progress:
		mission_button.text = "Continue Mission (Part 2)"
		abort_button.visible = true
	else:
		mission_button.text = "Start Mission"
		abort_button.visible = false

func _on_botao_missao_pressed() -> void:
	var event = GameEvent.new()
	var new_lines: Array[StoryLine] = []
	var new_choices: Array[StoryChoice] = []
	
	if not PlayerData.mission_in_progress:
		# --- PART 1: JACK FROST EMBUSH ---
		var l1 = StoryLine.new()
		l1.character_name = "Mash"
		l1.text = "Senpai! A wild Jack Frost blocks the corridor! Prepare for battle!"
		new_lines.append(l1)
		
		# 1. Configura os dados do combate em inglês
		var combat_setup = CombatData.new()
		combat_setup.enemy = test_enemy
		
		# 2. Configura a ação de combate no GameEvent
		var action_combat = GameEvent.new()
		action_combat.action_type = GameEvent.ActionType.START_COMBAT
		action_combat.is_mission_in_progress = true 
		action_combat.combat_data = combat_setup
		
		# 3. Injeta a opção no diálogo
		var choice = StoryChoice.new()
		choice.choice_text = "Attack Jack Frost!"
		choice.trigger_game_event = action_combat
		new_choices.append(choice)
		
	else:
		# --- PART 2: SAFE ROOM REACHED ---
		var l2 = StoryLine.new()
		l2.character_name = "Mash"
		l2.text = "Uff, we defeated it and reached the safe room! Team fully restored!"
		new_lines.append(l2)
		
		var choice_end = StoryChoice.new()
		choice_end.choice_text = "Rest"
		
		var action_heal = GameEvent.new()
		action_heal.action_type = GameEvent.ActionType.FULL_HEAL
		action_heal.is_mission_in_progress = false 
		
		choice_end.trigger_game_event = action_heal
		new_choices.append(choice_end)
		
	event.dialogue_lines = new_lines
	event.choices = new_choices
	
	print("🚀 [Exploration] Emitting 'mission_started' with Jack Frost setup...")
	mission_started.emit(event)

func _on_abort_button_pressed() -> void:
	PlayerData.mission_in_progress = false
	PlayerData.heal_active_party()
	print("❌ [Exploration] Mission aborted! Team fully healed.")
	_update_map_ui()
