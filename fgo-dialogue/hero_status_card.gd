# HeroStatusCard.gd
extends MarginContainer

@export var name_label: Label
@export var level_label: Label
@export var hp_label: Label

var _associated_state: HeroState

func configurar_card(hero_state: HeroState) -> void:
	_associated_state = hero_state
	name = hero_state.blueprint.id 
	
	# Preenche usando as propriedades corrigidas em inglês
	name_label.text = hero_state.blueprint.character_name
	level_label.text = "Lv. " + str(hero_state.get_nivel())
	_update_hp_text(hero_state.hp_atual, hero_state.get_max_hp())
	
	if hero_state.has_signal("hp_alterado") and not hero_state.hp_alterado.is_connected(_on_hero_hp_changed):
		hero_state.hp_alterado.connect(_on_hero_hp_changed)

func animar_selecao(selected: bool) -> void:
	var tween = create_tween()
	var target_margin = 25 if selected else 0
	tween.tween_property(self, "theme_override_constants/margin_left", target_margin, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _on_hero_hp_changed(new_hp: int, max_hp: int, _change: int) -> void:
	_update_hp_text(new_hp, max_hp)

func _update_hp_text(current: int, maximum: int) -> void:
	hp_label.text = "HP: " + str(current) + "/" + str(maximum)
