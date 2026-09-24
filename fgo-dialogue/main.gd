extends Node
class_name MainController

@export_category("Containers")
@export var scene_container: Node

# Caminhos absolutos das três cenas equivalentes
const EXPLORATION_SCENE_PATH = "res://test_exploration_scene.tscn"
const DIALOGUE_SCENE_PATH = "res://scenes/dialogue_box.tscn"
const COMBAT_SCENE_PATH = "res://scenes/combat_arena.tscn"

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
	# 🔴 O SEGREDO ESTÁ AQUI: Espera um frame para garantir que os sinais 
	# de GameEvent atualizaram o PlayerData antes de renderizar o mapa!
	await get_tree().process_frame
	
	print("\n📊 [STATUS DO TIME SALVO NO AUTOLOAD]")
	for heroi_id in PlayerData.party_ativa:
		var dados = PlayerData.get_dados_heroi(heroi_id)
		print("👤 %s -> HP Atual: %d/100" % [dados.get("nome"), dados.get("hp_atual")])
	print("📌 Estado da Missão Em Andamento: ", PlayerData.missao_em_andamento)
	print("-----------------------------------------\n")
	
	_transicionar_para_cena(EXPLORATION_SCENE_PATH)
# O Diálogo fez uma escolha que gerou um GameEvent (ex: Iniciar Batalha)
func _on_dialogue_disparou_evento(event: GameEvent) -> void:
	if event == null: return
	
	PlayerData.missao_em_andamento = event.set_missao_em_andamento
	if event.heroi_id != "" and event.hp_modifier != 0:
		if PlayerData.colecao_herois.has(event.heroi_id):
			var hp_velho = PlayerData.colecao_herois[event.heroi_id]["hp_atual"]
			# Executa a matemática cega pura baseada no Resource
			PlayerData.atualizar_hp(event.heroi_id, hp_velho + event.hp_modifier)

# O Combate acabou -> Devolve o jogador para a Exploração
func _on_combate_terminou(vitoria: bool) -> void:
	print("🏁 Main: Batalha encerrada! Vitória: ", vitoria, ". Voltando para a Exploração...")
	_transicionar_para_cena(EXPLORATION_SCENE_PATH)
