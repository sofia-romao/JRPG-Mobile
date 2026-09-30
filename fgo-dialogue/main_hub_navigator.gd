# main_hub_navigator.gd
extends Control
class_name MainHubNavigator

@export var missions_button: Button
@export var barracks_button: Button
@export var menu_click_sfx: AudioStream

func _ready() -> void:
	if missions_button: missions_button.pressed.connect(_on_missions_pressed)
	if barracks_button: barracks_button.pressed.connect(_on_barracks_pressed)

func _on_missions_pressed() -> void:
	_play_click_sound()
	var main = get_tree().root.get_node_or_null("MainController")
	if main and main.has_method("_transition_to_scene"):
		main._transition_to_scene(main.EXPLORATION_SCENE_PATH)

func _on_barracks_pressed() -> void:
	_play_click_sound()
	var main = get_tree().root.get_node_or_null("MainController")
	if main and main.has_method("_transition_to_scene"):
		main._transition_to_scene(main.HERO_DETAILS_PATH)

func _play_click_sound() -> void:
	if menu_click_sfx:
		AudioManager.play_sfx(menu_click_sfx)
