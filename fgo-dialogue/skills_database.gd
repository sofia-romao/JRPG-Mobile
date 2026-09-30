# SkillDatabase.gd
extends Node

var skills: Dictionary = {}

# 🔒 Escreva aqui as strings com os IDs das habilidades que os inimigos têm no EnemyData.
# O caminho aponta para o arquivo .tres original (o Godot cuida do resto na Web!)
const SKILL_PATHS: Array[String] = [
	"res://resources/skills/agi.tres",
	"res://resources/skills/bufu.tres",
	"res://resources/skills/dia.tres",
	"res://resources/skills/rush.tres",
	"res://resources/skills/tarukaja.tres"
]

func _ready() -> void:
	_load_skills_statically()

func _load_skills_statically() -> void:
	skills.clear()
	
	for path in SKILL_PATHS:
		# O load direto do Godot resolve os remapeamentos internos na Web de forma nativa!
		var data = load(path) as SkillData
		if data:
			skills[data.id] = data
			print("🔮 [SkillDatabase] Skill loaded statically: %s (%s)" % [data.name, data.id])
			
	print("📦 [SkillDatabase] Total skills loaded securely: ", skills.size())

func get_skill(skill_id: String) -> SkillData:
	return skills.get(skill_id, null)
