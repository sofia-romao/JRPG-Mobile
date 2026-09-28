# hero_details_menu.gd
extends Control
class_name HeroDetailsMenu

@export_category("Prefabs")
@export var hero_card_prefab: PackedScene # Seu prefab de cartão de herói existente!

@export_category("UI Panels")
@export var selection_panel: Control      # Painel da lista inicial
@export var details_panel: Control        # Painel íntimo de status e papo

@export_category("Selection UI Elements")
@export var hero_list_container: VBoxContainer # Onde os cartões vão nascer

@export_category("Details UI Components")
@export var avatar_texture: TextureRect
@export var name_label: Label
@export var level_label: Label
@export var stats_label: Label
@export var skills_list_container: VBoxContainer

@export_category("Dialogue Components")
@export var dialogue_label: RichTextLabel
@export var chat_button: Button
@export var text_click_sfx: AudioStream 

@export_category("Narrative Database")
## hero_id (String) -> { "common": Array[String], "level_up": Dictionary }
@export var dialogue_database: Dictionary = {}

var current_hero_state: HeroState
var _current_tween: Tween = null
var _last_char_count: int = 0

func _ready() -> void:
	if chat_button:
		chat_button.pressed.connect(_on_chat_button_pressed)
		
	# Inicializa mostrando a lista e escondendo os detalhes íntimos
	if selection_panel: selection_panel.show()
	if details_panel: details_panel.hide()
	
	# Popula a lista automática logo no primeiro frame
	_populate_hero_selection_list()

## 🆕 Varre a coleção salva do jogador e cria a lista física de cartões
func _populate_hero_selection_list() -> void:
	if not hero_list_container or not hero_card_prefab: return
	
	# Limpa cartões antigos por segurança
	for child in hero_list_container.get_children():
		child.queue_free()
		
	# Varre os heróis que o jogador possui no PlayerData
	for hero_id in PlayerData.hero_collection:
		var hero_state: HeroState = PlayerData.hero_collection[hero_id]
		
		# Instancia o seu cartão original
		var new_card = hero_card_prefab.instantiate()
		hero_list_container.add_child(new_card)
		
		# Inicializa o cartão usando a função dele (sem travas ou seleção de party)
		if new_card.has_method("initialize_card"):
			new_card.initialize_card(hero_id, hero_state, false)
			
		# Redireciona o clique do cartão para abrir a tela íntima deste herói!
		if new_card.has_signal("card_clicked"):
			new_card.card_clicked.connect(func(_id): open_hero_details(hero_state))

## 🆕 Transiciona da lista para os detalhes íntimos do herói selecionado
func open_hero_details(hero_state: HeroState) -> void:
	current_hero_state = hero_state
	
	# Alterna os painéis visualmente
	if selection_panel: selection_panel.hide()
	if details_panel: details_panel.show()
	
	_update_ui()
	_populate_skills_list()
	_start_conversation()

## Chamado pelo botão de voltar da sua tela íntima para retornar à lista de heróis
func close_hero_details() -> void:
	current_hero_state = null
	if _current_tween: _current_tween.kill()
	
	# Alterna de volta para a lista de seleção
	if details_panel: details_panel.hide()
	if selection_panel: selection_panel.show()

# --- CORE DETAILS FUNCTIONS (Mantidas do seu código original) ---

func _update_ui() -> void:
	if not current_hero_state or not current_hero_state.blueprint: return
	
	var bp = current_hero_state.blueprint
	var current_level = current_hero_state.get_level() # 🔢 Puxa o nível calculado via função!
	
	name_label.text = bp.character_name
	avatar_texture.texture = bp.avatar_icon
	level_label.text = "LV: %d" % current_level
	
	# Atualizado para usar suas funções nativas: get_max_hp, get_attack e get_speed
	stats_label.text = "HP: %d/%d\nATK: %d\nSPD: %d" % [
		current_hero_state.current_hp,
		current_hero_state.get_max_hp(),
		current_hero_state.get_attack(),
		current_hero_state.get_speed()
	]
