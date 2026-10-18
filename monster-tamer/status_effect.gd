# status_effect.gd
class_name StatusEffect
extends Resource

@export_group("Identity")
@export var id: String = ""
@export var name: String = ""
@export var icon: Texture2D
@export var is_debuff: bool = true

# 🌟 O ajuste definitivo que você está fazendo:
# Agora a duração padrão nasce e vive aqui dentro do efeito!
@export var default_duration: int = 3 

# --- Gatilhos Virtuais (Hooks) ---
func on_apply(target: Object) -> void:
	pass

func on_turn_tick(target: Object, elapsed_turn: int) -> void:
	pass

func on_remove(target: Object) -> void:
	pass

func modify_damage(base_damage: int, element_type: String, is_inflicting: bool) -> int:
	return base_damage
