# party_selection_menu.gd
extends Control
class_name PartySelectionMenu

@export_category("Scene Configuration")
@export var card_prefab: PackedScene 

@export_category("UI Nodes")
@export var grid_container: GridContainer
@export var locked_warning_label: Label

func _ready() -> void:
	if not card_prefab:
		push_error("PartySelectionMenu: Forgot to assign card_prefab in the Inspector!")
		return
	if not grid_container:
		push_error("PartySelectionMenu: Forgot to assign grid_container in the Inspector!")
		return
		
	update_menu_ui()

func update_menu_ui() -> void:
	for child in grid_container.get_children():
		child.queue_free()
		
	var is_locked: bool = PlayerData.mission_in_progress
	if locked_warning_label:
		locked_warning_label.visible = is_locked
		locked_warning_label.text = "⚠️ MISSION IN PROGRESS - PARTY LOCKED"
		
	for hero_id in PlayerData.hero_collection:
		var hero_state: HeroState = PlayerData.hero_collection[hero_id]
		var is_in_party: bool = PlayerData.active_party.has(hero_id)
		
		var new_card = card_prefab.instantiate()
		grid_container.add_child(new_card)
		
		# Sincronizado com o método em inglês do HeroSelectionCard
		if new_card.has_method("initialize_card"):
			new_card.initialize_card(hero_id, hero_state, is_in_party, is_locked)
		elif new_card.has_method("configurar_card"):
			new_card.configurar_card(hero_state)
			
		new_card.card_clicked.connect(_on_card_selected)

func _on_card_selected(hero_id: String) -> void:
	if PlayerData.mission_in_progress: return
		
	if PlayerData.active_party.has(hero_id):
		PlayerData.active_party.erase(hero_id)
	else:
		if PlayerData.active_party.size() < PlayerData.MAX_PARTY_SIZE:
			PlayerData.active_party.append(hero_id)
			
	for card in grid_container.get_children():
		var id = card.get("hero_id") if "hero_id" in card else card.name
		var hero_state = PlayerData.get_hero(id)
		var is_in_party = PlayerData.active_party.has(id)
		var is_locked = PlayerData.mission_in_progress
		
		if card.has_method("initialize_card"):
			card.initialize_card(id, hero_state, is_in_party, is_locked)
