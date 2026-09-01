extends Node

# ── Variables de pelea ─────────────────────────────────────────────────────
var p1_character: String = "Kung Lao"
var p2_character: String = "Scorpion"
var p1_wins: int = 0
var p2_wins: int = 0
var round_number: int = 1

# ── Configuración de partida (guardable) ───────────────────────────────────
var npc_count_per_team: int = 5   # NPCs por equipo al inicio de ronda

const SAVE_PATH: String = "user://config.cfg"

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	load_config()

func reset_match() -> void:
	p1_wins = 0
	p2_wins = 0
	round_number = 1

# ── Guardado / Carga (formato .cfg tipo INI sin dependencia de texto) ─────────
func save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("fight",  "p1_character", p1_character)
	cfg.set_value("fight",  "p2_character", p2_character)
	cfg.set_value("ciudad", "npc_count",    npc_count_per_team)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("GameManager: no se pudo guardar config (%d)" % err)

func load_config() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		# Primera vez o archivo no existe: generar con valores por defecto
		save_config()
		return
	p1_character       = cfg.get_value("fight",  "p1_character", p1_character)
	p2_character       = cfg.get_value("fight",  "p2_character", p2_character)
	npc_count_per_team = cfg.get_value("ciudad", "npc_count",    npc_count_per_team)
