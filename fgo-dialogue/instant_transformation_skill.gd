# instant_transformation_skill.gd
class_name InstantTransformationSkill
extends SkillData

## Arraste aqui a ficha EnemyData (o blueprint) para a qual o Boss deve transicionar IMEDIATAMENTE!
@export var target_enemy_blueprint: EnemyData

## Se esta transformação específica deve atordoar/incapacitar o monstro na troca
@export var force_stun: bool = false
