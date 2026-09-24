extends Control

signal missao_iniciada(story_event: StoryEvent)
signal missao_abortada

@export var botao_missao: Button
@export var botao_abortar: Button

func _ready() -> void:
	_atualizar_interface_do_mapa()

func _atualizar_interface_do_mapa() -> void:
	if PlayerData.missao_em_andamento:
		botao_missao.text = "Continuar Missão (Parte 2)"
		botao_abortar.visible = true
	else:
		botao_missao.text = "Iniciar Missão"
		botao_abortar.visible = false

func _on_botao_missao_pressed() -> void:
	var evento = StoryEvent.new()
	var novas_linhas: Array[StoryLine] = []
	var novas_escolhas: Array[StoryChoice] = []
	
	if not PlayerData.missao_em_andamento:
		# --- PARTE 1: CONFIGURA O EVENTO QUE TRAVA E DÁ DANO ---
		var l1 = StoryLine.new()
		l1.character_name = "Mash"
		l1.text = "Senpai! Fomos emboscados no corredor! Ativando defesas!"
		novas_linhas.append(l1)
		
		var escolha = StoryChoice.new()
		escolha.choice_text = "Fugir para a sala segura"
		
		var ev_parte1 = GameEvent.new()
		ev_parte1.set_missao_em_andamento = true # Manda ligar a flag
		ev_parte1.heroi_id = "mash_01"
		ev_parte1.hp_modifier = -40              # Manda tirar 40 de HP
		
		escolha.trigger_game_event = ev_parte1
		novas_escolhas.append(escolha)
	else:
		# --- PARTE 2: CONFIGURA O EVENTO QUE DESTRAVA E CURA ---
		var l2 = StoryLine.new()
		l2.character_name = "Mash"
		l2.text = "Ufa, chegamos à sala segura! Missão cumprida, time restaurado!"
		novas_linhas.append(l2)
		
		var escolha_fim = StoryChoice.new()
		escolha_fim.choice_text = "Descansar"
		
		var ev_parte2 = GameEvent.new()
		ev_parte2.set_missao_em_andamento = false # Manda desligar a flag
		ev_parte2.heroi_id = "mash_01"
		ev_parte2.hp_modifier = 40                 # Manda curar os 40 de HP de volta
		
		escolha_fim.trigger_game_event = ev_parte2
		novas_escolhas.append(escolha_fim)
		
	evento.dialogue_lines = novas_linhas
	evento.choices = novas_escolhas
	missao_iniciada.emit(evento)

func _on_botao_abortar_pressed() -> void:
	PlayerData.missao_em_andamento = false
	if PlayerData.colecao_herois.has("mash_01"):
		PlayerData.colecao_herois["mash_01"]["hp_atual"] = 100
		
	print("❌ [Mapa] Missão abortada! Mash foi totalmente curada.")
	_atualizar_interface_do_mapa()
