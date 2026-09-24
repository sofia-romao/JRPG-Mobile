extends Control
class_name DialogueManager

signal dialogue_finished
signal game_event_triggered(event: GameEvent)

@export_group("Componentes de Texto")
@export var name_label: RichTextLabel
@export var text_label: RichTextLabel

@export_group("Componentes Visuais e Cliques")
@export var portrait_rect: TextureRect
@export var choices_container: VBoxContainer
@export var next_button: Button

var _current_story: StoryEvent = null
var _line_index: int = 0
var _is_typing: bool = false
var _current_tween: Tween = null

func _ready() -> void:
	# Impede que cliques na interface passem para o mapa ou jogo atrás dela
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	
	# Garante que o botão invisível avance o diálogo ao ser clicado
	if next_button:
		next_button.pressed.connect(_on_next_clicked)
	else:
		push_error("DialogueManager: O NextButton não foi arrastado no Inspector!")

func start_dialogue(story: StoryEvent) -> void:
	if story == null or story.dialogue_lines.is_empty():
		push_error("DialogueManager: Evento de história vazio ou inválido!")
		return
		
	_current_story = story
	_line_index = 0
	_limpar_botoes_de_escolha()
	visible = true
	_exibir_linha_atual()

func _exibir_linha_atual() -> void:
	# Se os textos acabaram, verifica se há escolhas ou encerra
	if _current_story == null or _line_index >= _current_story.dialogue_lines.size():
		_processar_fim_dos_textos()
		return
		
	var linha: StoryLine = _current_story.dialogue_lines[_line_index]
	
	# --- 1. EFEITOS DE TELA (Estilo FGO) ---
	if linha.shake_screen:
		_aplicar_screen_shake()
		
	if linha.flash_screen != Color(0,0,0,0):
		_aplicar_screen_flash(linha.flash_screen)
	
	# --- 2. ATUALIZAÇÃO DE TEXTO ---
	if name_label: 
		name_label.text = linha.character_name
	
	# --- 3. ATUALIZAÇÃO DO RETRATO ---
	if portrait_rect:
		if linha.character_portrait != null:
			# Se o retrato mudou ou estava oculto, faz um Fade In suave
			if not portrait_rect.visible or portrait_rect.texture != linha.character_portrait:
				portrait_rect.texture = linha.character_portrait
				portrait_rect.visible = true
				portrait_rect.modulate.a = 0.0
				var portrait_tween = create_tween()
				portrait_tween.tween_property(portrait_rect, "modulate:a", 1.0, 0.2)
		else:
			# Narração pura: esconde o retrato com Fade Out
			if portrait_rect.visible:
				var portrait_tween = create_tween()
				portrait_tween.tween_property(portrait_rect, "modulate:a", 0.0, 0.15)
				portrait_tween.tween_callback(func(): portrait_rect.visible = false)

	# --- 4. ANIMAÇÃO MÁQUINA DE ESCREVER ---
	if text_label:
		text_label.text = linha.text
		text_label.visible_characters = 0
		_is_typing = true
		
		if _current_tween: _current_tween.kill()
		_current_tween = create_tween()
		
		var duracao = max(0.3, linha.text.length() * 0.025)
		_current_tween.tween_property(text_label, "visible_characters", linha.text.length(), duracao)
		_current_tween.tween_callback(func(): _is_typing = false)

func _on_next_clicked() -> void:
	if _is_typing:
		# Se ainda está digitando, pula a animação direto para o fim do texto
		if _current_tween: _current_tween.kill()
		if text_label: text_label.visible_characters = text_label.text.length()
		_is_typing = false
	else:
		# Se já terminou de digitar, avança a linha
		_line_index += 1
		_exibir_linha_atual()

func _processar_fim_dos_textos() -> void:
	if _current_story and _current_story.choices.size() > 0:
		if next_button: next_button.visible = false # Oculta o botão geral para liberar cliques nas escolhas
		_gerar_botoes_de_escolha()
	else:
		_fechar_dialogo()

func _gerar_botoes_de_escolha() -> void:
	_limpar_botoes_de_escolha()
	if choices_container == null: return
	
	choices_container.visible = true
	
	for escolha in _current_story.choices:
		var btn = Button.new()
		btn.text = escolha.choice_text
		btn.custom_minimum_size = Vector2(250, 45)
		btn.pressed.connect(func(): _on_escolha_selecionada(escolha))
		choices_container.add_child(btn)

func _on_escolha_selecionada(choice: StoryChoice) -> void:
	_limpar_botoes_de_escolha()
	if choice.trigger_game_event != null:
		game_event_triggered.emit(choice.trigger_game_event)
		# Se o evento for de batalha, interrompemos o fluxo de texto aqui, pois a Main vai deletar essa cena
		if choice.trigger_game_event.tipo_evento == GameEvent.EventType.INICIAR_BATALHA:
			return 
	if next_button: next_button.visible = true
	
	if choice.next_event:
		start_dialogue(choice.next_event)
	else:
		_fechar_dialogo()

func _limpar_botoes_de_escolha() -> void:
	if choices_container:
		choices_container.visible = false
		for child in choices_container.get_children():
			child.queue_free()

func _fechar_dialogo() -> void:
	visible = false
	dialogue_finished.emit()

# --- FUNÇÕES DE EFEITOS ESPECIAIS ---

func _aplicar_screen_shake() -> void:
	var original_pos = position
	var shake_tween = create_tween()
	for i in range(5):
		var offset = Vector2(randf_range(-12, 12), randf_range(-6, 6))
		shake_tween.tween_property(self, "position", original_pos + offset, 0.04)
	shake_tween.tween_property(self, "position", original_pos, 0.04)

func _aplicar_screen_flash(cor: Color) -> void:
	var flash_node = ColorRect.new()
	flash_node.color = cor
	flash_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_node.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	add_child(flash_node)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_node, "color:a", 0.0, 0.3)
	flash_tween.tween_callback(flash_node.queue_free)
