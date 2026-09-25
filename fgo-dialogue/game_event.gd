extends Resource
class_name GameEvent

# Adicionamos CURAR_TOTAL para cobrir o caso de fontes de cura ou fim de missões por evento
enum EventType { 
	INICIAR_BATALHA, 
	CONCLUIR_MISSAO, 
	MODIFICAR_ATRIBUTO,
	CURAR_TOTAL
}

@export_category("Configuração Geral")
@export var tipo_evento: EventType = EventType.INICIAR_BATALHA

@export_group("Controle de Missão")
@export var set_missao_em_andamento: bool = false # Altera o PlayerData.missao_em_andamento

@export_group("Comandos de Herói")
@export var heroi_id: String = ""                 # ID do herói (ex: "mash_01")
@export var hp_modifier: int = 0                  # Negativo para dano, positivo para cura
@export var xp_recompensa: int = 0                # Caso o evento dê XP (ex: escolha em diálogo)
