extends Button
signal card_clicked(hero_id: String)

@export var avatar_texture: TextureRect
@export var name_label: Label
@export var hp_label: Label
@export var lock_overlay: ColorRect
@export var margin_container: MarginContainer

var hero_id: String = ""
var displacement_tween: Tween 
var is_visually_selected: bool = false

# Registra o clique do botão no próprio Godot! [26]
func _pressed() -> void:
	card_clicked.emit(hero_id)

func initialize_card(id: String, hero_state: HeroState, is_in_party: bool) -> void:
	hero_id = id
	
	if hero_state.blueprint:
		name_label.text = hero_state.blueprint.character_name
	
	hp_label.text = "HP: %d/%d" % [hero_state.current_hp, hero_state.get_max_hp()]
	
	if avatar_texture and hero_state.blueprint and hero_state.blueprint.avatar_icon:
		avatar_texture.texture = hero_state.blueprint.avatar_icon
		
	
	# Inicializa o estado visual sem animação abrupta na primeira renderização
	is_visually_selected = is_in_party
	if margin_container:
		margin_container.position.x = 25.0 if is_in_party else 0.0
	
	# Define a cor inicial estática baseada na seleção
	self_modulate = Color(0.6, 1.0, 0.6, 1.0) if is_in_party else Color.WHITE

func _animate_displacement(selected: bool) -> void:
	if not margin_container: return
	
	# Se o estado não mudou, evita recriar tweens desnecessários [26]
	if is_visually_selected == selected and displacement_tween != null:
		return
		
	is_visually_selected = selected

	if displacement_tween and displacement_tween.is_valid():
		displacement_tween.kill()

	var target_offset = 25.0 if selected else 0.0
	
	# SMT Retro Style: Um verde vibrante translúcido para destacar a seleção
	var target_color = Color(0.5, 1.0, 0.5, 1.0) if selected else Color.WHITE

	displacement_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 1. Animação de Recuo Posicional (X) [26]
	displacement_tween.tween_property(margin_container, "position:x", target_offset, 0.18)
	
	# 2. Animação de Cor de Fundo no próprio Botão
	displacement_tween.tween_property(self, "self_modulate", target_color, 0.18)
