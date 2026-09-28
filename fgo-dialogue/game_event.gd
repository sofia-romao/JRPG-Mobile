# GameEvent.gd
extends Resource
class_name GameEvent


enum ActionType { 
	NONE, 
	START_COMBAT, 
	COMPLETE_MISSION, 
	MODIFY_ATTRIBUTE,
	FULL_HEAL 
}

@export_category("Dialogue Flow")
@export var dialogue_lines: Array[StoryLine] = []
@export var choices: Array[StoryChoice] = []


@export_category("Action Trigger")
@export var action_type: ActionType = ActionType.NONE

@export_group("Target Modification")
@export var hero_id: String = ""                 
@export_range(-9999, 9999) var hp_modifier: int = 0                  
@export var xp_reward: int = 0                

@export_group("Combat Setup")
@export var combat_data: CombatData 
