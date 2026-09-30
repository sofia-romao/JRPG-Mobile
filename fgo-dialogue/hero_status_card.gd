# hero_status_card.gd
extends MarginContainer

@export var name_label: Label
@export var hp_label: Label
@export var mp_label: Label # 🔮 NOVO: Arraste o seu novo nó de texto de MP aqui pelo Inspector!
@export var status_icons_container: HBoxContainer # 🌟 NOVO: Arraste o seu HBoxContainer do ContentLayout aqui!

var _associated_state: HeroState

## Configura os dados iniciais do card injetados dinamicamente pelo CombatManager
func configurar_card(hero_state: HeroState) -> void:
	# Avoid duplicate connections if the card is re-configured for the same hero
	if _associated_state != hero_state:
		_associated_state = hero_state
		name = hero_state.blueprint.id
		
		# --- CONEXÃO DOS SINAIS DE EVENTO DO MOTOR ---
		if hero_state.has_signal("changed_hp") and not hero_state.changed_hp.is_connected(_on_hero_hp_changed):
			hero_state.changed_hp.connect(_on_hero_hp_changed)
			
		if hero_state.has_signal("changed_mp") and not hero_state.changed_mp.is_connected(_on_hero_mp_changed):
			hero_state.changed_mp.connect(_on_hero_mp_changed)
			
		# 🌟 NEW: Connects the modular status signal to re-render icons instantly
		if hero_state.has_signal("status_updated") and not hero_state.status_updated.is_connected(_on_status_updated):
			hero_state.status_updated.connect(_on_status_updated)
	
	if name_label and hero_state.blueprint:
		name_label.text = hero_state.blueprint.character_name
		
	_update_hp_text(hero_state.current_hp, hero_state.get_max_hp())
	_update_mp_text(hero_state.current_mp, hero_state.get_max_mp()) # 🔮 Desenha o MP inicial na arena
	
	# Initial render for status icons
	_update_status_icons()

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

func _on_status_updated() -> void:
	_update_status_icons()

# --- RE-RENDERIZADORES DE TEXTO E ÍCONES ---

func _update_hp_text(current: int, maximum: int) -> void:
	if hp_label:
		hp_label.text = "HP: " + str(current) + "/" + str(maximum)

func _update_mp_text(current: int, maximum: int) -> void:
	if mp_label:
		mp_label.text = "MP: " + str(current) + "/" + str(maximum)

## Clears and completely reconstructs status effect icons inside the layout container
func _update_status_icons() -> void:
	if not status_icons_container or not _associated_state:
		return
		
	# Clear previous icons safely
	for child in status_icons_container.get_children():
		child.queue_free()
		
	# Instantiates a TextureRect for each active resource effect
	for effect in _associated_state.active_status.keys():
		if effect and effect.icon:
			var texture_rect = TextureRect.new()
			texture_rect.texture = effect.icon
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			
			# Mobile-friendly size fit for your layout list
			texture_rect.custom_minimum_size = Vector2(20, 20)
			
			# Visual cue: slight red tint if the status is a debuff
			if "is_debuff" in effect and effect.is_debuff:
				texture_rect.modulate = Color(1.0, 0.6, 0.6)
				
			status_icons_container.add_child(texture_rect)
