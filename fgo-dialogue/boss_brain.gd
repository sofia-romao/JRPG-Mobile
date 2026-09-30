# boss_brain.gd
class_name BossBrain
extends Resource

## Virtual method that every specialist AI must override.
## Receives the combat context and returns a Dictionary with:
## { "skill": SkillData (or null for basic attack), "target_id": String (the chosen hero ID) }
func choose_action(_context: Dictionary) -> Dictionary:
	return {
		"skill": null,
		"target_id": ""
	}
