# boss_structure_data.gd
class_name BossStructureData
extends Resource

@export var boss_id: String = "" 

# A ficha limpa do inimigo que entra em campo no Turno 1
@export var initial_enemy_blueprint: EnemyData

# A array com todas as transformações possíveis para este combate
@export var possible_phases: Array[BossPhaseData] = []
