# trigger_party_hero.gd
class_name TriggerPartyHero
extends ActivationTrigger

@export var hero_id_required: String = ""

func is_condition_met(_enemy_state: EnemyState, context_data: Dictionary) -> bool:
	# 🛡️ BARREIRA ARQUITETURAL EXCLUSIVA:
	# Este gatilho narra uma reação de entrada (Frame Zero).
	# Se a chamada veio da rota de dano ("on_damage"), ele DEVE recusar a ativação imediatamente!
	var current_event = context_data.get("current_event_type", "")
	if current_event == "on_damage":
		return false
		
	var active_party_ids = context_data.get("active_party_ids", [])
	print("🎭 [DEBUG - TriggerPartyHero] Procurando Herói ID: '%s' na Party Ativa..." % hero_id_required)
	
	var achou = active_party_ids.has(hero_id_required)
	print("   | Resultado da Busca Narrativa: %s" % ("✔️ ENCONTRADO!" if achou else "❌ Não está na equipe"))
	return achou

func get_custom_class() -> String:
	return "TriggerPartyHero"
