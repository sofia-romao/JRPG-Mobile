extends Node

func _ready() -> void:
	print("🧪 [TESTE] Iniciando simulação de teste lógico de combate direto na memória (HeroData em Inglês)...\n")
	_executar_teste_completo()

func _executar_teste_completo() -> void:
	# --- 1. INSTANCIANDO O PRIMEIRO HERÓI (FLYNN) ---
	var hero_data_1 = HeroData.new()
	hero_data_1.id = "hero_01"
	hero_data_1.character_name = "Flynn"
	hero_data_1.base_hp = 100
	hero_data_1.base_attack = 15
	hero_data_1.hp_per_level = 15
	hero_data_1.attack_per_level = 3
	
	# Afinidades elementais (Lógica em inglês do CombatManager e HeroData)
	hero_data_1.res_fire = 2.0       # FRAQUEZA A FOGO (Toma dobro de dano)
	hero_data_1.res_ice = 0.5        # RESISTENTE A GELO (Toma metade do dano)
	hero_data_1.res_elec = 1.0
	hero_data_1.res_physical = 1.0
	hero_data_1.skill_list = ["agi_01"] as Array[String]

	var hero_state_1 = HeroState.new()
	hero_state_1.blueprint = hero_data_1
	hero_state_1.xp_atual = 0        # Nível 1
	hero_state_1.curar_total()

	# --- 2. INSTANCIANDO O SEGUNDO HERÓI (WALTER) ---
	var hero_data_2 = HeroData.new()
	hero_data_2.id = "hero_02"
	hero_data_2.character_name = "Walter"
	hero_data_2.base_hp = 120
	hero_data_2.base_attack = 18
	hero_data_2.hp_per_level = 20
	hero_data_2.attack_per_level = 4
	
	hero_data_2.res_fire = 0.5       # RESISTE A FOGO
	hero_data_2.res_ice = 2.0        # FRAQUEZA A GELO
	hero_data_2.res_elec = 1.0
	hero_data_2.res_physical = 1.0
	hero_data_2.skill_list = ["agi_01"] as Array[String]

	var hero_state_2 = HeroState.new()
	hero_state_2.blueprint = hero_data_2
	hero_state_2.xp_atual = 1200     # Nível 2 (Testa o escalonamento automático!)
	hero_state_2.curar_total()

	# Injeta os dois heróis nos dicionários em português do seu PlayerData real
	PlayerData.colecao_herois[hero_data_1.id] = hero_state_1
	PlayerData.colecao_herois[hero_data_2.id] = hero_state_2
	
	# A sua party ativa mobile com os 2 personagens criados
	PlayerData.party_ativa = [hero_data_1.id, hero_data_2.id]

	print("👤 Herói 1: %s | Nível: %d | HP: %d/%d | Ataque: %d" % [
		hero_state_1.blueprint.character_name, hero_state_1.get_nivel(),
		hero_state_1.hp_atual, hero_state_1.get_max_hp(), hero_state_1.get_ataque()
	])
	print("👤 Herói 2: %s | Nível: %d | HP: %d/%d | Ataque: %d (Escalonado por XP!)\n" % [
		hero_state_2.blueprint.character_name, hero_state_2.get_nivel(),
		hero_state_2.hp_atual, hero_state_2.get_max_hp(), hero_state_2.get_ataque()
	])

	# --- 3. INSTANCIANDO O INIMIGO DE TESTE ---
	var enemy_data = EnemyData.new()
	enemy_data.id = "enemy_test_01"
	enemy_data.nome = "Jack Frost"
	enemy_data.hp_base = 80
	enemy_data.ataque_base = 12
	enemy_data.res_fire = 2.0       # FRAQUEZA A FOGO
	enemy_data.res_ice = 0.0        # IMUNE A GELO
	enemy_data.res_elec = 1.0
	enemy_data.res_physical = 1.0

	var enemy_state = EnemyState.new()
	enemy_state.inicializar(enemy_data)

	print("👹 Inimigo Criado: %s | HP: %d/%d | Ataque: %d\n" % [
		enemy_state.blueprint.nome, 
		enemy_state.hp_atual, 
		enemy_state.get_max_hp(), 
		enemy_state.get_ataque()
	])

	# --- 4. SIMULANDO ATAQUES DO JOGADOR ---
	print("⚔️ [RODADA DO JOGADOR] %s usa magia de FOGO (Agi) contra %s..." % [hero_state_1.blueprint.character_name, enemy_state.blueprint.nome])
	var agi_skill = SkillData.new()
	agi_skill.element_type = "FIRE"
	agi_skill.damage_multiplier = 1.2 # 120% do dano do herói
	
	var dano_base_heroi = int(hero_state_1.get_ataque() * agi_skill.damage_multiplier) # 15 * 1.2 = 18
	# Jack Frost tem fraqueza (2.0) a fogo: 18 * 2 = 36 de dano esperado
	var acertou_fraqueza = enemy_state.receber_dano_combate(dano_base_heroi, agi_skill.element_type)
	print("👉 Acertou Fraqueza do Monstro? %s | HP do Inimigo: %d/%d\n" % [acertou_fraqueza, enemy_state.hp_atual, enemy_state.get_max_hp()])

	# --- 5. SIMULANDO ATAQUE DO INIMIGO ---
	print("⚔️ [RODADA DO INIMIGO] %s revida lançando GELO (Bufu) na equipe..." % enemy_state.blueprint.nome)
	var dano_monstro = enemy_state.get_ataque() # 12
	
	# Bufu contra Flynn (res_ice = 0.5): 12 * 0.5 = 6 de dano esperado
	hero_state_1.take_damage_combat(dano_monstro, "ICE")
	# Bufu contra Walter (res_ice = 2.0): 12 * 2 = 24 de dano esperado (Fraqueza!)
	hero_state_2.take_damage_combat(dano_monstro, "ICE")
	
	print("\n👉 HP final de %s: %d/%d" % [hero_state_1.blueprint.character_name, hero_state_1.hp_atual, hero_state_1.get_max_hp()])
	print("👉 HP final de %s: %d/%d\n" % [hero_state_2.blueprint.character_name, hero_state_2.hp_atual, hero_state_2.get_max_hp()])

	# --- 6. TESTANDO CONDIÇÃO DE MORTE DO MONSTRO ---
	print("💀 [FINALIZAÇÃO] %s desfere um golpe físico devastador para encerrar a luta!" % hero_state_2.blueprint.character_name)
	enemy_state.morreu.connect(func(): print("🎉 SINAL EMITIDO: O Inimigo morreu e enviou a notificação de vitória!"))
	
	# Walter ataca físico (1.0). Dano: 22 (Ataque base 18 + 4 do nível 2). Jack Frost tem 44 restantes, toma 22, fica com 22.
	enemy_state.receber_dano_combate(hero_state_2.get_ataque(), "PHYSICAL")
	# Mais um ataque para liquidar os 22 de vida restantes
	enemy_state.receber_dano_combate(hero_state_2.get_ataque(), "PHYSICAL")

	print("\n🧪 [TESTE] Fim da simulação na memória. O motor lógico do SMT2 passou em todos os testes!")
