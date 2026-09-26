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

# Adicione esta linha para registrar o clique do botão no próprio Godot!
func _pressed() -> void:
	card_clicked.emit(hero_id)

func initialize_card(id: String, hero_state: HeroState, is_in_party: bool, is_locked: bool) -> void:
	hero_id = id
	print("--- DEBUG DO HERÓI ---")
	print("Objeto blueprint inteiro: ", hero_state.blueprint)
	if hero_state.blueprint:
		print("Variável character_name: '", hero_state.blueprint.character_name, "'")
	
	name_label.text = hero_state.blueprint.character_name
	hp_label.text = "HP: %d/%d" % [hero_state.current_hp, hero_state.get_max_hp()]
	
	if avatar_texture and hero_state.blueprint.avatar_icon:
		avatar_texture.texture = hero_state.blueprint.avatar_icon
		
	if lock_overlay:
		lock_overlay.visible = is_locked
	disabled = is_locked
	
	# Chamamos a animação diretamente
	_animate_displacement(is_in_party)

func _animate_displacement(selected: bool) -> void:
	if not margin_container: return
	
	# Se o estado não mudou, não faz nada
	if is_visually_selected == selected and displacement_tween != null:
		return
		
	is_visually_selected = selected

	if displacement_tween and displacement_tween.is_valid():
		displacement_tween.kill()

	var target_offset = 25.0 if selected else 0.0

	displacement_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# SOLUÇÃO COMPATÍVEL COM CONTAINERS: 
	# Em vez de mexer no tema, movemos a posição X local do MarginContainer.
	# Como ele é filho direto do Button (que tem tamanho fixo), isso funciona perfeitamente
	# e ignora as travas do GridContainer pai.
	displacement_tween.tween_property(margin_container, "position:x", target_offset, 0.18)
