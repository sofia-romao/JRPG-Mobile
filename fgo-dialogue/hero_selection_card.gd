extends Button

# Sinais para avisar o menu principal que este cartão foi clicado
signal card_clicked(id_heroi: String)

@export_category("Componentes Visuais")
@export var texture: TextureRect
@export var label_nome: Label
@export var label_HP: Label
@export var overlay: ColorRect
@export var margin: MarginContainer

# Guardamos o ID deste herói para saber quem enviar no sinal de clique
var heroi_id: String = ""

func _ready() -> void:
	# Conecta o sinal de clique do próprio botão a uma função local
	pressed.connect(_on_pressed)

## Função que o menu principal vai chamar para configurar ou atualizar o cartão
func configurar_cartao(id: String, estado: HeroState, esta_na_party: bool, jogo_trancado: bool) -> void:
	heroi_id = id
	
	# 1. Alimenta os textos e imagens com a nossa nova arquitetura
	label_nome.text = estado.blueprint.nome
	label_HP.text = "HP: %d/%d" % [estado.hp_atual, estado.get_max_hp()]
	
	if texture and estado.blueprint.icone_avatar:
		texture.texture = estado.blueprint.icone_avatar
		
	# 2. Gerencia o overlay de bloqueio (se a missão composta estiver em andamento)
	if overlay:
		overlay.visible = jogo_trancado
	disabled = jogo_trancado # Desativa o clique se o jogo estiver trancado
	
	# 3. Executa a animação de deslizar baseada no estado de seleção
	_animar_deslocamento(esta_na_party)

## Controla o efeito visual de mover o conteúdo para o lado de forma segura
var meu_tween: Tween # Guardamos a referência do tween no topo do script

func _animar_deslocamento(selecionado: bool) -> void:
	if not margin: return
	
	# Se já existir uma animação rodando neste cartão, interrompe ela imediatamente
	if meu_tween and meu_tween.is_valid():
		meu_tween.kill()
		
	if margin.get("theme_override_constants/margin_left") == null:
		margin.set("theme_override_constants/margin_left", 0)

	var valor_alvo = 25 if selecionado else 0
	
	# 🛠️ SÓ ANIMA SE O VALOR MUDOU: Se o cartão já está na posição certa, não faz nada!
	if margin.get("theme_override_constants/margin_left") == valor_alvo:
		return

	meu_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	meu_tween.tween_property(margin, "theme_override_constants/margin_left", valor_alvo, 0.15)

## Quando o jogador clica no cartão, avisa o menu principal enviando o ID
func _on_pressed() -> void:
	card_clicked.emit(heroi_id)
