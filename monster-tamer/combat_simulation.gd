# CombatManagerTestPuro.gd
extends Node

enum EstadoCombate { INICIALIZANDO, TURNO_HEROI, TURNO_INIMIGO, VITORIA, DERROTA }

var estado_atual: EstadoCombate = EstadoCombate.INICIALIZANDO
var inimigo_instanciado: EnemyState
var party_viva_ids: Array[String] = []
var indice_heroi_atual: int = 0
var rodada_atual: int = 1

func _ready() -> void:
	print("\n=== ⚔️ INICIANDO SIMULAÇÃO PURA E IMEDIATA DE LÓGICA ===")
	
	_configurar_player_data_ficticio()
	_iniciar_combate_ficticio()
	
	# O loop roda de forma puramente síncrona até mudar de estado
	while estado_atual != EstadoCombate.VITORIA and estado_atual != EstadoCombate.DERROTA:
		if estado_atual == EstadoCombate.TURNO_HEROI:
			_processar_turno_heroi_imediato()
		elif estado_atual == EstadoCombate.TURNO_INIMIGO:
			_processar_turno_inimigo_imediato()

func _configurar_player_data_ficticio() -> void:
	PlayerData.colecao_herois.clear()
	PlayerData.party_ativa.clear()
	PlayerData.missao_em_andamento = false
	
	# Herói 1: Arthur (Equilibrado)
	var bp_arthur = HeroData.new()
	bp_arthur.id = "arthur_id"
	bp_arthur.nome = "Arthur"
	bp_arthur.hp_base = 40
	bp_arthur.hp_por_nivel = 10
	bp_arthur.ataque_base = 12
	
	var state_arthur = HeroState.new()
	state_arthur.blueprint = bp_arthur
	state_arthur.hp_atual = state_arthur.get_max_hp()
	
	# Herói 2: Beatrice (Vidro de Canhão - Alto ataque, pouca vida)
	var bp_beatrice = HeroData.new()
	bp_beatrice.id = "beatrice_id"
	bp_beatrice.nome = "Beatrice"
	bp_beatrice.hp_base = 20
	bp_beatrice.hp_por_nivel = 5
	bp_beatrice.ataque_base = 25
	
	PlayerData.colecao_herois[bp_arthur.id] = state_arthur
	PlayerData.party_ativa = [bp_arthur.id, bp_beatrice.id]

func _iniciar_combate_ficticio() -> void:
	var bp_goblin = EnemyData.new()
	bp_goblin.id = "goblin_id"
	bp_goblin.nome = "Orco Chefe"
	bp_goblin.hp_base = 90
	bp_goblin.ataque_base = 15
	bp_goblin.xp_recompensa = 60
	
	inimigo_instanciado = EnemyState.new()
	inimigo_instanciado.inicializar(bp_goblin)
	
	print("▶️ Enfrentando: ", inimigo_instanciado.blueprint.nome, " (HP: ", inimigo_instanciado.hp_atual, ")")
	_atualizar_lista_party_viva()
	estado_atual = EstadoCombate.TURNO_HEROI
	print("\n--- 🔄 RODADA ", rodada_atual, " ---")

func _processar_turno_heroi_imediato() -> void:
	if indice_heroi_atual >= party_viva_ids.size():
		estado_atual = EstadoCombate.TURNO_INIMIGO
		return
		
	var heroi_id = party_viva_ids[indice_heroi_atual]
	var heroi_state = PlayerData.colecao_herois[heroi_id]
	
	# Lógica do Ataque do Herói
	var dano = heroi_state.blueprint.ataque_base
	inimigo_instanciado.receber_dano(dano)
	print("👤 ", heroi_state.blueprint.nome, " ataca -> Causa ", dano, " de dano. (HP do Inimigo: ", inimigo_instanciado.hp_atual, ")")
	
	_checar_condicoes_fim()
	if estado_atual == EstadoCombate.VITORIA:
		return
		
	indice_heroi_atual += 1

func _processar_turno_inimigo_imediato() -> void:
	print("👹 Vez do Inimigo: ", inimigo_instanciado.blueprint.nome)
	
	# Alvo aleatório
	var alvo_id = party_viva_ids.pick_random()
	var heroi_alvo: HeroState = PlayerData.colecao_herois[alvo_id]
	
	# Lógica do Ataque do Inimigo
	var dano_monstro = inimigo_instanciado.get_ataque()
	heroi_alvo.modificar_hp(-dano_monstro)
	print("🩸 ", inimigo_instanciado.blueprint.nome, " ataca ", heroi_alvo.blueprint.nome, " -> Causa ", dano_monstro, " de dano. (HP de ", heroi_alvo.blueprint.nome, ": ", heroi_alvo.hp_atual, ")")
	
	# Reseta índices para a próxima rodada
	indice_heroi_atual = 0
	_atualizar_lista_party_viva()
	
	_checar_condicoes_fim()
	if estado_atual != EstadoCombate.DERROTA:
		estado_atual = EstadoCombate.TURNO_HEROI
		rodada_atual += 1
		print("\n--- 🔄 RODADA ", rodada_atual, " ---")

func _atualizar_lista_party_viva() -> void:
	var antigas_ids = party_viva_ids.duplicate()
	party_viva_ids.clear()
	
	for heroi_id in PlayerData.party_ativa:
		var state = PlayerData.colecao_herois[heroi_id]
		if state.hp_atual > 0:
			party_viva_ids.append(heroi_id)
		elif heroi_id in antigas_ids:
			print("💀 ", state.blueprint.nome, " caiu em batalha!")

func _checar_condicoes_fim() -> void:
	if inimigo_instanciado.hp_atual <= 0:
		estado_atual = EstadoCombate.VITORIA
		print("\n🏆 VITÓRIA! O Inimigo foi derrotado. Recompensa de XP: ", inimigo_instanciado.blueprint.xp_recompensa)
	elif party_viva_ids.is_empty():
		estado_atual = EstadoCombate.DERROTA
		print("\n💀 GAME OVER! A party inteira foi eliminada.")
