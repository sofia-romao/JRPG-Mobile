# status_effect.gd
class_name StatusEffect
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var icon: Texture2D
@export var is_debuff: bool = true

# --- Gatilhos Virtuais (Hooks) ---
# Sobrescreva estes métodos nos efeitos específicos

## Chamado no momento exato em que o status é aplicado
func on_apply(target: Object) -> void:
	pass

## Chamado no início/fim do turno (o antigo tick)
func on_turn_tick(target: Object, elapsed_turn: int) -> void:
	pass

## Chamado quando o status expira naturalmente ou é limpo
func on_remove(target: Object) -> void:
	pass

## Permite modificar o dano causado ou recebido (ex: Escudo ou Buff de Atque)
func modify_damage(base_damage: int, is_inflicting: bool) -> int:
	return base_damage
