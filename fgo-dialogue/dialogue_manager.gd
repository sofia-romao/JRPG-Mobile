# dialogue_manager.gd
extends Control
class_name DialogueManager

signal dialogue_finished
signal game_event_triggered(event: GameEvent)

@export_group("Text Components")
@export var name_label: RichTextLabel
@export var text_label: RichTextLabel

@export_group("Visual & Interaction Components")
@export var portrait_rect: TextureRect
@export var choices_container: VBoxContainer
@export var next_button: Button

var _current_story: GameEvent = null
var _line_index: int = 0
var _is_typing: bool = false
var _current_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if next_button:
		next_button.pressed.connect(_on_next_clicked)

func start_dialogue(story: GameEvent) -> void:
	if story == null or story.dialogue_lines.is_empty():
		push_error("DialogueManager: Empty or invalid GameEvent!")
		return
		
	_current_story = story
	_line_index = 0
	_clear_choice_buttons()
	visible = true
	_display_current_line()

func _display_current_line() -> void:
	if _current_story == null or _line_index >= _current_story.dialogue_lines.size():
		_process_dialogue_end()
		return
		
	var line: StoryLine = _current_story.dialogue_lines[_line_index]
	
	if line.shake_screen:
		_apply_screen_shake()
		
	if line.flash_screen != Color(0,0,0,0):
		_apply_screen_flash(line.flash_screen)
	
	if name_label: 
		name_label.text = line.character_name
	
	if portrait_rect:
		if line.character_portrait != null:
			if not portrait_rect.visible or portrait_rect.texture != line.character_portrait:
				portrait_rect.texture = line.character_portrait
				portrait_rect.visible = true
				portrait_rect.modulate.a = 0.0
				create_tween().tween_property(portrait_rect, "modulate:a", 1.0, 0.2)
		else:
			if portrait_rect.visible:
				var portrait_tween = create_tween()
				portrait_tween.tween_property(portrait_rect, "modulate:a", 0.0, 0.15)
				portrait_tween.tween_callback(func(): portrait_rect.visible = false)

	if text_label:
		text_label.text = line.text
		text_label.visible_characters = 0
		_is_typing = true
		
		if _current_tween: _current_tween.kill()
		_current_tween = create_tween()
		
		var duration = max(0.3, line.text.length() * 0.025)
		_current_tween.tween_property(text_label, "visible_characters", line.text.length(), duration)
		_current_tween.tween_callback(func(): _is_typing = false)

func _on_next_clicked() -> void:
	if _is_typing:
		if _current_tween: _current_tween.kill()
		if text_label: text_label.visible_characters = text_label.text.length()
		_is_typing = false
	else:
		_line_index += 1
		_display_current_line()

func _process_dialogue_end() -> void:
	if _current_story and _current_story.choices.size() > 0:
		if next_button: next_button.visible = false 
		_generate_choice_buttons()
	else:
		_close_dialogue()

func _generate_choice_buttons() -> void:
	_clear_choice_buttons()
	if choices_container == null: return
	choices_container.visible = true
	
	for choice in _current_story.choices:
		var btn = Button.new()
		btn.text = choice.choice_text
		btn.custom_minimum_size = Vector2(250, 45)
		btn.pressed.connect(func(): _on_choice_selected(choice))
		choices_container.add_child(btn)

func _on_choice_selected(choice: StoryChoice) -> void:
	_clear_choice_buttons()
	
	if choice.trigger_game_event != null:
		game_event_triggered.emit(choice.trigger_game_event)
		
	if choice.next_event != null:
		start_dialogue(choice.next_event)
	else:
		_close_dialogue()

func _clear_choice_buttons() -> void:
	if choices_container:
		choices_container.visible = false
		for child in choices_container.get_children():
			child.queue_free()

func _close_dialogue() -> void:
	visible = false
	dialogue_finished.emit()

func _apply_screen_shake() -> void:
	var original_pos = position
	var shake_tween = create_tween()
	for i in range(5):
		var offset = Vector2(randf_range(-12, 12), randf_range(-6, 6))
		shake_tween.tween_property(self, "position", original_pos + offset, 0.04)
	shake_tween.tween_property(self, "position", original_pos, 0.04)

func _apply_screen_flash(color: Color) -> void:
	var flash_node = ColorRect.new()
	flash_node.color = color
	flash_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_node.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	add_child(flash_node)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_node, "color:a", 0.0, 0.3)
	flash_tween.tween_callback(flash_node.queue_free)
