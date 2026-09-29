# trigger_party_hero.gd
class_name TriggerPartyHero
extends ActivationTrigger

@export var hero_id_required: String = ""

func is_condition_met(_enemy_state: EnemyState, context_data: Dictionary) -> bool:
	var active_party_ids = context_data.get("active_party_ids", [])
	print("🎭 [DEBUG - TriggerPartyHero] Procurando Herói ID: '%s' na Party Ativa..." % hero_id_required)
	print("   | IDs presentes na Party de Teste: %s" % str(active_party_ids))
	
	var achou = active_party_ids.has(hero_id_required)
	print("   | Resultado da Busca Narrativa: %s" % ("✔️ ENCONTRADO!" if achou else "❌ Não está na equipe"))
	return achou

func get_custom_class() -> String:
	return "TriggerPartyHero"
