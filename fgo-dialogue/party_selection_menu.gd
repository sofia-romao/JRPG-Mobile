extends Control
# 🖥️ PARTY SELECTION MENU - Gerencia a interface de montagem do time

@export_category("Configurações de Cena")
## Arraste aqui o seu arquivo .tscn do cartão (hero_selection_card.tscn)
@export var card_prefab: PackedScene 

@export_category("Nós da Interface")
## Arraste aqui o seu GridContainer onde os cartões vão nascer
@export var grid_container: GridContainer
## OPCIONAL: Um Label para avisar o jogador se a equipe estiver trancada
@export var label_aviso_trancado: Label

func _ready() -> void:
	if not card_prefab:
		push_error("PartyMenu: Esqueceu de arrastar o card_prefab no Inspector!")
		return
	if not grid_container:
		push_error("PartyMenu: Esqueceu de arrastar o grid_container no Inspector!")
		return
		
	# Monta a lista visual de heróis assim que a tela abre
	atualizar_menu_ui()

## Limpa o grid e redesenha todos os heróis com seus status atuais
func atualizar_menu_ui() -> void:
	# 1. Limpa os cartões antigos do grid para não duplicar
	for filho in grid_container.get_children():
		filho.queue_free()
		
	# 2. Atualiza o texto de aviso se a missão composta estiver trancada
	var trancado: bool = PlayerData.missao_em_andamento
	if label_aviso_trancado:
		label_aviso_trancado.visible = trancado
		label_aviso_trancado.text = "⚠️ MISSÃO EM ANDAMENTO - EQUIPE TRANCADA"
		
	# 3. Varre a coleção global do PlayerData e spawna os cartões
	for heroi_id in PlayerData.colecao_herois:
		var estado: HeroState = PlayerData.colecao_herois[heroi_id]
		
		# Verifica se este herói específico está atualmente na equipe de 3
		var esta_na_party: bool = PlayerData.party_ativa.has(heroi_id)
		
		# Instancia o cartão visual
		var novo_cartao = card_prefab.instantiate()
		grid_container.add_child(novo_cartao)
		
		# Configura os dados do cartão (passando as flags de seleção e bloqueio)
		novo_cartao.configurar_cartao(heroi_id, estado, esta_na_party, trancado)
		
		# Escuta o sinal de clique que o cartão emite
		novo_cartao.card_clicked.connect(_on_card_selecionado)

## Função que roda sempre que o jogador clica em qualquer cartão de herói
func _on_card_selecionado(id_heroi: String) -> void:
	if PlayerData.missao_em_andamento: return
		
	# 1. Modifica o array (Sua lógica perfeita de antes)
	if PlayerData.party_ativa.has(id_heroi):
		PlayerData.party_ativa.erase(id_heroi)
	else:
		if PlayerData.party_ativa.size() < PlayerData.MAX_PARTY_SIZE:
			PlayerData.party_ativa.append(id_heroi)
			
	# 2. 🛠️ EM VEZ DE CHAMAR atualizar_menu_ui(), ATUALIZAMOS OS CARTOES EXISTENTES:
	# Varre os nós filhos do grid que já estão vivos na tela!
	for cartao in grid_container.get_children():
		var id = cartao.heroi_id
		var estado = PlayerData.colecao_herois[id]
		var esta_na_party = PlayerData.party_ativa.has(id)
		var trancado = PlayerData.missao_em_andamento
		
		# Atualiza o cartão. Como ele não foi deletado, a animação vai rodar 
		# LINDA e ISOLADA apenas no cartão que mudou de estado!
		cartao.configurar_cartao(id, estado, esta_na_party, trancado)
