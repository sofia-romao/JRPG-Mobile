# hero_status_card.gd
extends MarginContainer

@export var name_label: Label
@export var level_label: Label
@export var hp_label: Label
@export var mp_label: Label # 🔮 NOVO: Arraste o seu novo nó de texto de MP aqui pelo Inspector!

var _associated_state: HeroState

## Configura os dados iniciais do card injetados dinamicamente pelo CombatManager
func configurar_card(hero_state: HeroState) -> void:
	_associated_state = hero_state
	name = hero_state.blueprint.id 
	
	if name_label and hero_state.blueprint:
		name_label.text = hero_state.blueprint.character_name
		
	if level_label:
		level_label.text = "Lv. " + str(hero_state.get_level())
		
	_update_hp_text(hero_state.current_hp, hero_state.get_max_hp())
	_update_mp_text(hero_state.current_mp, hero_state.get_max_mp()) # 🔮 Desenha o MP inicial na arena
	
	# --- CONEXÃO DOS SINAIS DE EVENTO DO MOTOR ---
	if hero_state.has_signal("changed_hp") and not hero_state.changed_hp.is_connected(_on_hero_hp_changed):
		hero_state.changed_hp.connect(_on_hero_hp_changed)
		
	if hero_state.has_signal("changed_mp") and not hero_state.changed_mp.is_connected(_on_hero_mp_changed):
		hero_state.changed_mp.connect(_on_hero_mp_changed)

## Animação clássica de recuo/deslocamento lateral ao alternar o turno do herói ativo
func animar_selecao(selected: bool) -> void:
	var tween = create_tween()
	var target_margin = 25 if selected else 0
	tween.tween_property(self, "theme_override_constants/margin_left", target_margin, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

# --- REATORES DE SINAL (ATIVADOS EM TEMPO REAL) ---

func _on_hero_hp_changed(new_hp: int, max_hp: int, _change: int) -> void:
	_update_hp_text(new_hp, max_hp)

func _on_hero_mp_changed(new_mp: int, max_mp: int, _change: int) -> void:
	_update_mp_text(new_mp, max_mp)

# --- RE-RENDERIZADORES DE TEXTO ---

func _update_hp_text(current: int, maximum: int) -> void:
	if hp_label:
		hp_label.text = "HP: " + str(current) + "/" + str(maximum)

func _update_mp_text(current: int, maximum: int) -> void:
	if mp_label:
		mp_label.text = "MP: " + str(current) + "/" + str(maximum)
