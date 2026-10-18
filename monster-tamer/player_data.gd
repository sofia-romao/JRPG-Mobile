extends Node
# 💾 PLAYERDATA - Fonte de Verdade Global do Progresso do Jogador (Modo Boss Rush)

@export var available_heroes: Array[HeroData] = []
const MAX_PARTY_SIZE : int = 3
const INITIAL_HERO_IDS: Array[String] = ["altria"]
# 🔒 Dicionário que guarda qual a ID do Kit/Skin que está atualmente equipado para cada herói
# São esses 3 valores que o CombatManager vai ler para montar a equipe da batalha!
# No topo do seu PlayerData.gd, altere para isto:

# 🔒 Dicionário atualizado com as chaves exatas que o seu computador gerou no log!
var active_kits: Dictionary = {
	"altria": "altria",
	"mash": "mash",
	"hero3": "new_hero" # Substituído 'hero3_base' pelo ID real 'new_hero' detectado pelo log!
}

# 📦 Listas de desbloqueio iniciais ajustadas com os mesmos IDs reais
var unlocked_altria_kits: Array[String] = ["altria"]
var unlocked_mash_kits: Array[String] = ["mash"]
var unlocked_hero3_kits: Array[String] = ["new_hero"]

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

# Adicione ou substitua no seu PlayerData.gd:

## Sincroniza a antiga array active_party para que o CombatManager e os menus leiam os 3 kits equipados!
func synchronize_active_party() -> void:
	active_party.clear()
	for hero_key in active_kits:
		var current_kit_id = active_kits[hero_key]
		active_party.append(current_kit_id)

## Atualizado: Função utilitária para curar todos os kits equipados
func heal_active_party() -> void:
	# Garante que a lista está com os 3 kits atuais antes de rodar a cura
	synchronize_active_party()
	
	for id in active_party:
		if hero_collection.has(id):
			hero_collection[id].full_heal()
	print("❤️ [PlayerData] Toda a equipe ativa de kits foi totalmente curada!")

## Retorna o objeto completo do herói para a UI ou Combate lerem os dados
func get_hero(id_hero: String) -> HeroState:
	return hero_collection.get(id_hero, null)

func _ready() -> void:
	# Inicializa a conta com os kits base na memória
	pass

## Inicializa a coleção injetando os objetos de dados carregados nativamente pela Main
func initialize_roster_statically(starting_heroes: Array[HeroData]) -> void:
	hero_collection.clear()
	
	print("🛡️ [PlayerData] Injecting native web-safe starting roster...")
	for data in starting_heroes:
		if not data: continue
		
		var kit_id = data.id if not data.id.is_empty() else data.character_name.to_lower().replace(" ", "_")
		
		var new_state = HeroState.new()
		
		# 💎 FIX DE MEMÓRIA: Duplica o recurso para criar uma cópia única e isolada no motor!
		new_state.blueprint = data.duplicate()
		
		new_state.full_heal()
		
		hero_collection[kit_id] = new_state
		print("📦 [PlayerData] Kit carregado nativamente na Web: ", kit_id)
		
	synchronize_active_party()

## 🆕 FUNÇÃO DE RECRUTAMENTO NARRATIVO: Chamada pela Main ou diálogo ao vencer um chefe!
func unlock_skin_for_hero(hero_owner: String, new_kit_id: String) -> void:
	# Evita duplicar o desbloqueio caso a função seja chamada duas vezes por engano
	match hero_owner:
		"altria":
			if not unlocked_altria_kits.has(new_kit_id): unlocked_altria_kits.append(new_kit_id)
		"mash":
			if not unlocked_mash_kits.has(new_kit_id): unlocked_mash_kits.append(new_kit_id)
		"hero3":
			if not unlocked_hero3_kits.has(new_kit_id): unlocked_hero3_kits.append(new_kit_id)
			
	# Monta o caminho do arquivo do novo kit/skin ganho do chefe
	var path = "res://resources/heroes/" + new_kit_id + ".tres"
	
	if ResourceLoader.exists(path) or ResourceLoader.exists(path + ".remap"):
		var data = load(path) as HeroData
		if data:
			var new_state = HeroState.new()
			new_state.blueprint = data
			new_state.current_exp = 0
			new_state.full_heal()
			
			# Registra a nova skin no banco de dados geral de heróis
			hero_collection[new_kit_id] = new_state
			print("🏅 [PlayerData] NOVA SKIN DESBLOQUEADA PARA %s: %s" % [hero_owner.to_upper(), data.character_name])
			
			# 💾 Salva o progresso no disco na hora para o jogador não perder o drop!
			if SaveManager.has_method("save_game"):
				SaveManager.save_game()
