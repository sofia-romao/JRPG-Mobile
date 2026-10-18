extends Node

# Linka automaticamente com o DialogueManager onde ele está inserido
@onready var dialogue_manager: DialogueManager = get_parent()

# Slots para você arrastar imagens de teste se quiser (Opcional!)
@export var retrato_heroi: Texture2D
@export var retrato_vilao: Texture2D

func _ready() -> void:
	# Espera a cena carregar totalmente
	await get_tree().process_frame
	
	if dialogue_manager == null:
		print("❌ Erro: O DialogueTester precisa ser filho do DialogueBox!")
		return
		
	_iniciar_simulacao_fgo()

func _iniciar_simulacao_fgo() -> void:
	print("🚀 [TESTE] Iniciando simulação estilo Fate/Grand Order...")
	
	# --- 1. EVENTO PRINCIPAL ---
	var evento_principal = StoryEvent.new()
	
	# Linha 1: Diálogo Padrão
	var l1 = StoryLine.new()
	l1.character_name = "Mash"
	l1.text = "Senpai! Leituras térmicas detectadas à frente. Por favor, mantenha-se atrás do meu escudo!"
	l1.character_portrait = retrato_heroi
	evento_principal.dialogue_lines.append(l1)
	
	# Linha 2: Emboscada (Impacto!)
	var l2 = StoryLine.new()
	l2.character_name = "⚠️ Alerta"
	l2.text = "BOM!!! Um ataque surpresa rompeu as linhas de defesa!"
	l2.character_portrait = retrato_heroi
	l2.shake_screen = true
	l2.flash_screen = Color(1, 0.1, 0.1, 0.5) # Clarão vermelho
	evento_principal.dialogue_lines.append(l2)
	
	# Linha 3: Aparição do Vilão
	var l3 = StoryLine.new()
	l3.character_name = "Servo Desconhecido"
	l3.text = "Tolos... Acharam mesmo que a Singularidade aceitaria a presença de Chaldea?"
	l3.character_portrait = retrato_vilao
	evento_principal.dialogue_lines.append(l3)
	
	# --- 2. CONFIGURANDO AS ESCOLHAS (ÁRVORE) ---
	var escolha_combate = StoryChoice.new()
	escolha_combate.choice_text = "Mash, contra-atacar com tudo!"
	# Criando a rota de combate
	var rota_combate = StoryEvent.new()
	var l_combate = StoryLine.new()
	l_combate.character_name = "Mash"
	l_combate.text = "Entendido, Master! Ativando: Lord Camelot!!"
	l_combate.character_portrait = retrato_heroi
	l_combate.flash_screen = Color(1, 1, 1, 0.8) # Clarão branco de energia
	rota_combate.dialogue_lines.append(l_combate)
	escolha_combate.next_event = rota_combate
	
	var escolha_recuo = StoryChoice.new()
	escolha_recuo.choice_text = "Recuar e reavaliar a situação."
	# Criando a rota de recuo
	var rota_recuo = StoryEvent.new()
	var l_recuo = StoryLine.new()
	l_recuo.character_name = "Mash"
	l_recuo.text = "Roger! Iniciando cortina de fumaça. Aguente firme, Senpai!"
	l_recuo.character_portrait = retrato_heroi
	rota_recuo.dialogue_lines.append(l_recuo)
	escolha_recuo.next_event = rota_recuo
	
	# Injeta as opções no evento inicial
	evento_principal.choices.append(escolha_combate)
	evento_principal.choices.append(escolha_recuo)
	
	# Monitora o encerramento total pelo sinal
	dialogue_manager.dialogue_finished.connect(func():
		print("🏁 [TESTE] O fluxo de diálogo foi encerrado com sucesso!")
	)
	
	# Dá o play no sistema!
	dialogue_manager.start_dialogue(evento_principal)
