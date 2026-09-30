# brain_barghest.gd
class_name BrainBarghest
extends BossBrain

## Specialist AI: Focuses entirely on Altria until she is defeated
func choose_action(context: Dictionary) -> Dictionary:
	var boss_state = context.get("boss_state") as EnemyState
	var active_heroes_ids = context.get("active_party_ids") as Array[String]
	
	var chosen_target_id: String = ""
	
	# 🎯 STEP 1: Check if Altria is present and alive in the active party
	if active_heroes_ids.has("altria"):
		var altria_state = PlayerData.get_hero("altria")
		if altria_state and altria_state.current_hp > 0:
			chosen_target_id = "altria"
			print("🐺 [AI - Barghest] Obsession Triggered! Target locked on ALTRIA.")
			
	# 🛡️ STEP 2: Backup Plan (If Altria is already dead or not in battle)
	if chosen_target_id == "":
		if not active_heroes_ids.is_empty():
			# Picks a random live hero from the leftovers
			chosen_target_id = active_heroes_ids.pick_random()
			print("🐺 [AI - Barghest] Altria is not available. Target shifted randomly to: %s" % chosen_target_id)
		else:
			return { "skill": null, "target_id": "" } # No targets left
			
	# 🔮 STEP 3: Choose Hivelihood / Skill based on current MP
	var chosen_skill: SkillData = null
	var available_skills = boss_state.get_current_skill_list()
	
	# SMT Rule: If he has MP and skills, has a 75% chance to cast a powerful spell, else hits basic physical
	if not available_skills.is_empty() and randf() < 0.75:
		var random_skill_id = available_skills.pick_random()
		var candidate_skill = SkillsDatabase.get_skill(random_skill_id)
		
		if candidate_skill and boss_state.current_mp >= candidate_skill.mp_cost:
			chosen_skill = candidate_skill
			
	return {
		"skill": chosen_skill,
		"target_id": chosen_target_id
	}
