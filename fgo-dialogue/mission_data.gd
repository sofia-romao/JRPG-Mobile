# MissionData.gd
class_name MissionData
extends Resource

@export_group("Identity")
@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export_group("Rewards")
## O herói dono que vai receber a skin (ex: "altria", "mash", "hero3")
@export var reward_hero_owner: String = ""
## O ID da nova skin/kit a ser liberada (ex: "altria_alter")
@export var reward_kit_id: String = ""

@export_group("Flow Trigger")
# O evento que dispara ao iniciar a missão pela primeira vez (Parte 1)
@export var start_event: GameEvent

@export_group("Progression Requirements")
# ID de outra missão que PRECISA estar concluída para esta aparecer (Vazio = Disponível desde o início)
@export var required_mission_id: String = ""
