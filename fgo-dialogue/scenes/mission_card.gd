# mission_card.gd
extends Button

# Sinal que o menu unificado vai escutar para saber qual missão foi clicada
signal mission_card_clicked(mission: MissionData)

@export var title_label: Label
@export var description_label: Label
@export var margin_container: MarginContainer

var associated_mission: MissionData = null
var displacement_tween: Tween 
var is_visually_selected: bool = false

# Registra o clique do próprio botão no Godot e avisa o menu principal
func _pressed() -> void:
	if associated_mission:
		mission_card_clicked.emit(associated_mission)

## Inicializa o cartão com os dados do Resource da missão
func initialize_mission_card(mission: MissionData, is_selected: bool) -> void:
	associated_mission = mission
	
	if title_label and mission:
		title_label.text = mission.title
		
	if description_label and mission:
		description_label.text = mission.description
	
	# Força o estado visual estático inicial sem animações abruptas ao abrir a tela
	is_visually_selected = is_selected
	if margin_container:
		margin_container.position.x = 25.0 if is_selected else 0.0
		
	# Mesma modulação verde estilosa que colocamos no cartão de herói
	self_modulate = Color(0.5, 1.0, 0.5, 1.0) if is_selected else Color.WHITE

## Executa a animação suave de recuo e mudança de cor ao selecionar
func _animate_displacement(selected: bool) -> void:
	if not margin_container: return
	
	if is_visually_selected == selected and displacement_tween != null:
		return
		
	is_visually_selected = selected

	if displacement_tween and displacement_tween.is_valid():
		displacement_tween.kill()

	var target_offset = 25.0 if selected else 0.0
	var target_color = Color(0.5, 1.0, 0.5, 1.0) if selected else Color.WHITE

	displacement_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 1. Deslocamento horizontal dentro do contêiner pai
	displacement_tween.tween_property(margin_container, "position:x", target_offset, 0.18)
	
	# 2. Modulação suave para o verde de seleção
	displacement_tween.tween_property(self, "self_modulate", target_color, 0.18)
