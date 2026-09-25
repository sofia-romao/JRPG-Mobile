extends Node
class_name MainController

@export_category("Containers")
@export var scene_container: Node

# Caminhos absolutos das três cenas equivalentes
const EXPLORATION_SCENE_PATH = "res://test_exploration_scene.tscn"
const DIALOGUE_SCENE_PATH = "res://scenes/dialogue_box.tscn"
const COMBAT_SCENE_PATH = "res://scenes/combat_manager.tscn"

var _current_active_scene: Node = null

func _ready() -> void:
	if scene_container == null:
		push_error("Main: O nó 'SceneContainer' não foi atribuído no Inspector!")
		return
		
	# O jogo começa direto no ambiente de Exploração/Menus
	_transicionar_para_cena(EXPLORATION_SCENE_PATH)

## Remove o ambiente anterior da memória e instancia o próximo de forma limpa
func _transicionar_para_cena(caminho_da_scene: String) -> Node:
	if _current_active_scene != null:
		_current_active_scene.queue_free()
		_current_active_scene = null
		
	var recurso_cena = load(caminho_da_scene)
	if recurso_cena == null:
		push_error("Main: Falha ao carregar a cena em: " + caminho_da_scene)
		return null
		
	var nova_instancia = recurso_cena.instantiate()
	scene_container.add_child(nova_instancia)
	_current_active_scene = nova_instancia
	
	# Conecta os sinais do novo ambiente que acabou de nascer
	_conectar_sinais_da_cena_ativa(nova_instancia)
	
	return nova_instancia

## Escuta os sinais de término de cada um dos 3 ambientes
func _conectar_sinais_da_cena_ativa(cena: Node) -> void:
	# 1. Se a cena ativa for a EXPLORAÇÃO
	if cena.has_signal("missao_iniciada"):
		cena.connect("missao_iniciada", _on_exploracao_solicitou_dialogo)
		
	# 2. Se a cena ativa for o DIÁLOGO (Nosso DialogueManager que emite sinais)
	if cena.has_signal("dialogue_finished"):
		cena.connect("dialogue_finished", _on_dialogue_terminou)
	if cena.has_signal("game_event_triggered"):
		cena.connect("game_event_triggered", _on_dialogue_disparou_evento)
		
	# 3. Se a cena ativa for o COMBATE
	if cena.has_signal("combate_concluido"):
		cena.connect("combate_concluido", _on_combate_terminou)

# --- RECEPTORES DE SINAIS (MÁQUINA DE ESTADOS DA MAIN) ---

# O jogador clicou em algo na Exploração -> Transiciona para o ambiente de Diálogo
func _on_exploracao_solicitou_dialogo(story_event: StoryEvent) -> void:
	print("🔄 Main: Saindo da Exploração e instanciando o Diálogo...")
	var tela_dialogo = _transicionar_para_cena(DIALOGUE_SCENE_PATH) as DialogueManager
	
	if tela_dialogo:
		# Injeta o dado e dá o play no diálogo que acabou de nascer!
		tela_dialogo.start_dialogue(story_event)

# O Diálogo acabou normalmente (sem lutas) -> Devolve o jogador para a Exploração
func _on_dialogue_terminou() -> void:
	# Espera um frame para garantir que os sinais de GameEvent atualizaram o PlayerData
	await get_tree().process_frame
	
	print("\n📊 [STATUS DO TIME SALVO NO AUTOLOAD]")
	for heroi_id in PlayerData.party_ativa:
		var heroi: HeroState = PlayerData.get_heroi(heroi_id)
		if heroi and heroi.blueprint:
			# Agora puxamos o nome do blueprint e o max_hp calculado em tempo real!
			print("👤 %s -> HP Atual: %d/%d (Nv. %d)" % [
				heroi.blueprint.nome, 
				heroi.hp_atual, 
				heroi.get_max_hp(), 
				heroi.get_nivel()
			])
	print("📌 Estado da Missão Em Andamento: ", PlayerData.missao_em_andamento)
	print("-----------------------------------------\n")
	
	_transicionar_para_cena(EXPLORATION_SCENE_PATH)

# O Diálogo fez uma escolha que gerou um GameEvent (ex: Iniciar Batalha ou Dano via diálogo)
func _on_dialogue_disparou_evento(event: GameEvent) -> void:
	if event == null: return
	
	# 1. Seta a flag de missão em andamento herdada do seu sistema original
	PlayerData.missao_em_andamento = event.set_missao_em_andamento
	
	# 2. Executa a unificação baseada no tipo de evento usando as novas regras seguras
	match event.tipo_evento:
		GameEvent.EventType.INICIAR_BATALHA:
			print("⚔️ Main: Evento disparou início de combate!")
			_transicionar_para_cena(COMBAT_SCENE_PATH)
			
		GameEvent.EventType.CONCLUIR_MISSAO:
			print("🏆 Main: Evento disparou conclusão de missão!")
			PlayerData.missao_em_andamento = false
			PlayerData.curar_party_ativa()
			
		GameEvent.EventType.MODIFICAR_ATRIBUTO:
			if event.heroi_id != "":
				# Modifica o HP de um herói específico usando a função atualizada (com clamp automático)
				if event.hp_modifier != 0:
					PlayerData.atualizar_hp_por_id(event.heroi_id, event.hp_modifier)
			else:
				# Se heroi_id estiver vazio, aplica o dano/cura no time inteiro ativo de graça!
				if event.hp_modifier != 0:
					for id in PlayerData.party_ativa:
						PlayerData.atualizar_hp_por_id(id, event.hp_modifier)
						
		GameEvent.EventType.CURAR_TOTAL:
			if event.heroi_id != "":
				var heroi = PlayerData.get_heroi(event.heroi_id)
				if heroi: heroi.curar_total()
			else:
				PlayerData.curar_party_ativa()

# O Combate acabou -> Devolve o jogador para a Exploração
func _on_combate_terminou(vitoria: bool) -> void:
	print("🏁 Main: Batalha encerrada! Vitória: ", vitoria, ". Voltando para a Exploração...")
	
	# Se a missão NÃO está em andamento (ou seja, era uma missão simples de uma parte só),
	# nós aplicamos a cura automática de fim de missão aqui!
	if not PlayerData.missao_em_andamento:
		PlayerData.curar_party_ativa()
		
	_transicionar_para_cena(EXPLORATION_SCENE_PATH)
