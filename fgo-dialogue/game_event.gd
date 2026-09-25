# GameEvent.gd
extends Resource
class_name GameEvent

<<<<<<< Updated upstream
# Definimos os tipos de comandos que um evento pode disparar no seu RPG
enum EventType { INICIAR_BATALHA, 
	CONCLUIR_MISSAO, 
	MODIFICAR_ATRIBUTO}
=======
enum ActionType { 
	NONE, 
	START_COMBAT, 
	COMPLETE_MISSION, 
	MODIFY_ATTRIBUTE,
	FULL_HEAL 
}
>>>>>>> Stashed changes

@export_category("Dialogue Flow")
@export var dialogue_lines: Array[StoryLine] = []
@export var choices: Array[StoryChoice] = []

<<<<<<< Updated upstream
@export_group("Comandos de Modificação")
@export var set_missao_em_andamento: bool = false # Seta o PlayerData.missao_em_andamento
@export var heroi_id: String = ""                 # ID do herói a ser afetado (ex: "mash_01")
@export var hp_modifier: int = 0                  # Quantidade de HP (ex: -40 para dano, 100 para cura)
=======
@export_category("Action Trigger")
@export var action_type: ActionType = ActionType.NONE
@export var is_mission_in_progress: bool = false

@export_group("Target Modification")
@export var hero_id: String = ""                 
@export_range(-9999, 9999) var hp_modifier: int = 0                  
@export var xp_reward: int = 0                

@export_group("Combat Setup")
@export var combat_data: CombatData 
>>>>>>> Stashed changes
