extends SceneTree

## Automated headless integration test suite for Example Typewriter and RichTextLabel synchronization.

const AnimaleseExampleTypewriter = preload("res://examples/example_typewriter.gd")

func _initialize() -> void:
	print("========================================")
	print("   Typewriter Integration Test Suite")
	print("========================================")
	
	test_bbcode_stripping_and_stepping()
	test_skip_functionality()
	
	print("========================================")
	print(" All Integration tests passed! ")
	print("========================================")
	quit(0)


func test_bbcode_stripping_and_stepping() -> void:
	print("[TEST] BBCode tag stripping and typewriter stepping...")
	var scene_res: PackedScene = load("res://examples/example_scene.tscn")
	assert(scene_res != null, "example_scene.tscn should load")
	
	var scene: AnimaleseExampleTypewriter = scene_res.instantiate()
	root.add_child(scene)
	
	var label: RichTextLabel = scene.output_label
	var player: AnimalesePlayer = scene.animalese_player
	assert(label != null and player != null, "Scene node references must be bound")
	
	# Dialogue containing BBCode tags
	var dialogue: String = "Hi [b]Bob[/b]! Welcome to [color=green]town[/color]~"
	scene.play_dialogue(dialogue)
	
	# Initial state: full text assigned upfront, but 0 characters visible
	assert(label.text == dialogue, "Label text should contain full BBCode string")
	assert(label.visible_characters == 0, "Initial visible_characters should be 0")
	assert(player.is_playing(), "Player should be playing")
	
	# Total parsed characters (stripped of BBCode tags)
	var expected_plain: String = label.get_parsed_text()
	var total_chars: int = label.get_total_character_count()
	assert(expected_plain == "Hi Bob! Welcome to town~", "get_parsed_text() should strip all tags")
	assert(total_chars == expected_plain.length(), "Total characters should match plain text length")
	
	# Step through multiple frames and observe typewriter progression
	var previous_visible: int = 0
	var max_iterations: int = 400
	while player.is_playing() and max_iterations > 0:
		player._process(0.016)
		# Visible characters should monotonically increase or remain equal
		assert(label.visible_characters >= previous_visible or label.visible_characters == -1, "Visible characters should never regress")
		if label.visible_characters != -1:
			previous_visible = label.visible_characters
		max_iterations -= 1
	
	assert(not player.is_playing(), "Player should complete speech")
	assert(label.visible_characters == -1 or label.visible_characters == total_chars, "All characters should be revealed at completion")
	
	scene.queue_free()
	print("  -> PASSED")


func test_skip_functionality() -> void:
	print("[TEST] Skip button instantly reveals text and halts audio...")
	var scene_res: PackedScene = load("res://examples/example_scene.tscn")
	var scene: AnimaleseExampleTypewriter = scene_res.instantiate()
	root.add_child(scene)
	
	var label: RichTextLabel = scene.output_label
	var player: AnimalesePlayer = scene.animalese_player
	
	scene.play_dialogue("A very long sentence that will be interrupted halfway through...")
	assert(player.is_playing())
	assert(label.visible_characters == 0)
	
	# Advance a few ticks
	player._process(0.016)
	player._process(0.016)
	
	# Call skip
	scene.skip()
	assert(not player.is_playing(), "Playback should halt immediately on skip")
	assert(label.visible_characters == -1, "All characters should be visible (-1) on skip")
	
	scene.queue_free()
	print("  -> PASSED")