func _populate_skills_list() -> void:
	for child in skills_list_container.get_children(): child.queue_free()
	if not current_hero_state: return
	for skill_id in current_hero_state.get_available_skills():
		var skill_data: SkillData = SkillsDatabase.get_skill(skill_id)
		if skill_data:
			var label = Label.new()
			skills_list_container.add_child(label)
			var cost_text = str(skill_data.mp_cost) + "% HP" if skill_data.element_type == "PHYSICAL" else str(skill_data.mp_cost) + " MP"
			label.text = "%-12s %6s" % [skill_data.name, cost_text]

## Selects the correct text line based on the hero's ID and level functions
func _start_conversation() -> void:
	if not current_hero_state or not current_hero_state.blueprint: return
	
	# Certifique-se de usar a String correspondente ao ID do seu herói na sua coleção
	# (Se o seu blueprint tiver uma variável 'id', use bp.id. Caso contrário, use o id vindo da coleção)
	var hero_id: String = ""
	if current_hero_state.blueprint.get("id"):
		hero_id = current_hero_state.blueprint.id
	else:
		# Fallback seguro caso você use o nome do blueprint como ID no dicionário
		hero_id = current_hero_state.blueprint.character_name.to_lower().replace(" ", "_")
		
	var current_level: int = current_hero_state.get_level() # 🔢 Puxa o nível via função!
	var chosen_text: String = "..." 
	
	# 1. Checks if the hero exists in the database
	if dialogue_database.has(hero_id) and dialogue_database[hero_id] is Dictionary:
		var hero_data: Dictionary = dialogue_database[hero_id]
		
		# 2. PRIORITY: Looks for a special level up quote
		if hero_data.has("level_up") and hero_data["level_up"] is Dictionary:
			var level_up_dict: Dictionary = hero_data["level_up"]
			if level_up_dict.has(current_level):
				chosen_text = level_up_dict[current_level]
				_display_typewriter_text(chosen_text)
				return
				
		# 3. FALLBACK: Sorters a random common quote
		if hero_data.has("common") and hero_data["common"] is Array:
			var common_list: Array = hero_data["common"]
			if not common_list.is_empty():
				chosen_text = common_list.pick_random()
	else:
		print("⚠️ Warning: ID '%s' not found in Inspector dialogue_database." % hero_id)
		chosen_text = "Hello! It is good to see you here." 

	_display_typewriter_text(chosen_text)
func _display_typewriter_text(text: String) -> void:
	if not dialogue_label: return
	dialogue_label.text = text
	dialogue_label.visible_characters = 0
	_last_char_count = 0
	if _current_tween: _current_tween.kill()
	_current_tween = create_tween()
	var duration = max(0.3, text.length() * 0.025)
	_current_tween.tween_property(dialogue_label, "visible_characters", text.length(), duration)
	_current_tween.parallel().tween_method(func(_v): _check_and_play_sfx(), 0, text.length(), duration)

func _check_and_play_sfx() -> void:
	var current_chars = dialogue_label.visible_characters
	if current_chars > _last_char_count:
		_last_char_count = current_chars
		var current_text = dialogue_label.text
		if current_chars <= current_text.length():
			var last_char = current_text[current_chars - 1]
			if last_char != " " and text_click_sfx: AudioManager.play_sfx(text_click_sfx)

func _on_chat_button_pressed() -> void:
	_start_conversation()

# O botão físico de voltar da sua cena (BackButton) agora faz o seguinte:
func _on_back_button_pressed() -> void:
	# Se o painel de detalhes estiver aberto, voltar primeiro para a lista de heróis
	if details_panel and details_panel.visible:
		close_hero_details()
	else:
		# Se já estiver na lista, aí sim volta para a tela intermediária (Hub Navigator)
		var main = get_tree().root.get_node_or_null("MainController")
		if main and main.has_method("_transition_to_scene"):
			main._transition_to_scene(main.HUB_NAVIGATOR_PATH)
