extends Node
# 💾 PLAYERDATA - Fonte de Verdade Global do Progresso do Jogador

const MAX_PARTY_SIZE : int = 3

var missao_em_andamento: bool = false
var id_missao_ativa: String = ""

# Agora a coleção guarda instâncias de HeroState indexadas por ID
var colecao_herois: Dictionary = {}

# Mantemos seu design inteligente de guardar apenas as Strings dos IDs na party ativa
var party_ativa: Array[String] = []

## Adiciona XP para qualquer herói da coleção
func adicionar_xp(id_heroi: String, quantidade: int) -> void:
	if colecao_herois.has(id_heroi):
		var heroi: HeroState = colecao_herois[id_heroi]
		var nivel_antigo = heroi.get_nivel()
		
		heroi.xp_atual += quantidade
		print("✨ [PlayerData] %s ganhou %d de XP! Total: %d" % [id_heroi, quantidade, heroi.xp_atual])
		
		# Se subiu de nível, você pode opcionalmente curar o herói ou rodar um VFX
		if heroi.get_nivel() > nivel_antigo:
			print("🆙 [PlayerData] %s subiu para o nível %d!" % [heroi.blueprint.nome, heroi.get_nivel()])

## Aplica dano ou cura passando valores positivos (cura) ou negativos (dano)
func atualizar_hp_por_id(id_heroi: String, modificador: int) -> void:
	if colecao_herois.has(id_heroi):
		var heroi: HeroState = colecao_herois[id_heroi]
		heroi.modificar_hp(modificador)
		print("💾 [PlayerData] HP de %s modificado. Atual: %d/%d" % [heroi.blueprint.nome, heroi.hp_atual, heroi.get_max_hp()])

## Função utilitária para curar todos da party ativa (fim de missões)
func curar_party_ativa() -> void:
	for id in party_ativa:
		if colecao_herois.has(id):
			colecao_herois[id].curar_total()
	print("❤️ [PlayerData] Toda a equipe ativa foi totalmente curada!")

## Retorna o objeto completo do herói para a UI ou Combate lerem os dados
func get_heroi(id_heroi: String) -> HeroState:
	return colecao_herois.get(id_heroi, null)
func _ready() -> void:
	print("🧪 [PlayerData] Iniciando testes do sistema de heróis...")
	_rodar_teste_sistema()

func _rodar_teste_sistema() -> void:
	# 1. CRIANDO BLUEPRINTS TEMPORÁRIOS VIA CÓDIGO (Simulando os arquivos .tres)
	var blueprint_mash = HeroData.new()
	blueprint_mash.id = "mash_01"
	blueprint_mash.nome = "Mash Kyrielight"
	blueprint_mash.hp_base = 100
	blueprint_mash.hp_por_nivel = 15
	
	var blueprint_artoria = HeroData.new()
	blueprint_artoria.id = "artoria_05"
	blueprint_artoria.nome = "Altria Pendragon"
	blueprint_artoria.hp_base = 150
	blueprint_artoria.hp_por_nivel = 25

	# 2. INSTANCIANDO O STATUS DINÂMICO (Simulando carregar um Save Game)
	var estado_mash = HeroState.new()
	estado_mash.blueprint = blueprint_mash
	estado_mash.xp_atual = 0  # Nível 1
	estado_mash.curar_total() # Começa com HP cheio
	
	var estado_artoria = HeroState.new()
	estado_artoria.blueprint = blueprint_artoria
	estado_artoria.xp_atual = 2500 # Nível 3 (2500 / 1000 = 2 + 1)
	estado_artoria.curar_total()

	# 3. POPULANDO A COLEÇÃO E A PARTY ATIVA
	colecao_herois["mash_01"] = estado_mash
	colecao_herois["artoria_05"] = estado_artoria
	
	party_ativa = ["mash_01", "artoria_05"]
	
	# 4. EXECUTANDO OS TESTES NO CONSOLE
	print("\n--- STATUS INICIAL ---")
	print("🛡️ %s | Nível: %d | HP: %d/%d" % [estado_mash.blueprint.nome, estado_mash.get_nivel(), estado_mash.hp_atual, estado_mash.get_max_hp()])
	print("⚔️ %s | Nível: %d | HP: %d/%d" % [estado_artoria.blueprint.nome, estado_artoria.get_nivel(), estado_artoria.hp_atual, estado_artoria.get_max_hp()])

	print("\n--- TESTE 1: SIMULANDO DANO EM COMBATE ---")
	# Mash toma 40 de dano, Artoria toma 80 de dano
	atualizar_hp_por_id("mash_01", -40)
	atualizar_hp_por_id("artoria_05", -80)

	print("\n--- TESTE 2: GANHO DE XP E UPGRADE DINÂMICO ---")
	# Vamos dar 1500 de XP para a Mash. Ela deve ir para o Nível 2.
	# O Max HP dela deve subir automaticamente, mas o HP atual continua ferido!
	adicionar_xp("mash_01", 1500)
	var heroi_mash = get_heroi("mash_01")
	print("📊 %s após XP | Nível: %d | HP Atual: %d | NOVO Max HP: %d" % [heroi_mash.blueprint.nome, heroi_mash.get_nivel(), heroi_mash.hp_atual, heroi_mash.get_max_hp()])

	print("\n--- TESTE 3: CURA TOTAL DA PARTY (FIM DA MISSÃO) ---")
	curar_party_ativa()
	print("📊 %s Recorada | HP: %d/%d" % [estado_mash.blueprint.nome, estado_mash.hp_atual, estado_mash.get_max_hp()])
	print("📊 %s Recuperada | HP: %d/%d" % [estado_artoria.blueprint.nome, estado_artoria.hp_atual, estado_artoria.get_max_hp()])
	
	print("\n🧪 [PlayerData] Testes concluídos com sucesso!")
