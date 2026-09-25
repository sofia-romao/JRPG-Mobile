# DamagePopup.gd
extends Label

func exibir(valor: int, posicao_global: Vector2, cor: Color = Color.WHITE) -> void:
	# Configura o texto e a cor base (ex: vermelho para herói levando dano, branco para inimigo)
	text = str(valor)
	modulate = cor
	global_position = posicao_global
	
	# Centraliza o pivô para que animações partam do meio do texto
	pivot_offset = size / 2.0
	
	# Cria o Tween de animação
	var tween = create_tween().set_parallel(true)
	
	# 1. Move para cima (sobe 40 pixels em 0.5 segundos)
	var posicao_alvo = global_position + Vector2(0, -40)
	tween.tween_property(self, "global_position", posicao_alvo, 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	# 2. Fade Out (vai sumindo até ficar transparente)
	var cor_transparente = Color(cor.r, cor.g, cor.b, 0.0)
	tween.tween_property(self, "modulate", cor_transparente, 0.5)\
		.set_delay(0.1) # Começa o fade um pouquinho depois do movimento
		
	# 3. Deleta o nó do jogo assim que o Tween terminar completamente
	tween.chain().tween_callback(queue_free)
