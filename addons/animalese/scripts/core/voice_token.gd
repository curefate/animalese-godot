class_name VoiceToken
extends RefCounted

## VoiceToken represents a single parsed phoneme or pause unit with timing and prosody data.

## Voice token type: Phoneme sound or Pause duration.
enum TokenType {
	PHONEME,
	PAUSE
}

## Core token fields
var type: TokenType = TokenType.PHONEME
var phoneme_id: String = ""
var pitch_offset: float = 0.0
var relative_duration: float = 1.0
var volume_scale: float = 1.0
var char_index: int = 0
var source_char: String = ""


## Constructor
func _init(
	p_type: TokenType = TokenType.PHONEME,
	p_phoneme_id: String = "",
	p_pitch_offset: float = 0.0,
	p_relative_duration: float = 1.0,
	p_volume_scale: float = 1.0,
	p_char_index: int = 0,
	p_source_char: String = ""
) -> void:
	type = p_type
	phoneme_id = p_phoneme_id
	pitch_offset = p_pitch_offset
	relative_duration = p_relative_duration
	volume_scale = p_volume_scale
	char_index = p_char_index
	source_char = p_source_char


## Static factory method to create a phoneme token.
static func create_phoneme(
	p_phoneme_id: String,
	p_char_index: int,
	p_source_char: String,
	p_pitch_offset: float = 0.0,
	p_relative_duration: float = 1.0,
	p_volume_scale: float = 1.0
) -> VoiceToken:
	return VoiceToken.new(
		TokenType.PHONEME,
		p_phoneme_id,
		p_pitch_offset,
		p_relative_duration,
		p_volume_scale,
		p_char_index,
		p_source_char
	)


## Static factory method to create a pause token.
static func create_pause(
	p_char_index: int,
	p_source_char: String,
	p_relative_duration: float
) -> VoiceToken:
	return VoiceToken.new(
		TokenType.PAUSE,
		"",
		0.0,
		p_relative_duration,
		1.0,
		p_char_index,
		p_source_char
	)


## Formatted string representation for debugging and logging.
func _to_string() -> String:
	if type == TokenType.PHONEME:
		return "[Phoneme: '%s', Char: '%s', Pitch: %.2f, Vol: %.2f, RelDur: %.2f]" % [
			phoneme_id, source_char, pitch_offset, volume_scale, relative_duration
		]
	else:
		return "[Pause: '%s', RelDur: %.2f]" % [source_char, relative_duration]