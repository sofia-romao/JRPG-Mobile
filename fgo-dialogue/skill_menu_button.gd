# skill_menu_button.gd
class_name SkillMenuButton
extends Button

signal short_clicked()
signal long_clicked()

@export var hold_threshold: float = 0.4

var _hold_timer: Tween = null
var _has_triggered_long_click: bool = false

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT

# O Godot chama isso automaticamente quando o botão sai da tela ou sofre queue_free()
func _exit_tree() -> void:
	_clear_timer()

func _clear_timer() -> void:
	if _hold_timer and _hold_timer.is_valid():
		_hold_timer.kill()
	_hold_timer = null

# Captura nativa de input focada no ciclo de vida DESTE elemento
func _gui_input(event: InputEvent) -> void:
	if disabled:
		_clear_timer()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Reseta o estado para um novo clique físico legítimo
			_has_triggered_long_click = false
			_clear_timer()
			
			# Inicia o timer associado rigidamente a este nó
			_hold_timer = create_tween()
			_hold_timer.tween_interval(hold_threshold)
			_hold_timer.tween_callback(func():
				_has_triggered_long_click = true
				long_clicked.emit()
			)
			# Consome o evento para evitar que ele "vaze" para painéis ou botões inferiores
			accept_event()
			
		else:
			# O mouse foi solto (Released)
			_clear_timer()
			
			# Se o tempo estourou e o long click já rodou, apenas consome e aborta
			if _has_triggered_long_click:
				accept_event()
				return
				
			# Se foi um clique curto e legítimo dentro dos limites do botão
			short_clicked.emit()
			accept_event()
