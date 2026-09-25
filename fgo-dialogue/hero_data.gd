class_name HeroData
extends Resource

@export_group("Identidade")
@export var id: String = ""
@export var nome: String = ""

@export_group("Visual Minimalista")
@export var cor_tema: Color = Color.WHITE
@export var icone_avatar: Texture2D

@export_group("Atributos Base (Nível 1)")
@export var hp_base: int = 100
@export var ataque_base: int = 10

@export_group("Escalonamento por Nível")
@export var hp_por_nivel: int = 15
@export var ataque_por_nivel: int = 3
