# trigger_hp_pct.gd
class_name TriggerHPPct
extends ActivationTrigger

@export_range(0.0, 1.0) var hp_percentage: float = 0.5

# 🚨 CORRIGIDO: mudou de Node para EnemyState
func is_condition_met(enemy_state: EnemyState, _context_data: Dictionary) -> bool:
	var pct = float(enemy_state.current_hp) / float(enemy_state.get_max_hp())
	return pct <= hp_percentage
