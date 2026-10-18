# effect_regen.gd
class_name EffectRegen
extends StatusEffect

@export var heal_amount: int = 8

## Runs automatically at the start of the entity's turn via tick_status()
func on_turn_tick(target: Object, _elapsed_turn: int) -> void:
	if target.has_method("modify_hp"):
		target.modify_hp(heal_amount)
		print("💚 [Status Effect] %s recovered %d HP from Regen!" % [target.name, heal_amount])
