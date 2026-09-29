extends Node
# 💾 PLAYERDATA - Fonte de Verdade Global do Progresso do Jogador (Modo Boss Rush)

@export var available_heroes: Array[HeroData] = []
const MAX_PARTY_SIZE : int = 3
const INITIAL_HERO_IDS: Array[String] = ["altria"]

var active_mission_id: String = ""
var completed_missions: Array[String] = [] 
var selected_mission_data: MissionData = null 

var hero_collection: Dictionary = {}
var active_party: Array[String] = []

## Aplica dano ou cura passando valores positivos (cura) ou negativos (dano)
func update_hp_by_id(id_heroi: String, modificador: int) -> void:
	if hero_collection.has(id_heroi):
		var heroi: HeroState = hero_collection[id_heroi]
		heroi.modify_hp(modificador)
		print("💾 [PlayerData] HP de %s modificado. Atual: %d/%d" % [heroi.blueprint.character_name, heroi.current_hp, heroi.get_max_hp()])

## Função utilitária para curar todos da party ativa (fim de missões)
func heal_active_party() -> void:
	for id in active_party:
		if hero_collection.has(id):
			hero_collection[id].full_heal()
	print("❤️ [PlayerData] Toda a equipe ativa foi totalmente curada e limpa de efeitos!")

## Retorna o objeto completo do herói para a UI ou Combate lerem os dados
func get_hero(id_hero: String) -> HeroState:
	return hero_collection.get(id_hero, null)

func _ready() -> void:
	_load_initial_heroes()

func _load_heroes_from_folder() -> void:
	var caminho_pasta = "res://resources/heroes/"
	var dir = DirAccess.open(caminho_pasta)
	
	if dir:
		dir.list_dir_begin()
		var nome_arquivo = dir.get_next()
		
		while nome_arquivo != "":
			if not dir.current_is_dir() and nome_arquivo.ends_with(".tres"):
				var caminho_completo = caminho_pasta + nome_arquivo
				var data = load(caminho_completo) as HeroData
				
				if data:
					var new_state = HeroState.new()
					new_state.blueprint = data
					new_state.full_heal()
					
					hero_collection[data.id] = new_state
					
					var name_for_print = data.character_name if "character_name" in data else "Herói"
					print("📦 [PlayerData] Herói carregado automaticamente: %s" % name_for_print)

			nome_arquivo = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("PlayerData: Não foi possível acessar a pasta de heróis em: " + caminho_pasta)

func add_hero_to_collection(hero_id: String) -> void:
	if hero_collection.has(hero_id):
		print("⚠️ [PlayerData] Hero already unlocked: ", hero_id)
		return
		
	var path = "res://resources/heroes/" + hero_id + ".tres"
	
	if ResourceLoader.exists(path) or ResourceLoader.exists(path + ".remap"):
		var data = load(path) as HeroData
		if data:
			var new_state = HeroState.new()
			new_state.blueprint = data
			new_state.full_heal()
			
			hero_collection[hero_id] = new_state
			print("🏅 [PlayerData] NEW HERO UNLOCKED: ", data.character_name)
			
			if SaveManager.has_method("save_game"):
				SaveManager.save_game()
	else:
		push_error("[PlayerData] Failed to find hero resource file at: " + path)

func _load_initial_heroes() -> void:
	hero_collection.clear()
	print("🛡️ [PlayerData] Initializing core starting roster...")
	for hero_id in INITIAL_HERO_IDS:
		add_hero_to_collection(hero_id)
