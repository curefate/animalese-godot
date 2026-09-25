class_name AnimalesePlayer
extends Node

## Core Animalese audio playback and dialogue state machine component.
## Drives procedural speech synthesis and millisecond-accurate typewriter synchronization.

## Emitted whenever a voice token is consumed and played.
## [param token] The VoiceToken data unit being processed.
## [param index] The 0-based token index in the active sequence.
signal token_played(token: VoiceToken, index: int)

## Emitted when the entire speech token sequence has finished playing.
signal play_completed()

@export_group("Configuration")
## Voice profile asset defining character pitch, speed, and audio mappings.
@export var profile: VoiceProfile

## Optional custom audio player (supports AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D).
## If unassigned, an internal AudioStreamPlayer will be automatically created on startup.
@export var audio_player: Node

const AnimaleseParser = preload("res://addons/animalese/scripts/core/animalese_parser.gd")

# Runtime state machine variables
var _tokens: Array[VoiceToken] = []
var _current_index: int = 0
var _timer: float = 0.0
var _speed_multiplier: float = 1.0
var _is_playing: bool = false
var _is_paused: bool = false
var _phoneme_step_counter: int = 0
var _internal_player: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_player()


func _ensure_player() -> void:
	if audio_player == null:
		_internal_player = AudioStreamPlayer.new()
		_internal_player.name = "InternalAudioStreamPlayer"
		add_child(_internal_player)
		audio_player = _internal_player


func _process(delta: float) -> void:
	if not _is_playing or _is_paused or _tokens.is_empty():
		return
	
	# Advance internal timer scaled by speed multiplier
	_timer -= delta * maxf(0.01, _speed_multiplier)
	
	# Clamp maximum time debt to -0.2s to prevent spiral loops during hitches
	_timer = maxf(_timer, -0.2)
	
	var played_audio_this_frame: bool = false
	
	while _timer <= 0.0 and _is_playing:
		if _current_index >= _tokens.size():
			_complete_playback()
			return
		
		var token: VoiceToken = _tokens[_current_index]
		var played := _process_token(token, played_audio_this_frame)
		if played:
			played_audio_this_frame = true
		_current_index += 1


## Parses text into tokens and starts playback using the assigned profile.
## [param text] Dialogue string to pronounce.
## [param profile_override] Optional voice profile to override the default profile.
func play(text: String, profile_override: VoiceProfile = null) -> void:
	_ensure_player()
	if profile_override != null:
		profile = profile_override
	
	var parsed_tokens: Array[VoiceToken] = AnimaleseParser.parse(text)
	play_tokens(parsed_tokens, profile)


## Plays an existing Array of VoiceTokens directly.
## [param tokens] Pre-parsed voice token sequence.
## [param profile_override] Optional voice profile to override the default profile.
func play_tokens(tokens: Array[VoiceToken], profile_override: VoiceProfile = null) -> void:
	stop()
	
	if profile_override != null:
		profile = profile_override
	
	if tokens == null or tokens.is_empty():
		play_completed.emit()
		return
	
	_tokens = tokens
	_current_index = 0
	_timer = 0.0
	_phoneme_step_counter = 0
	_is_playing = true
	_is_paused = false


## Immediately halts playback and resets state.
func stop() -> void:
	_is_playing = false
	_is_paused = false
	_current_index = 0
	_timer = 0.0
	
	if audio_player != null and audio_player.has_method("stop"):
		audio_player.stop()


## Pauses ongoing playback.
func pause() -> void:
	_is_paused = true


## Resumes paused playback.
func resume() -> void:
	_is_paused = false


## Sets the dynamic playback speed multiplier (e.g. 2.0 for fast-forward).
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = maxf(0.1, multiplier)


## Returns whether speech playback is currently active.
func is_playing() -> bool:
	return _is_playing


## Returns whether speech playback is currently paused.
func is_paused() -> bool:
	return _is_paused


## Returns the active speed multiplier.
func get_speed_multiplier() -> float:
	return _speed_multiplier


func _process_token(token: VoiceToken, played_audio_this_frame: bool) -> bool:
	var did_play_audio: bool = false
	
	# 1. Calculate physical duration required for this token
	var base_interval: float = profile.base_interval if profile != null else 0.06
	var speech_rate: float = profile.speech_rate if (profile != null and profile.speech_rate > 0.01) else 1.0
	var duration: float = (base_interval * token.relative_duration) / speech_rate
	_timer += duration
	
	# 2. If it is a phoneme, perform audio output
	if token.type == VoiceToken.TokenType.PHONEME:
		_phoneme_step_counter += 1
		var step: int = maxi(1, profile.phoneme_step) if profile != null else 1
		
		if _phoneme_step_counter % step == 0:
			# Rate-limit audio playback to at most once per frame to prevent distortion
			if not played_audio_this_frame:
				var clip: AudioStream = _find_clip_for_token(token)
				if clip != null and audio_player != null:
					var base_pitch: float = profile.base_pitch if profile != null else 1.0
					var rise_factor: float = profile.question_pitch_rise if profile != null else 0.35
					var jitter_range: float = profile.pitch_jitter if profile != null else 0.08
					var jitter: float = randf_range(-jitter_range, jitter_range)
					
					var final_pitch: float = clampf(base_pitch * (1.0 + token.pitch_offset * rise_factor) + jitter, 0.1, 3.0)
					var base_volume: float = profile.volume if profile != null else 1.0
					var final_linear_vol: float = clampf(base_volume * token.volume_scale, 0.0, 1.0)
					
					audio_player.pitch_scale = final_pitch
					audio_player.volume_db = linear_to_db(final_linear_vol)
					audio_player.stream = clip
					if audio_player.is_inside_tree():
						audio_player.play()
					
					did_play_audio = true
	
	# 3. Emit event for typewriter synchronization
	token_played.emit(token, _current_index)
	return did_play_audio


func _find_clip_for_token(token: VoiceToken) -> AudioStream:
	if profile == null or profile.phoneme_map == null:
		return null
	
	# 1. If explicit phoneme ID exists (e.g. English letter or digraph), look up directly
	if not token.phoneme_id.is_empty():
		var clip: AudioStream = profile.phoneme_map.get_clip(token.phoneme_id)
		if clip != null:
			return clip
	
	# 2. Fallback using character CodePoint for non-English characters
	if not token.source_char.is_empty():
		var code_point: int = token.source_char.unicode_at(0)
		return profile.phoneme_map.get_fallback_clip(code_point)
	
	return null


func _complete_playback() -> void:
	_is_playing = false
	_current_index = 0
	_timer = 0.0
	play_completed.emit()
