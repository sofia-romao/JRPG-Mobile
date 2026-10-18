# activation_trigger.gd
class_name ActivationTrigger
extends Resource

## Função base corrigida com a tipagem estrita para o EnemyState
## Retorna TRUE se a condição da luta bater com a regra do gatilho.
func is_condition_met(enemy_state: EnemyState, context_data: Dictionary) -> bool:
	return false
## Faz o Godot entender o nome customizado da sua classe no console
func get_custom_class() -> String:
	return "ActivationTrigger"
