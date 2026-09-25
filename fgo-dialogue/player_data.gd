extends Node
# 💾 PLAYERDATA - Fonte de Verdade Global do Progresso do Jogador
@export var herois_disponiveis: Array[HeroData] = []
const MAX_PARTY_SIZE : int = 3

var missao_em_andamento: bool = false
var id_active_mission: String = ""


# Agora a coleção guarda instâncias de HeroState indexadas por ID
var hero_collection: Dictionary = {}

# Mantemos seu design inteligente de guardar apenas as Strings dos IDs na party ativa
var active_party: Array[String] = []

## Adiciona XP para qualquer herói da coleção
func add_exp(id_heroi: String, quantidade: int) -> void:
	if hero_collection.has(id_heroi):
		var heroi: HeroState = hero_collection[id_heroi]
		var nivel_antigo = heroi.get_nivel()
		
		heroi.xp_atual += quantidade
		print("✨ [PlayerData] %s ganhou %d de XP! Total: %d" % [id_heroi, quantidade, heroi.xp_atual])
		
		# Se subiu de nível, você pode opcionalmente curar o herói ou rodar um VFX
		if heroi.get_nivel() > nivel_antigo:
			print("🆙 [PlayerData] %s subiu para o nível %d!" % [heroi.blueprint.nome, heroi.get_nivel()])

## Aplica dano ou cura passando valores positivos (cura) ou negativos (dano)
func atualizar_hp_por_id(id_heroi: String, modificador: int) -> void:
	if hero_collection.has(id_heroi):
		var heroi: HeroState = hero_collection[id_heroi]
		heroi.modificar_hp(modificador)
		print("💾 [PlayerData] HP de %s modificado. Atual: %d/%d" % [heroi.blueprint.nome, heroi.hp_atual, heroi.get_max_hp()])

## Função utilitária para curar todos da party ativa (fim de missões)
func heal_active_party() -> void:
	for id in active_party:
		if hero_collection.has(id):
			hero_collection[id].full_recovery()
	print("❤️ [PlayerData] Toda a equipe ativa foi totalmente curada!")

## Retorna o objeto completo do herói para a UI ou Combate lerem os dados
func get_hero(id_hero: String) -> HeroState:
	return hero_collection.get(id_hero, null)
func _ready() -> void:
	_load_heroes_from_folder()
	# ... seu código de inicialização ou testes ...

func _load_heroes_from_folder() -> void:
	var caminho_pasta = "res://resources/heroes/"
	var dir = DirAccess.open(caminho_pasta)
	
	if dir:
		dir.list_dir_begin()
		var nome_arquivo = dir.get_next()
		
		while nome_arquivo != "":
			# Garante que só vai ler arquivos de recurso (.tres) e ignorar arquivos .import
			if not dir.current_is_dir() and nome_arquivo.ends_with(".tres"):
				var caminho_completo = caminho_pasta + nome_arquivo
				var data = load(caminho_completo) as HeroData
				
				if data:
					# Instancia o estado dinâmico exatamente como fazíamos antes
					var novo_estado = HeroState.new()
					novo_estado.blueprint = data
					novo_estado.current_exp = 0
					novo_estado.total_recovery()
					
					hero_collection[data.id] = novo_estado
					# Como deve ficar corrigido:
					var nome_para_print = "Herói"
					if "nome" in data:
						nome_para_print = data.nome
					elif "character_name" in data:
						nome_para_print = data.character_name

					print("📦 [PlayerData] Herói carregado automaticamente: %s" % nome_para_print)

			nome_arquivo = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("PlayerData: Não foi possível acessar a pasta de heróis em: " + caminho_pasta)
