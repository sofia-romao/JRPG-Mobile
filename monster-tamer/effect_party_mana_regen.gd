# effect_party_mana_regen.gd
extends StatusEffect

@export var mp_regen_amount: int = 5
@export var hp_threshold_percentage: float = 0.5

func on_turn_tick(target: Object, _elapsed_turn: int) -> void:
	# target aqui será o HeroState que possui a passiva
	if target.current_hp > (target.get_max_hp() * hp_threshold_percentage):
		# Acessa os heróis ativos diretamente pelo escopo global do PlayerData
		for p_id in PlayerData.active_party:
			var member = PlayerData.get_hero(p_id)
			if member:
				member.modify_mp(mp_regen_amount)
		print("🔮 [Passive] %s triggered %d MP regeneration for the active party!" % [name, mp_regen_amount])
