class_name AnimaleseExampleTypewriter
extends Control

## Example typewriter controller demonstrating synchronized Animalese speech with RichTextLabel.
## Bypasses BBCode formatting tags for speech synthesis to maintain exact character stepping.

@export_group("UI Components")
## The RichTextLabel used to display typewriter text.
@export var output_label: RichTextLabel

## The LineEdit input field providing dialogue text.
@export var input_field: LineEdit

## Button to trigger playback.
@export var play_button: Button

## Button to skip typewriter effect immediately.
@export var skip_button: Button

@export_group("Animalese Components")
## The AnimalesePlayer node responsible for procedural speech.
@export var animalese_player: AnimalesePlayer

var _current_tokens: Array[VoiceToken] = []
var _is_listening: bool = false


func _ready() -> void:
	if play_button != null:
		play_button.pressed.connect(_on_play_button_pressed)
	if skip_button != null:
		skip_button.pressed.connect(skip)


func _exit_tree() -> void:
	_unbind_player_events()


## Starts synchronized typewriter dialogue for the specified text.
## [param text] Can contain BBCode tags (e.g. "[b]Hello[/b] [color=green]world[/color]!").
func play_dialogue(text: String) -> void:
	if output_label == null or animalese_player == null:
		push_warning("[Typewriter] Missing output_label or animalese_player reference!")
		return
	
	stop_playback()
	
	if text.is_empty():
		output_label.text = ""
		return
	
	# 1. Set full text upfront and hide all characters initially to prevent layout reflow jitter
	output_label.text = text
	output_label.visible_characters = 0
	
	# 2. Extract plain text stripped of BBCode tags for accurate speech token parsing
	var plain_text: String = output_label.get_parsed_text()
	_current_tokens = AnimaleseParser.parse(plain_text)
	
	if _current_tokens.is_empty():
		output_label.visible_characters = -1
		return
	
	# 3. Subscribe to Player events for synchronous character stepping
	_bind_player_events()
	
	# 4. Start speech playback
	animalese_player.play_tokens(_current_tokens)


## Instantly reveals all characters and stops audio playback.
func skip() -> void:
	stop_playback()
	if output_label != null:
		output_label.visible_characters = -1


## Halts playback and cleans up event subscriptions.
func stop_playback() -> void:
	_unbind_player_events()
	if animalese_player != null and animalese_player.is_playing():
		animalese_player.stop()


func _on_play_button_pressed() -> void:
	if input_field != null:
		play_dialogue(input_field.text)


func _bind_player_events() -> void:
	if animalese_player != null and not _is_listening:
		animalese_player.token_played.connect(_on_token_played)
		animalese_player.play_completed.connect(_on_play_completed)
		_is_listening = true


func _unbind_player_events() -> void:
	if animalese_player != null and _is_listening:
		animalese_player.token_played.disconnect(_on_token_played)
		animalese_player.play_completed.disconnect(_on_play_completed)
		_is_listening = false


func _on_token_played(_token: VoiceToken, token_index: int) -> void:
	if output_label == null:
		return
	
	var total_chars: int = output_label.get_total_character_count()
	var visible_count: int = 0
	
	# Advance visible characters to the beginning of the next token
	if token_index + 1 < _current_tokens.size():
		visible_count = _current_tokens[token_index + 1].char_index
	else:
		visible_count = total_chars
	
	output_label.visible_characters = clampi(visible_count, 0, total_chars)


func _on_play_completed() -> void:
	_unbind_player_events()
	if output_label != null:
		output_label.visible_characters = -1
