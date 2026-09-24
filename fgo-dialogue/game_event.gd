extends Resource
class_name GameEvent

# Definimos os tipos de comandos que um evento pode disparar no seu RPG
enum EventType { INICIAR_BATALHA, CONCLUIR_MISSAO, GANHAR_ITEM }

@export_category("Configuração Geral")
@export var tipo_evento: EventType = EventType.INICIAR_BATALHA

@export_group("Dados de Batalha (Estilo Pokémon/FGO)")
@export var inimigos: Array[String] = [] # IDs dos inimigos que vão surgir (ex: ["goblin_01", "orc_02"])
@export var cenario_fundo: Texture2D    # A imagem de fundo da arena onde a luta vai acontecer

@export_group("Dados de Progresso e Recompensas")
@export var quest_id: String = ""       # ID da missão a ser afetada no banco de dados global
@export var item_id: String = ""        # ID do item caso o jogador ganhe algo no diálogo
