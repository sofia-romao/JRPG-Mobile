# AudioManager.gd
extends Node

const POOL_SIZE: int = 8
var _sfx_pool: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer

func _ready() -> void:
	# 1. Instantiates the SFX pool channels
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		add_child(player)
		_sfx_pool.append(player)
		
	# 2. Instantiates the dedicated BGM channel
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)

## Plays a sound effect with a subtle random pitch variation to prevent repetition
func play_sfx(stream: AudioStream) -> void:
	if not stream:
		return # Total safety check. If the resource is null, do nothing!
		
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = randf_range(0.92, 1.08) # 🎲 The organic feel magic!
			player.play()
			return
			
	# Fallback: If all channels are busy, override the first one
	var fallback_player = _sfx_pool[0]
	fallback_player.stream = stream
	fallback_player.pitch_scale = randf_range(0.92, 1.08)
	fallback_player.play()

## Plays background music with a smooth fade cross-transition
func play_bgm(stream: AudioStream, fade_time: float = 0.5) -> void:
	if not stream:
		return # Safety check
		
	# Prevent restarting the exact same track if it's already playing
	if _bgm_player.playing and _bgm_player.stream == stream:
		return
		
	# If something is playing, fade it out first, then swap and fade in
	if _bgm_player.playing:
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_time)
		await fade_out_tween.finished
		
	# Prepare and start the new track silently
	_bgm_player.stream = stream
	_bgm_player.volume_db = -80.0
	_bgm_player.play()
	
	# Fade the new track up to full volume (0 dB)
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(_bgm_player, "volume_db", 0.0, fade_time)

## Stops the current music smoothly
func stop_bgm(fade_time: float = 0.5) -> void:
	if not _bgm_player.playing:
		return
		
	var fade_out_tween = create_tween()
	fade_out_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_time)
	await fade_out_tween.finished
	_bgm_player.stop()
