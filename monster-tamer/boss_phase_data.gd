# boss_phase_data.gd
class_name BossPhaseData
extends Resource

@export var phase_blueprint: EnemyData 
@export var is_stunned: bool = false 

@export_group("Gatilhos de Ativação Polimórficos")
@export var activation_triggers: Array[ActivationTrigger] = []
