# main_menu.gd
extends Control
class_name MainMenu

@export_category("UI Panels")
@export var title_panel: Control
@export var confirm_panel: Control # Seu pop-up simples de "Overwrite Save?"

@export_category("UI Controls")
@export var continue_button: Button # Botão que será desativado se não houver save

@export_category("Story Illustration")
@export var story_art_display: TextureRect
# 🖼️ Arraste as suas ilustrações de progresso monocromáticas aqui no Inspector!
@export var art_prologue: Texture2D # Imagem padrão inicial
@export var art_chapter_1: Texture2D # Imagem após vencer o Jack Frost

const SAVE_PATH = "user://savegame.tres"

func _ready() -> void:
	# Inicialização direta usando os métodos nativos do Godot 4!
	if title_panel: title_panel.show()
	if confirm_panel: confirm_panel.hide() # Começa o jogo com o pop-up escondido
	
	_evaluate_save_file_and_art()

## Checa se o arquivo de save existe para liberar o botão Continue e definir a ilustração
func _evaluate_save_file_and_art() -> void:
	var save_exists: bool = ResourceLoader.exists(SAVE_PATH)
	
	if continue_button:
		continue_button.disabled = not save_exists
		
	if save_exists:
		# Carrega temporariamente apenas para escanear a flag de história
		var save_data = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as SaveGameData
		if save_data and not save_data.completed_missions.is_empty():
			_update_story_illustration(save_data.completed_missions.back())
			return
			
	_update_story_illustration("") # Sem save ou sem missões concluídas mostra o Prólogo

# --- INTERAÇÕES DA TELA DE TÍTULO ---

func _on_new_game_pressed() -> void:
	# Se já existe um save no PC, mostra o pop-up na tela usando show()
	if ResourceLoader.exists(SAVE_PATH):
		if confirm_panel: confirm_panel.show()
	else:
		_execute_new_game()

func _on_continue_pressed() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		_execute_continue()

func _on_exit_pressed() -> void:
	get_tree().quit()

# --- INTERAÇÕES DO POP-UP DE CONFIRMAÇÃO ---

func _on_confirm_overwrite_pressed() -> void:
	_execute_new_game()

func _on_cancel_overwrite_pressed() -> void:
	# O jogador desistiu? Esconde o pop-up na hora usando hide()
	if confirm_panel: confirm_panel.hide()

# --- MOTORES DE FLUXO ---

func _update_story_illustration(last_completed_mission_id: String) -> void:
	if not story_art_display: return
	
	# 🎨 Troca a arte da tela de título baseado na última missão salva!
	match last_completed_mission_id:
		"jack_frost_01":
			story_art_display.texture = art_chapter_1 # Venceu o Jack Frost
		_:
			story_art_display.texture = art_prologue # Arte inicial padrão

func _execute_new_game() -> void:
	print("✨ Menu: Starting a fresh NEW GAME!")
	
	# Reseta as variáveis do PlayerData na memória limpa
	PlayerData.is_mission_in_progress = false
	PlayerData.active_mission_id = ""
	PlayerData.completed_missions.clear()
	PlayerData.active_party.clear()
	
	# Restaura a vida de todos os heróis da coleção para o padrão inicial
	for id in PlayerData.hero_collection:
		var hero = PlayerData.hero_collection[id]
		if hero:
			hero.current_exp = 0
			hero.full_heal()
			
	# Força o SaveManager a gravar o arquivo zerado no computador
	if SaveManager.has_method("save_game"):
		SaveManager.save_game()
		
	_enter_game_world()

func _execute_continue() -> void:
	print("📂 Menu: Loading existing progress...")
	if SaveManager.has_method("load_game"):
		var success = SaveManager.load_game()
		if success:
			_enter_game_world()

func _enter_game_world() -> void:
	var main = get_tree().root.get_node_or_null("MainController")
	if main and main.has_method("_transition_to_scene"):
		main._transition_to_scene(main.EXPLORATION_SCENE_PATH)
