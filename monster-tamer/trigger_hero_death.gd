# trigger_hero_death.gd
class_name TriggerHeroDeath
extends Resource # Se você tiver uma classe base para gatilhos, mude para ela (ex: extends BossTrigger)

@export var target_hero_id: String = "altria"

## Retorna o nome da classe para os prints de debug automatizados que você colocou no EnemyState
func get_custom_class() -> String:
	return "TriggerHeroDeath"

## Avalia a condição de ativação em runtime
func is_condition_met(enemy_state: Object, context_data: Dictionary) -> bool:
	# Resgata a array de IDs dos heróis que continuam vivos na arena
	var active_party_ids = context_data.get("active_party_ids", [])
	
	# Se a lista de heróis vivos NÃO contém mais o ID alvo (ex: "altria"),
	# significa que o personagem foi derrotado e removido do combate!
	if not active_party_ids.has(target_hero_id):
		print("💀 [TriggerHeroDeath] %s is no longer in the active party!" % target_hero_id)
		return true
		
	return false
