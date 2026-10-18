# trigger_status_transformation.gd
class_name TriggerStatusTransformation
extends ActivationTrigger

## O ID do status que a skill vai aplicar no Boss (ex: "status_mutacao_iminente")
@export var status_id_to_check: String = "status_mutacao_iminente"

## Se o Boss estiver com esse status aplicado nele mesmo, o gatilho bate como TRUE!
func is_condition_met(enemy_state: EnemyState, _context_data: Dictionary) -> bool:
	if enemy_state and enemy_state.has_method("has_status"):
		# Se a sua classe EnemyState tiver um método de checagem direta:
		return enemy_state.has_status(status_id_to_check)
	
	# Caso não tenha o método direto, varremos o dicionário nativo active_status do Boss
	if enemy_state and "active_status" in enemy_state:
		for active_effect in enemy_state.active_status.keys():
			if active_effect and active_effect.get("id") == status_id_to_check:
				return true
				
	return false

func get_custom_class() -> String:
	return "TriggerStatusTransformation"
