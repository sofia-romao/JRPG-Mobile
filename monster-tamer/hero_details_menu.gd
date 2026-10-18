# hero_details_menu.gd
extends Control
class_name HeroDetailsMenu

@export_category("Prefabs")
@export var hero_card_prefab: PackedScene 

@export_category("UI Panels")
@export var selection_panel: Control
@export var details_panel: Control

@export_category("Selection UI Elements")
@export var hero_list_container: VBoxContainer
@export var deploy_button: Button

@export_category("Details UI Components")
@export var avatar_texture: TextureRect
@export var chat_button: Button         # 💬 O BOTÃO MARAVILHOSO ESTÁ DE VOLTA!
@export var name_label: Label
@export var stats_label: Label
@export var skills_list_container: VBoxContainer
@export var skin_list_container: HBoxContainer 

@export_category("Dialogue Components")
@export var dialogue_label: RichTextLabel
@export var text_click_sfx: AudioStream 

@export_category("Narrative Database")
## hero_owner_id ("altria", "mash") -> { "common": Array[String], "level_up": Dictionary }
@export var dialogue_database: Dictionary = {}

var current_hero_owner: String = ""
var _current_tween: Tween = null
var _last_char_count: int = 0

func _ready() -> void:
	if selection_panel: selection_panel.show()
	if details_panel: details_panel.hide()
	
	if deploy_button and not deploy_button.pressed.is_connected(_on_deploy_button_pressed):
		deploy_button.pressed.connect(_on_deploy_button_pressed)
		
	# 💬 Conecta o clique do botão maravilhoso de conversa!
	if chat_button and not chat_button.pressed.is_connected(_on_chat_button_pressed):
		chat_button.pressed.connect(_on_chat_button_pressed)
		
	PlayerData.synchronize_active_party()
	_populate_hero_selection_list()
	_update_deploy_button_status()
## Popula a lista inicial isolando os nós visuais das instâncias de cartões
func _populate_hero_selection_list() -> void:
	if not hero_list_container or not hero_card_prefab: return
	
	for child in hero_list_container.get_children():
		child.queue_free()
			
	for hero_owner in PlayerData.active_kits:
		var current_active_kit_id = PlayerData.active_kits[hero_owner]
		var hero_state: HeroState = PlayerData.get_hero(current_active_kit_id)
		
		if hero_state and hero_state.blueprint:
			var new_card = hero_card_prefab.instantiate()
			hero_list_container.add_child(new_card)
			
			# 🚀 FORÇA ISOLAMENTO VISUAL: Injeta o texto direto nas propriedades do nó instanciado
			# antes mesmo do initialize_card rodar, garantindo que o cache da UI seja quebrado!
			if new_card.get("name_label") and new_card.name_label:
				new_card.name_label.text = hero_state.blueprint.character_name
				
			if new_card.has_method("initialize_card"):
				new_card.initialize_card(hero_owner, hero_state, false)
				
				# 💎 GARANTIA EXTRALIMPA: Força a sobrescrita do label após a inicialização nativa
				if new_card.name_label:
					new_card.name_label.text = hero_state.blueprint.character_name
				
			if new_card.has_signal("card_clicked"):
				new_card.card_clicked.connect(func(owner_id): open_hero_details(owner_id))
				
	_update_deploy_button_status()

## Abre a ficha íntima carregando o kit ativo atual e montando o carrossel de skins
func open_hero_details(hero_owner: String) -> void:
	current_hero_owner = hero_owner
	
	if selection_panel: selection_panel.hide()
	if details_panel: details_panel.show()
	
	var active_kit_id = PlayerData.active_kits[hero_owner]
	var hero_state = PlayerData.get_hero(active_kit_id)
	
	_update_ui_display(hero_state)
	_populate_skin_selector_list()
	_start_conversation()

## Popula o carrossel horizontal com todas as skins desbloqueadas daquele herói
func _populate_skin_selector_list() -> void:
	if not skin_list_container or not hero_card_prefab: return
	
	for child in skin_list_container.get_children():
		child.queue_free()
		
	var unlocked_list: Array[String] = []
	match current_hero_owner:
		"altria": unlocked_list = PlayerData.unlocked_altria_kits
		"mash": unlocked_list = PlayerData.unlocked_mash_kits
		"hero3": unlocked_list = PlayerData.unlocked_hero3_kits
		
	for kit_id in unlocked_list:
		var hero_state = PlayerData.get_hero(kit_id)
		if not hero_state: continue
		
		var is_equipped = (PlayerData.active_kits[current_hero_owner] == kit_id)
		
		var new_card = hero_card_prefab.instantiate()
		skin_list_container.add_child(new_card)
		
		if new_card.has_method("initialize_card"):
			new_card.initialize_card(kit_id, hero_state, is_equipped)
			
		if new_card.has_signal("card_clicked"):
			new_card.card_clicked.connect(func(chosen_kit_id):
				PlayerData.active_kits[current_hero_owner] = chosen_kit_id
				PlayerData.synchronize_active_party() 
				
				_update_ui_display(hero_state)
				_populate_skin_selector_list()
				_start_conversation()
				_update_deploy_button_status() 
			)

