extends SceneTree

## Automated headless unit test suite for AnimaleseParser.

const AnimaleseParser = preload("res://addons/animalese/scripts/core/animalese_parser.gd")
const VoiceToken = preload("res://addons/animalese/scripts/core/voice_token.gd")

func _initialize() -> void:
	print("========================================")
	print("   AnimaleseParser Unit Test Suite")
	print("========================================")
	
	var passed: int = 0
	var total: int = 0
	
	var tests: Array[Callable] = [
		test_empty_string,
		test_english_digraphs,
		test_question_pitch_rise,
		test_exclamation_emphasis,
		test_combined_shock_punctuation,
		test_ellipsis_decrescendo,
		test_tilde_and_dash_elongation,
		test_multilingual_and_emoji,
		test_buffer_reuse
	]
	
	for test in tests:
		total += 1
		print("[TEST %d] %s ..." % [total, test.get_method()])
		test.call()
		passed += 1
		print("  -> PASSED")
	
	print("========================================")
	print(" All %d / %d tests passed successfully! " % [passed, total])
	print("========================================")
	quit(0)


func test_empty_string() -> void:
	var tokens: Array[VoiceToken] = AnimaleseParser.parse("")
	assert(tokens.is_empty(), "Empty string should return empty tokens array")


func test_english_digraphs() -> void:
	var tokens: Array[VoiceToken] = AnimaleseParser.parse("the")
	assert(tokens.size() == 2, "Expected 2 tokens: 'th' and 'e', got %d" % tokens.size())
	assert(tokens[0].phoneme_id == "th", "First token should be digraph 'th'")
	assert(tokens[0].char_index == 0, "First token char_index should be 0")
	assert(tokens[1].phoneme_id == "e", "Second token should be 'e'")
	assert(tokens[1].char_index == 2, "Second token char_index should be 2")


func test_question_pitch_rise() -> void:
	var tokens: Array[VoiceToken] = AnimaleseParser.parse("is it?")
	# tokens: 'i', 's', ' ', 'i', 't', '?'
	var last_phoneme: VoiceToken = null
	var second_last_phoneme: VoiceToken = null
	for k in range(tokens.size() - 1, -1, -1):
		if tokens[k].type == VoiceToken.TokenType.PHONEME:
			if last_phoneme == null:
				last_phoneme = tokens[k]
			elif second_last_phoneme == null:
				second_last_phoneme = tokens[k]
				break
	
	assert(last_phoneme != null and last_phoneme.phoneme_id == "t", "Last phoneme should be 't'")
	assert(is_equal_approx(last_phoneme.pitch_offset, 0.35), "Question last phoneme pitch rise should be 0.35")
	assert(second_last_phoneme != null and is_equal_approx(second_last_phoneme.pitch_offset, 0.15), "Question 2nd last phoneme pitch rise should be 0.15")


func test_exclamation_emphasis() -> void:
	var tokens: Array[VoiceToken] = AnimaleseParser.parse("go!")
	var phoneme: VoiceToken = tokens[1] # 'o'
	assert(phoneme.phoneme_id == "o", "Phoneme should be 'o'")
	assert(is_equal_approx(phoneme.pitch_offset, 0.25), "Exclamation pitch offset should be 0.25")
	assert(is_equal_approx(phoneme.volume_scale, 1.35), "Exclamation volume scale should be 1.35")


func test_combined_shock_punctuation() -> void:
	var tokens: Array[VoiceToken] = AnimaleseParser.parse("what?!")
	var last_phoneme: VoiceToken = tokens[2] # 't' in 'wh', 'a', 't'
	assert(last_phoneme.phoneme_id == "t", "Target phoneme should be 't'")
	assert(is_equal_approx(last_phoneme.pitch_offset, 0.45), "Shock pitch rise should be 0.45")
	assert(is_equal_approx(last_phoneme.volume_scale, 1.40), "Shock volume scale should be 1.40")


func test_ellipsis_decrescendo() -> void:
	var tokens: Array[VoiceToken] = AnimaleseParser.parse("wait...")
	var last_phoneme: VoiceToken = tokens[3] # 't'
	assert(last_phoneme.phoneme_id == "t", "Target phoneme should be 't'")
	assert(is_equal_approx(last_phoneme.volume_scale, 0.6), "Ellipsis last phoneme volume should fade to 0.6")
	assert(is_equal_approx(last_phoneme.pitch_offset, -0.1), "Ellipsis last phoneme pitch should drop -0.1")


func test_tilde_and_dash_elongation() -> void:
	# Tilde test
	var tilde_tokens: Array[VoiceToken] = AnimaleseParser.parse("hi~")
	var tilde_phoneme: VoiceToken = tilde_tokens[1] # 'i'
	assert(is_equal_approx(tilde_phoneme.relative_duration, 1.8), "Tilde should extend duration to 1.8")
	assert(is_equal_approx(tilde_phoneme.pitch_offset, 0.15), "Tilde should raise pitch by 0.15")
	
	# Dash test
	var dash_tokens: Array[VoiceToken] = AnimaleseParser.parse("no-")
	var dash_phoneme: VoiceToken = dash_tokens[1] # 'o'
	assert(is_equal_approx(dash_phoneme.relative_duration, 2.0), "Dash should extend duration to 2.0")


func test_multilingual_and_emoji() -> void:
	var text: String = "你好 🐱!"
	var tokens: Array[VoiceToken] = AnimaleseParser.parse(text)
	
	# '你', '好' -> non-English phonemes
	assert(tokens[0].type == VoiceToken.TokenType.PHONEME and tokens[0].source_char == "你")
	assert(tokens[0].phoneme_id.is_empty(), "Non-English characters should have empty phoneme_id")
	
	assert(tokens[1].type == VoiceToken.TokenType.PHONEME and tokens[1].source_char == "好")
	
	# ' ' -> pause
	assert(tokens[2].type == VoiceToken.TokenType.PAUSE and tokens[2].source_char == " ")
	
	# '🐱' -> emoji silent pause
	assert(tokens[3].type == VoiceToken.TokenType.PAUSE and tokens[3].source_char == "🐱")
	assert(is_equal_approx(tokens[3].relative_duration, 0.5), "Emoji should create a 0.5 duration pause")


func test_buffer_reuse() -> void:
	var buffer: Array[VoiceToken] = []
	var res1: Array[VoiceToken] = AnimaleseParser.parse("abc", buffer)
	assert(res1.size() == 3, "Buffer should have 3 tokens")
	
	var res2: Array[VoiceToken] = AnimaleseParser.parse("de", buffer)
	assert(res2.size() == 2, "Reused buffer should be cleared and have 2 tokens")
	assert(res1 == res2, "Both variables should point to the exact same array instance")
