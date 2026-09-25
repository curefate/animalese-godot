extends SceneTree

## Automated headless unit test suite for AnimalesePlayer node.

const AnimalesePlayer = preload("res://addons/animalese/scripts/nodes/animalese_player.gd")
const VoiceProfile = preload("res://addons/animalese/scripts/resources/voice_profile.gd")
const VoiceToken = preload("res://addons/animalese/scripts/core/voice_token.gd")

func _initialize() -> void:
	print("========================================")
	print("   AnimalesePlayer Unit Test Suite")
	print("========================================")
	
	test_initialization()
	test_playback_lifecycle()
	test_pause_resume_stop()
	test_custom_audio_player_binding()
	
	print("========================================")
	print(" All Player tests passed successfully! ")
	print("========================================")
	quit(0)


func test_initialization() -> void:
	print("[TEST] Initialization and default internal player...")
	var player := AnimalesePlayer.new()
	root.add_child(player)
	player._ready()
	
	assert(player.audio_player != null, "Default AudioStreamPlayer should be auto-created")
	assert(player.audio_player is AudioStreamPlayer, "Auto-created player should be AudioStreamPlayer")
	assert(not player.is_playing(), "Player should not be playing initially")
	assert(not player.is_paused(), "Player should not be paused initially")
	
	player.queue_free()
	print("  -> PASSED")


func test_playback_lifecycle() -> void:
	print("[TEST] Playback lifecycle and signal emission...")
	var player := AnimalesePlayer.new()
	root.add_child(player)
	player._ready()
	
	var default_profile: VoiceProfile = load("res://addons/animalese/assets/default_profile.tres")
	assert(default_profile != null, "Default profile should load")
	player.profile = default_profile
	
	var stats := {
		"count": 0,
		"completed": false
	}
	
	player.token_played.connect(func(_token: VoiceToken, _idx: int): stats["count"] += 1)
	player.play_completed.connect(func(): stats["completed"] = true)
	
	player.play("hi")
	assert(player.is_playing(), "Player should be playing after play()")
	
	# Simulate frame ticks through _process until completion
	var max_iterations: int = 200
	while player.is_playing() and max_iterations > 0:
		player._process(0.016)
		max_iterations -= 1
	
	assert(stats["count"] >= 2, "Expected at least 2 tokens played for 'hi', got %d" % stats["count"])
	assert(stats["completed"], "play_completed signal should have fired")
	assert(not player.is_playing(), "Player should have finished playing")
	
	player.queue_free()
	print("  -> PASSED")


func test_pause_resume_stop() -> void:
	print("[TEST] Pause, resume, and stop controls...")
	var player := AnimalesePlayer.new()
	root.add_child(player)
	
	player.profile = load("res://addons/animalese/assets/default_profile.tres")
	player.play("hello world, how are you doing?")
	assert(player.is_playing())
	
	player.pause()
	assert(player.is_paused(), "Player should be paused")
	
	# While paused, advancing frames should not advance speech
	var initial_index: int = player._current_index
	player._process(0.1)
	assert(player._current_index == initial_index, "Paused player should not advance tokens")
	
	player.resume()
	assert(not player.is_paused(), "Player should be resumed")
	
	player.stop()
	assert(not player.is_playing(), "Player should be stopped")
	assert(not player.is_paused(), "Stop should reset pause state")
	
	player.queue_free()
	print("  -> PASSED")


func test_custom_audio_player_binding() -> void:
	print("[TEST] Custom external AudioStreamPlayer binding...")
	var player := AnimalesePlayer.new()
	var custom_audio := AudioStreamPlayer.new()
	custom_audio.name = "MyCustomPlayer"
	root.add_child(custom_audio)
	
	player.audio_player = custom_audio
	root.add_child(player)
	
	assert(player.audio_player == custom_audio, "Player should bind to external custom audio player")
	
	player.queue_free()
	custom_audio.queue_free()
	print("  -> PASSED")