func _update_ui_display(hero_state: HeroState) -> void:
	if not hero_state or not hero_state.blueprint: return
	var bp = hero_state.blueprint
	
	if avatar_texture and bp.avatar_icon:
		avatar_texture.texture = bp.avatar_icon
		avatar_texture.modulate = Color(1.6, 1.6, 1.6, 1.0) 
		var flash_tween = create_tween()
		flash_tween.tween_property(avatar_texture, "modulate", Color.WHITE, 0.25)
		
	name_label.text = bp.character_name
	
	stats_label.text = "HP: %d/%d\nATK: %d\nSPD: %d" % [
		hero_state.current_hp,
		hero_state.get_max_hp(),
		hero_state.get_attack(),
		hero_state.get_speed()
	]
	
	_populate_skills_list(hero_state)

func _populate_skills_list(hero_state: HeroState) -> void:
	for child in skills_list_container.get_children(): child.queue_free()
	if not hero_state: return
	for skill_id in hero_state.get_available_skills():
		var skill_data: SkillData = SkillsDatabase.get_skill(skill_id)
		if skill_data:
			var label = Label.new()
			skills_list_container.add_child(label)
			var cost_text = str(skill_data.mp_cost) + "% HP" if skill_data.element_type == "PHYSICAL" else str(skill_data.mp_cost) + " MP"
			label.text = "%-12s %6s" % [skill_data.name, cost_text]

func _start_conversation() -> void:
	if not current_hero_owner: return
	
	# Puxa o ID do Kit que está equipado no momento (ex: "altria", "altria_frost") [10]
	var active_kit_id = PlayerData.active_kits[current_hero_owner]
	var hero_state = PlayerData.get_hero(active_kit_id)
	if not hero_state: return
	
	var chosen_text: String = "..."
	
	# 1. Verifica se o dono do herói ("altria", "mash") existe no banco de dados [10]
	if dialogue_database.has(current_hero_owner) and dialogue_database[current_hero_owner] is Dictionary:
		var hero_data: Dictionary = dialogue_database[current_hero_owner]
		
		# 2. PRIORITY: Procura se existe uma fala específica para o KIT equipado!
		if hero_data.has("kit_reactions") and hero_data["kit_reactions"] is Dictionary:
			var kit_dict: Dictionary = hero_data["kit_reactions"]
			if kit_dict.has(active_kit_id):
				chosen_text = kit_dict[active_kit_id]
				_display_typewriter_text(chosen_text)
				return
				
		# 3. FALLBACK: Se não tiver fala pro kit, sorteia uma frase comum do personagem [10]
		if hero_data.has("common") and hero_data["common"] is Array:
			var common_list: Array = hero_data["common"]
			if not common_list.is_empty(): 
				chosen_text = common_list.pick_random()
	else:
		# Frase padrão caso o Inspetor esteja em branco [10]
		chosen_text = "Ready to deploy, Commander. All systems calibrated." 
		
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

## 💬 Acionado quando o jogador clica fisicamente no ChatButton para ouvir uma nova frase!
func _on_chat_button_pressed() -> void:
	_start_conversation()

func close_hero_details() -> void:
	current_hero_owner = ""
	if _current_tween: _current_tween.kill()
	if details_panel: details_panel.hide()
	if selection_panel: selection_panel.show()
	_populate_hero_selection_list()
	_update_deploy_button_status()
## Checa se os 3 heróis possuem kits válidos equipados e se há uma missão ativa
func _update_deploy_button_status() -> void:
	if not deploy_button: return
	
	if PlayerData.selected_mission_data == null:
		deploy_button.text = "Select a Mission First"
		deploy_button.disabled = true
		return

	# 🌐 PROTEÇÃO DA WEB: Checa se a chave salva na string existe de verdade dentro do dicionário físico!
	var altria_ready: bool = PlayerData.active_kits.has("altria") and PlayerData.hero_collection.has(PlayerData.active_kits["altria"])
	var mash_ready: bool = PlayerData.active_kits.has("mash") and PlayerData.hero_collection.has(PlayerData.active_kits["mash"])
	var hero3_ready: bool = PlayerData.active_kits.has("hero3") and PlayerData.hero_collection.has(PlayerData.active_kits["hero3"])
	
	var party_complete: bool = altria_ready and mash_ready and hero3_ready

	if party_complete:
		deploy_button.text = "[ DEPLOY TEAM ]"
		deploy_button.disabled = false
	else:
		deploy_button.text = "Equip All 3 Heroes"
		deploy_button.disabled = true


func _on_back_button_pressed() -> void:
	if details_panel and details_panel.visible:
		close_hero_details()
	else:
		var main = get_tree().root.get_node_or_null("MainController")
		if main and main.has_method("_transition_to_scene"):
			main._transition_to_scene(main.EXPLORATION_SCENE_PATH)

func _on_deploy_button_pressed() -> void:
	if PlayerData.selected_mission_data != null:
		var mission = PlayerData.selected_mission_data
		PlayerData.active_mission_id = mission.id
		
		PlayerData.heal_active_party()
		
		print("🚀 Barracks: Deploying squad into mission: ", mission.title)
		var main = get_tree().root.get_node_or_null("MainController")
		if main and main.has_method("_on_exploration_requested_dialogue"):
			main._on_exploration_requested_dialogue(mission.start_event)
