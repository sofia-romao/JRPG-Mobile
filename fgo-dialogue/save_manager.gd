# save_manager.gd
extends Node

const SAVE_PATH = "user://savegame.tres" 

## Cria o resource de save, injeta os dados globais e grava no disco
func save_game() -> void:
	var save_res = SaveGameData.new()
	
	# Passa as variáveis simples do Autoload para o Resource
	save_res.active_mission_id = PlayerData.active_mission_id
	save_res.completed_missions = PlayerData.completed_missions
	save_res.active_party = PlayerData.active_party
	
	# 📦 Salva as listas de kits desbloqueados permanentemente
	save_res.unlocked_altria_kits = PlayerData.unlocked_altria_kits
	save_res.unlocked_mash_kits = PlayerData.unlocked_mash_kits
	save_res.unlocked_hero3_kits = PlayerData.unlocked_hero3_kits
	
	# Captura o progresso dinâmico de cada herói na coleção (Apenas recursos atuais)
	for hero_id in PlayerData.hero_collection:
		var hero_state: HeroState = PlayerData.hero_collection[hero_id]
		save_res.hero_stats[hero_id] = {
			"current_hp": hero_state.current_hp,
			"current_mp": hero_state.current_mp
		}
	
	# Salva o arquivo de uma vez só como recurso nativo do Godot
	var error = ResourceSaver.save(save_res, SAVE_PATH)
	if error == OK:
		print("💾 [SaveManager] Game saved successfully as Resource to: ", SAVE_PATH)
	else:
		push_error("❌ [SaveManager] Failed to save resource file! Error code: ", error)

## Carrega o Resource do disco e devolve as variáveis para o PlayerData
func load_game() -> bool:
	if not ResourceLoader.exists(SAVE_PATH):
		print("⚠️ [SaveManager] No save resource found.")
		return false
		
	var save_res = ResourceLoader.load(SAVE_PATH) as SaveGameData
	if not save_res:
		push_error("❌ [SaveManager] Failed to load or cast the save resource!")
		return false
		
	# Devolve as variáveis do Resource de volta para o Autoload global
	PlayerData.active_mission_id = save_res.active_mission_id
	PlayerData.completed_missions = save_res.completed_missions
	PlayerData.active_party = save_res.active_party
	
	# 📦 Restaura as listas de kits desbloqueados no PlayerData
	PlayerData.unlocked_altria_kits = save_res.unlocked_altria_kits
	PlayerData.unlocked_mash_kits = save_res.unlocked_mash_kits
	PlayerData.unlocked_hero3_kits = save_res.unlocked_hero3_kits
	
	# Aplica a vida e mana salvas em cima das instâncias de heróis
	for hero_id in save_res.hero_stats:
		# 🏅 Mapa explícito que associa o ID da Skin/Kit ao seu Herói Base (Owner)
		# Se você criar novas skins no futuro, basta listar o ID do kit e quem o possui aqui!
		var kit_to_owner_map: Dictionary = {
			"altria": "altria",
			"altria_frost": "altria", 
			"mash": "mash",
			"new_hero": "hero3",       # Garante que o herói inicial do log seja mapeado corretamente
			"barghest_skin": "hero3"   # Exemplo de skin futura ganha em chefes
		}
		
		# Se for uma skin/kit já registrado no progresso mas que não está na memória viva da coleção, reconstrói!
		if not PlayerData.hero_collection.has(hero_id):
			var owner_hero = kit_to_owner_map.get(hero_id, "hero3") # Cai para "hero3" por segurança padrão
			PlayerData.unlock_skin_for_hero(owner_hero, hero_id)
			
		if PlayerData.hero_collection.has(hero_id):
			var hero_state: HeroState = PlayerData.hero_collection[hero_id]
			var stats = save_res.hero_stats[hero_id]
			
			# Resgata os status, usando os valores máximos do blueprint fixo como fallback seguro
			hero_state.current_hp = stats.get("current_hp", hero_state.get_max_hp())
			hero_state.current_mp = stats.get("current_mp", hero_state.get_max_mp())
		# 🔑 Executa o pente fino do Lock & Key após restaurar as missões concluídas do disco
	PlayerData.evaluate_mission_rewards_statically()
			
	print("📂 [SaveManager] Game resource loaded successfully!")
	return true
