class_name HeroData
extends Resource

@export_group("Identity & Visuals")
@export var id: String = ""
@export var character_name: String = ""
@export var theme_color: Color = Color.WHITE
@export var avatar_icon: Texture2D

@export_group("Base Stats (Level 1)")
@export var base_hp: int = 100
@export var base_mp: int = 20
@export var base_attack: int = 10
@export var base_speed: int = 5

@export_group("Level Scaling")
@export var hp_per_level: int = 15
@export var mp_per_level: int = 3
@export var attack_per_level: int = 2
@export var speed_per_level: int = 1

@export_group("Elemental Resistances")
# SMT System: 1.0 = Normal | 0.5 = Resist | 2.0 = Weakness
@export var res_fire: float = 1.0   # Agi
@export var res_ice: float = 1.0    # Bufu
@export var res_elec: float = 1.0   # Zio
@export var res_physical: float = 1.0

@export_group("Skills")
@export var skills_by_level: Dictionary = {}

# --- Calculation Functions ---
func get_max_hp(level: int) -> int: return base_hp + (hp_per_level * (level - 1))
func get_max_mp(level: int) -> int: return base_mp + (mp_per_level * (level - 1))
func get_attack(level: int) -> int: return base_attack + (attack_per_level * (level - 1))
func get_speed(level: int) -> int: return base_speed + (speed_per_level * (level - 1))
func get_skills_up_to_level(current_level: int) -> Array[String]:
	var unlocked_skills: Array[String] = []
	
	for level_key in skills_by_level.keys():
		if int(level_key) <= current_level:
			unlocked_skills.append_array(skills_by_level[level_key])
			
	return unlocked_skills
