# main_menu.gd
extends Control
class_name MainMenu

# 🆕 Sinal adicionado para a MainController escutar e gerenciar a troca de cena
signal continue_pressed

@export_category("UI Panels")
@export var title_panel: Control
@export var confirm_panel: Control 

@export_category("UI Controls")
@export var continue_button: Button 

@export_category("Story Illustration")
@export var story_art_display: TextureRect
@export var art_prologue: Texture2D 
@export var art_chapter_1: Texture2D 

const SAVE_PATH = "user://savegame.tres"

func _ready() -> void:
	if title_panel: title_panel.show()
	if confirm_panel: confirm_panel.hide() 
	
	_evaluate_save_file_and_art()

func _evaluate_save_file_and_art() -> void:
	var save_exists: bool = ResourceLoader.exists(SAVE_PATH)
	
	if continue_button:
		continue_button.disabled = not save_exists
		
	if save_exists:
		var save_data = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as SaveGameData
		if save_data and not save_data.completed_missions.is_empty():
			_update_story_illustration(save_data.completed_missions.back())
			return
			
	_update_story_illustration("") 

# --- TITLE SCREEN INTERACTIONS ---

func _on_new_game_pressed() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		if confirm_panel: confirm_panel.show()
	else:
		_execute_new_game()

func _on_continue_pressed() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		_execute_continue()

func _on_exit_pressed() -> void:
	get_tree().quit()

# --- OVERWRITE POP-UP INTERACTIONS ---

func _on_confirm_overwrite_pressed() -> void:
	_execute_new_game()

func _on_cancel_overwrite_pressed() -> void:
	if confirm_panel: confirm_panel.hide()

# --- FLOW MOTORS ---

func _update_story_illustration(last_completed_mission_id: String) -> void:
	if not story_art_display: return
	
	match last_completed_mission_id:
		"jack_frost_01":
			story_art_display.texture = art_chapter_1 
		_:
			story_art_display.texture = art_prologue 

func _execute_new_game() -> void:
	print("✨ Menu: Starting a fresh NEW GAME!")
	
	PlayerData.active_mission_id = ""
	PlayerData.completed_missions.clear()
	PlayerData.active_party.clear()
	
	for id in PlayerData.hero_collection:
		var hero = PlayerData.hero_collection[id]
		if hero:
			hero.current_exp = 0
			if hero.has_method("full_heal"):
				hero.full_heal()
			
	if SaveManager.has_method("save_game"):
		SaveManager.save_game()
		
	_enter_game_world()

func _execute_continue() -> void:
	print("📂 Menu: Loading existing progress...")
	if SaveManager.has_method("load_game"):
		var success = SaveManager.load_game()
		if success:
			_enter_game_world()

## Ajustado para emitir o sinal. A MainController vai pegar e abrir o Hub!
func _enter_game_world() -> void:
	var main = get_tree().root.get_node_or_null("MainController")
	if main and main.has_method("_transition_to_scene"):
		# Usando o seu método original, mas apontando para o caminho do Hub!
		main._transition_to_scene(main.HUB_NAVIGATOR_PATH)
