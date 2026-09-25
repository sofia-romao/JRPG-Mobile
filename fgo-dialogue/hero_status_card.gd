# HeroStatusCard.gd
extends MarginContainer

@export var nome_label: Label
@export var level_label: Label
@export var hp_label: Label

var state_associado: HeroState

# Inicializa o cartão com os dados do Autoload
func configurar_card(heroi_state: HeroState) -> void:
	state_associado = heroi_state
	name = heroi_state.blueprint.id # Facilita encontrar o nó pelo ID depois
	
	# Preenche os dados iniciais usando os métodos dinâmicos que você criou
	nome_label.text = heroi_state.blueprint.nome
	level_label.text = "Lv. " + str(heroi_state.get_nivel())
	_atualizar_texto_hp(heroi_state.hp_atual, heroi_state.get_max_hp())
	
	# Conecta o sinal de HP do herói para atualizar a UI automaticamente quando ele levar dano
	# Nota: Certifique-se de que o sinal hp_alterado no seu HeroState passe (novo_hp, max_hp)
	if heroi_state.has_signal("hp_alterado"):
		heroi_state.hp_alterado.connect(_on_heroi_hp_alterado)

func animar_selecao(selecionado: bool) -> void:
	var tween = create_tween()
	var alvo_margin = 25 if selecionado else 0
	
	# Executa o slide out de 25px conforme o escopo do seu projeto
	tween.tween_property(self, "theme_override_constants/margin_left", alvo_margin, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func _on_heroi_hp_alterado(novo_hp: int, max_hp: int, _mudanca: int) -> void:
	_atualizar_texto_hp(novo_hp, max_hp)

func _atualizar_texto_hp(atual: int, maximo: int) -> void:
	hp_label.text = "HP: " + str(atual) + "/" + str(maximo)
