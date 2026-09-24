extends Resource
class_name GameEvent

# Definimos os tipos de comandos que um evento pode disparar no seu RPG
enum EventType { INICIAR_BATALHA, 
	CONCLUIR_MISSAO, 
	MODIFICAR_ATRIBUTO}

@export_category("Configuração Geral")
@export var tipo_evento: EventType = EventType.INICIAR_BATALHA

@export_group("Comandos de Modificação")
@export var set_missao_em_andamento: bool = false # Seta o PlayerData.missao_em_andamento
@export var heroi_id: String = ""                 # ID do herói a ser afetado (ex: "mash_01")
@export var hp_modifier: int = 0                  # Quantidade de HP (ex: -40 para dano, 100 para cura)
