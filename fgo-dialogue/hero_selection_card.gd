# hero_selection_card.gd (Apenas a função de inicialização traduzida)
extends Button
signal card_clicked(hero_id: String)

@export var avatar_texture: TextureRect
@export var name_label: Label
@export var hp_label: Label
@export var lock_overlay: ColorRect
@export var margin_container: MarginContainer

var hero_id: String = ""

func initialize_card(id: String, hero_state: HeroState, is_in_party: bool, is_locked: bool) -> void:
	hero_id = id
	name_label.text = hero_state.blueprint.character_name
	hp_label.text = "HP: %d/%d" % [hero_state.current_hp, hero_state.get_max_hp()]
	
	if avatar_texture and hero_state.blueprint.avatar_icon:
		avatar_texture.texture = hero_state.blueprint.avatar_icon
		
	if lock_overlay:
		lock_overlay.visible = is_locked
	disabled = is_locked
	
	_animate_displacement(is_in_party)
var displacement_tween: Tween # Guarda a referência do tween para evitar sobreposição


var is_visually_selected: bool = false

func _animate_displacement(selected: bool) -> void:
	if not margin_container: return
	
	# 1. Se o estado visual não mudou, ignora para não estragar tweens ativos
	if is_visually_selected == selected:
		return
		
	is_visually_selected = selected

	# 2. ESPERA UM FRAME: Dá tempo para o ScrollContainer/GridContainer terminar de 
	# calcular o layout inicial da tela e não atropelar o nosso Tween!
	await get_tree().process_frame
	
	# Proteção caso o cartão tenha sido deletado enquanto esperávamos o frame
	if not is_inside_tree() or not margin_container: 
		return

	if displacement_tween and displacement_tween.is_valid():
		displacement_tween.kill()

	# 3. Em vez de mover o nó fisicamente (o que o contêiner proíbe),
	# nós alteramos a margem interna real usando a sintaxe segura do Godot 4
	var target_margin = 25 if selected else 0
	var current_margin = margin_container.get_theme_constant("margin_left")

	displacement_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Animamos a margem interna. Isso força o conteúdo a deslizar de forma nativa e segura!
	displacement_tween.tween_method(
		func(val: int): margin_container.add_theme_constant_override("margin_left", val),
		current_margin,
		target_margin,
		0.18
	)
