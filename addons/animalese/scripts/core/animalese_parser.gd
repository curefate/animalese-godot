class_name AnimaleseParser
extends RefCounted

## Pure static text parser for Animalese speech synthesis.
## Converts raw text into a normalized array of VoiceTokens with expressive prosody and timing.

# Common English digraphs matched in greedy order
const DIGRAPHS: Array[String] = ["ch", "sh", "th", "wh", "ph"]

# Punctuation characters ignored during speech without pauses
const IGNORED_PUNCTUATION: Array[String] = [
	"\"", "'", "“", "”", "‘", "’",
	"(", ")", "（", "）", "【", "】",
	"[", "]", "{", "}", "<", ">"
]


## Parses input text into an Array of VoiceTokens.
## If [param results] is provided, it is cleared and reused to avoid memory allocations.
static func parse(text: String, results: Array[VoiceToken] = []) -> Array[VoiceToken]:
	var tokens: Array[VoiceToken] = results
	tokens.clear()
	
	if text.is_empty():
		return tokens
	
	var length: int = text.length()
	var i: int = 0
	
	while i < length:
		var c: String = text[i]
		
		# 1. Ellipsis handling (... or ……)
		if c == "…" or (c == "." and i + 2 < length and text[i + 1] == "." and text[i + 2] == "."):
			_apply_decrescendo(tokens)
			tokens.append(VoiceToken.create_pause(i, c, 5.0))
			var skip_char: String = c
			while i < length and text[i] == skip_char:
				i += 1
			continue
		
		# 2. Question mark and Exclamation mark (single or combined ?! / !?)
		if c in ["?", "？", "!", "！"]:
			var is_question: bool = (c == "?" or c == "？")
			var is_exclamation: bool = (c == "!" or c == "！")
			var is_combined: bool = false
			
			if i + 1 < length:
				var next_char: String = text[i + 1]
				if (is_question and (next_char == "!" or next_char == "！")) or \
				   (is_exclamation and (next_char == "?" or next_char == "？")):
					is_combined = true
			
			if is_combined:
				_apply_punctuation_emphasis(tokens, 0.45, 0.25, 1.4, 1.2)
				tokens.append(VoiceToken.create_pause(i, c, 4.0))
				i += 2
				while i < length and text[i] in ["?", "？", "!", "！"]:
					i += 1
				continue
			
			if is_question:
				_apply_punctuation_emphasis(tokens, 0.35, 0.15, 1.0, 1.0)
				tokens.append(VoiceToken.create_pause(i, c, 3.0))
				while i < length and text[i] in ["?", "？"]:
					i += 1
				continue
			
			# Single exclamation
			_apply_punctuation_emphasis(tokens, 0.25, 0.10, 1.35, 1.15)
			tokens.append(VoiceToken.create_pause(i, c, 4.0))
			while i < length and text[i] in ["!", "！"]:
				i += 1
			continue
		
		# 3. Dash, hyphen, or Japanese vowel extender (-, —, ー) -> extends last phoneme
		if c in ["-", "—", "ー"]:
			_extend_last_phoneme_duration(tokens, 1.0)
			tokens.append(VoiceToken.create_pause(i, c, 0.2))
			i += 1
			continue
		
		# 4. Tilde (~, ～) -> playful/casual tail inflection
		if c in ["~", "～"]:
			_extend_last_phoneme_duration(tokens, 0.8)
			_apply_pitch_offset_to_last_phoneme(tokens, 0.15)
			tokens.append(VoiceToken.create_pause(i, c, 0.2))
			i += 1
			continue
		
		# 5. Regular pauses and punctuations
		if c in [",", "，", "、"]:
			tokens.append(VoiceToken.create_pause(i, c, 2.0))
			i += 1
			continue
		
		if c in [".", "。", ";", "；", ":", "："]:
			tokens.append(VoiceToken.create_pause(i, c, 4.0))
			i += 1
			continue
		
		if c in [" ", "\t", "\n", "\r"]:
			tokens.append(VoiceToken.create_pause(i, c, 0.5))
			i += 1
			continue
		
		# Ignore non-vocal enclosing symbols (quotes, brackets)
		if c in IGNORED_PUNCTUATION:
			i += 1
			continue
		
		# 6. Greedy English digraph matching (ch, sh, th, wh, ph)
		if i + 1 < length and _is_ascii_letter(c) and _is_ascii_letter(text[i + 1]):
			var two_chars: String = (c + text[i + 1]).to_lower()
			if two_chars in DIGRAPHS:
				tokens.append(VoiceToken.create_phoneme(two_chars, i, c, 0.0, 1.0))
				i += 2
				continue
		
		# 7. Single ASCII letter ('a' ~ 'z')
		if _is_ascii_letter(c):
			tokens.append(VoiceToken.create_phoneme(c.to_lower(), i, c, 0.0, 1.0))
			i += 1
			continue
		
		# 8. Emoji or supplementary plane symbols: silent pause to advance typewriter
		var code: int = c.unicode_at(0)
		if _is_emoji_or_symbol(code):
			tokens.append(VoiceToken.create_pause(i, c, 0.5))
			i += 1
			continue
		
		# 9. Non-English characters (Chinese, Japanese, etc.): empty phoneme ID for deterministic hash fallback
		tokens.append(VoiceToken.create_phoneme("", i, c, 0.0, 1.0))
		i += 1
	
	return tokens


