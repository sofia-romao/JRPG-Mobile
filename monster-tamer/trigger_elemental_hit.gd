# trigger_elemental_hit.gd
class_name TriggerElementalHit
extends ActivationTrigger

@export_enum("PHYSICAL", "FIRE", "ICE", "ELEC") var required_element: String = "FIRE"

# 🚨 CORRIGIDO: mudou de Node para EnemyState para sincronizar com o compilador
func is_condition_met(_enemy_state: EnemyState, context_data: Dictionary) -> bool:
	return context_data.get("element_type", "") == required_element
