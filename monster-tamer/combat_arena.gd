extends Node

# Sinal que a Main espera para saber que a luta acabou e voltar para a exploração
signal combate_concluido(vitoria: bool)

func inicializar_batalha(inimigos: Array[String], fundo: Texture2D) -> void:
	print("⚔️ [TESTE - ARENA] Batalha inicializada com sucesso!")
	print("👾 Inimigos carregados da Data: ", inimigos)
	print("🖼️ Fundo da Arena recebido: ", fundo != null)
	
	# Simula um combate curto: espera 3 segundos e encerra com vitória
	await get_tree().create_timer(3.0).timeout
	print("🏁 [TESTE - ARENA] Inimigo derrotado! Encerrando cena...")
	
	combate_concluido.emit(true)
