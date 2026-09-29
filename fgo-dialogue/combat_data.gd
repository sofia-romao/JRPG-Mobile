
class_name CombatData
extends Resource

@export_category("Visual & Áudio")
@export var bgm: AudioStream
@export var background: Texture2D

@export_category("Desafio")
# 🚨 ATUALIZADO: Substitui o EnemyData isolado pela estrutura completa de fases e transformações!
@export var boss_structure: BossStructureData

@export_category("Recompensas")
# Se quiser customizar um evento complexo pós-luta (ex: fechar missão + dar XP)
@export var victory_event: GameEvent 