static func _is_ascii_letter(c: String) -> bool:
	if c.is_empty():
		return false
	var code: int = c.unicode_at(0)
	return (code >= 97 and code <= 122) or (code >= 65 and code <= 90)


static func _is_emoji_or_symbol(code: int) -> bool:
	# Supplementary planes (Emoji e.g. 🐱, 🎉) or Miscellaneous Symbols (0x2600..0x27BF)
	return code >= 0x10000 or (code >= 0x2600 and code <= 0x27BF)


## Extends playback duration of the most recent active phoneme token.
static func _extend_last_phoneme_duration(tokens: Array[VoiceToken], extend_duration: float) -> void:
	for k in range(tokens.size() - 1, -1, -1):
		if tokens[k].type == VoiceToken.TokenType.PHONEME:
			tokens[k].relative_duration += extend_duration
			break


## Applies pitch offset to the most recent active phoneme token.
static func _apply_pitch_offset_to_last_phoneme(tokens: Array[VoiceToken], pitch_offset: float) -> void:
	for k in range(tokens.size() - 1, -1, -1):
		if tokens[k].type == VoiceToken.TokenType.PHONEME:
			tokens[k].pitch_offset += pitch_offset
			break


## Retroactively emphasizes ending phonemes for questions, exclamations, or combined punctuation.
static func _apply_punctuation_emphasis(
	tokens: Array[VoiceToken],
	pitch_rise_last: float,
	pitch_rise_second: float,
	volume_scale_last: float,
	volume_scale_second: float
) -> void:
	var phonemes_found: int = 0
	var last_index: int = -1
	var second_last_index: int = -1
	
	for k in range(tokens.size() - 1, -1, -1):
		var token: VoiceToken = tokens[k]
		if token.type == VoiceToken.TokenType.PAUSE and token.relative_duration >= 3.0:
			break
		
		if token.type == VoiceToken.TokenType.PHONEME:
			if phonemes_found == 0:
				last_index = k
				phonemes_found += 1
			elif phonemes_found == 1:
				second_last_index = k
				phonemes_found += 1
				break
	
	if second_last_index != -1:
		tokens[second_last_index].pitch_offset += pitch_rise_second
		tokens[second_last_index].volume_scale = maxf(tokens[second_last_index].volume_scale, volume_scale_second)
	
	if last_index != -1:
		tokens[last_index].pitch_offset += pitch_rise_last
		tokens[last_index].volume_scale = maxf(tokens[last_index].volume_scale, volume_scale_last)


## Applies decrescendo (volume fade and slight pitch drop) to preceding phonemes before an ellipsis.
static func _apply_decrescendo(tokens: Array[VoiceToken]) -> void:
	var phonemes_found: int = 0
	for k in range(tokens.size() - 1, -1, -1):
		var token: VoiceToken = tokens[k]
		if token.type == VoiceToken.TokenType.PAUSE and token.relative_duration >= 3.0:
			break
		
		if token.type == VoiceToken.TokenType.PHONEME:
			if phonemes_found == 0:
				token.volume_scale = 0.6
				token.pitch_offset -= 0.1
				phonemes_found += 1
			elif phonemes_found == 1:
				token.volume_scale = 0.8
				break
