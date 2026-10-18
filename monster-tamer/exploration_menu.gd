extends Control

# Sinal que a Main espera para saber que o jogador clicou em uma missão
signal missao_iniciada(story_event: StoryEvent)

@export_category("Imagens de Teste (Opcionais)")
@export var retrato_heroi: Texture2D
@export var retrato_vilao: Texture2D

func _ready() -> void:
	# Espera um frame para a Main se estabilizar e conectar os sinais
	await get_tree().process_frame
	_simular_clique_de_missao()

func _simular_clique_de_missao() -> void:
	print("🚀 [TESTE] Simulando jogador clicando em uma missão na Exploração...")
	
	# --- 1. CRIANDO O EVENTO PRINCIPAL ---
	var evento_principal = StoryEvent.new()
	
	# Linha 1: Fala com impacto visual
	var l1 = StoryLine.new()
	l1.character_name = "Mash"
	l1.text = "Senpai! Uma leitura de energia massiva foi detectada à frente!"
	l1.character_portrait = retrato_heroi
	l1.shake_screen = true
	l1.flash_screen = Color(1, 0.1, 0.1, 0.4) # Flash vermelho translúcido
	evento_principal.dialogue_lines.append(l1)
	
	# Linha 2: Fala normal
	var l2 = StoryLine.new()
	l2.character_name = "Mash"
	l2.text = "Por segurança, recomendo darmos a volta pelo setor leste."
	l2.character_portrait = retrato_heroi
	evento_principal.dialogue_lines.append(l2)
	
	# --- 2. CONFIGURANDO AS ESCOLHAS DE TEXTO PURO ---
	var escolha1 = StoryChoice.new()
	escolha1.choice_text = "Entendido, vamos recuar!"
	
	# Rota alternativa (Apenas mais texto, sem luta)
	var rota_recuo = StoryEvent.new()
	var l_recuo = StoryLine.new()
	l_recuo.character_name = "Mash"
	l_recuo.text = "Ativando propulsores de manobra. Mudando curso agora!"
	l_recuo.character_portrait = retrato_heroi
	rota_recuo.dialogue_lines.append(l_recuo)
	escolha1.next_event = rota_recuo
	
	var escolha2 = StoryChoice.new()
	escolha2.choice_text = "Espere, quero investigar mais de perto."
	
	var rota_investigar = StoryEvent.new()
	var l_investigar = StoryLine.new()
	l_investigar.character_name = "Mash"
	l_investigar.text = "Por favor, tome cuidado, Senpai... Avançando lentamente."
	l_investigar.character_portrait = retrato_heroi
	rota_investigar.dialogue_lines.append(l_investigar)
	escolha2.next_event = rota_investigar
	
	# Injeta as opções puras de texto na história
	evento_principal.choices.append(escolha1)
	evento_principal.choices.append(escolha2)
	
	# Dispara o sinal! A Main vai deletar esta tela e criar o Diálogo
	missao_iniciada.emit(evento_principal)
