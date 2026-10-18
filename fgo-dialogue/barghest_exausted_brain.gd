# brain_barghest_exhausted.gd
class_name BrainBarghestExhausted
extends BossBrain

## Specialist AI: Always forces the boss to cast his re-enrage transformation skill
func choose_action(context: Dictionary) -> Dictionary:
	var boss_state = context.get("boss_state") as EnemyState
	var active_heroes_ids = context.get("active_party_ids") as Array[String]
	
	# Default fallback target just in case
	var fallback_target = active_heroes_ids.pick_random() if not active_heroes_ids.is_empty() else ""
	
	# 1. Fetch the skills configured for this exhausted phase blueprint
	var available_skills = boss_state.get_current_skill_list()
	
	if not available_skills.is_empty():
		# Grab the first skill in his list (which will be your Enrage/Recovery skill)
		var recovery_skill_id = available_skills[0]
		var candidate_skill = SkillsDatabase.get_skill(recovery_skill_id)
		
		# 2. 🛡️ SAFETY CHECK: Ensure he has enough MP to execute the transformation
		if candidate_skill and boss_state.current_mp >= candidate_skill.mp_cost:
			print("🐺 [AI - Exhausted] Gathering remaining strength... 100%% forced cast: %s" % candidate_skill.name)
			return {
				"skill": candidate_skill,
				"target_id": boss_state.active_blueprint.id # 🌟 FIXED: Changed spawned_enemy to boss_state
			}
			
	# Fallback to basic attack if out of MP or skill is missing from inspector
	print("⚠️ [AI - Exhausted] Out of breath or missing skill asset. Falling back to Basic Attack.")
	return {
		"skill": null,
		"target_id": fallback_target
	}
