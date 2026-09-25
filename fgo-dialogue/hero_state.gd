class_name HeroState
extends Resource # Usamos Resource para facilitar o sistema de Save/Load no futuro

@export var blueprint: HeroData
@export var xp_atual: int = 0
@export var hp_atual: int = 0

## Calcula o nível atual baseado na XP. 
## Sinta-se livre para mudar essa fórmula linear simples depois!
func get_nivel() -> int:
	return int(xp_atual / 1000) + 1

## Busca o HP base no Blueprint e soma o ganho por nível dinamicamente
func get_max_hp() -> int:
	if not blueprint: return 0
	# (Nível - 1) porque no nível 1 ele tem apenas o status base
	return blueprint.hp_base + (blueprint.hp_por_nivel * (get_nivel() - 1))

## Busca o Ataque dinamicamente
func get_ataque() -> int:
	if not blueprint: return 0
	return blueprint.ataque_base + (blueprint.ataque_por_nivel * (get_nivel() - 1))

## Atualiza o HP garantindo que ele fique entre 0 e o Max HP atual
func modificar_hp(quantidade: int) -> void:
	hp_atual = clamp(hp_atual + quantidade, 0, get_max_hp())

## Cura total (usado ao limpar missões)
func curar_total() -> void:
	hp_atual = get_max_hp()
