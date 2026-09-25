extends Button

# Arraste o arquivo do Jack Frost aqui pelo Inspector do Godot
@export var inimigo_teste: EnemyData 

# Sinal que a sua MainController já está programada para escutar na cena de exploração
signal missao_iniciada(story_event: StoryEvent)

func _ready() -> void:
	# Conecta o clique do próprio botão à função que inicia a treta
	pressed.connect(_on_botao_pressionado)
	
	# Alerta caso você esqueça de arrastar o Jack Frost no Inspector
	if inimigo_teste == null:
		push_warning("Botão Teste: Lembre-se de arrastar o recurso 'jack_frost.tres' no Inspector!")

func _on_botao_pressionado() -> void:
	if inimigo_teste == null:
		print("❌ Não é possível testar: Nenhum inimigo configurado.")
		return
		
	print("⚔️ Botão Teste: Gerando dados de combate para o Jack Frost...")
	
	# 1. Criamos o CombatData e injetamos o Jack Frost nele
	var dados_luta = CombatData.new()
	dados_luta.inimigo = inimigo_teste
	# Se quiser testar o evento de vitória automática depois, descomente as linhas abaixo:
	# var recompensa = GameEvent.new()
	# recompensa.tipo_evento = GameEvent.EventType.CURAR_TOTAL
	# dados_luta.evento_vitoria = recompensa

	# 2. Criamos o GameEvent de batalha e injetamos o CombatData nele
	var evento_batalha = GameEvent.new()
	evento_batalha.tipo_evento = GameEvent.EventType.INICIAR_BATALHA
	evento_batalha.combat_data = dados_luta
	
	# 3. Criamos o StoryEvent exigido pela sua MainController
	# Como é um teste, criamos um recurso genérico vazio na memória
	var evento_historia = StoryEvent.new()
	
	# !!! NOTA: Se o seu StoryEvent original precisar de uma lista de eventos, 
	# você pode adicioná-lo à propriedade correspondente do seu script original, ex:
	# evento_historia.lista_eventos = [evento_batalha]
	
	print("🚀 Botão Teste: Disparando sinal 'missao_iniciada' para a MainController...")
	# Emitimos o sinal. A MainController vai interceptar, ler os dados e abrir a arena!
	missao_iniciada.emit(evento_historia)
