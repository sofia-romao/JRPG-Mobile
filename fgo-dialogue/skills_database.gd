# SkillDatabase.gd (Configurar como Autoload)
extends Node

# Dicionário que vai guardar as magias indexadas por ID: {"agi_01": SkillData}
var skills: Dictionary = {}

func _ready() -> void:
	_load_skills_from_folder()

func _load_skills_from_folder() -> void:
	var folder_path = "res://resources/skills/"
	var dir = DirAccess.open(folder_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = folder_path + file_name
				var data = load(full_path) as SkillData
				if data:
					skills[data.id] = data
					print("🔮 [SkillDatabase] Magia carregada: %s (%s)" % [data.name, data.id])
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("[SkillDatabase] Pasta de magias não encontrada ou vazia.")

## Função para buscar a magia pelo ID de texto
func get_skill(skill_id: String) -> SkillData:
	return skills.get(skill_id, null)
