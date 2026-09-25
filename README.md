# Animalese for Godot 4

A lightweight, zero-dependency, procedural "Animalese" speech synthesizer for Godot 4 dialogue systems. Converts raw text into rhythmic character gibberish voice lines in real time, with expressive intonations and millisecond-accurate UI typewriter synchronization.

> **Note:** This project is a full-featured, zero-dependency GDScript port to **Godot 4** based on the original Unity package [animalese-unity](https://github.com/curefate/Animalese-Unity).

---

## Features

- **Decoupled Architecture**: Zero-dependency static `AnimaleseParser` paired with a dedicated `AnimalesePlayer` node state machine.
- **Expressive Prosody & Punctuation**: Procedural pitch inflection and rhythmic pauses for questions (`?`), exclamations (`!`, `?!`), decrescendo (`...`), and elongations (`-`, `~`).
- **Character Voice Profiles (`VoiceProfile`)**: Tweakable resources (`.tres`) for base pitch, randomness (jitter), speech rate, articulation steps, and audio filters.
- **Multilingual & Emoji Ready**: Greedy English digraphs (`ch`, `sh`, etc.), deterministic hash fallback for CJK characters, and safe Emoji stepping.
- **Flawless Typewriter Sync**: Advances `RichTextLabel.visible_characters` in exact lockstep with audio, seamlessly bypassing BBCode tags without layout reflow jitter.
- **Flexible Audio Routing**: Zero-config default UI playback, with full support for `AudioStreamPlayer2D` / `AudioStreamPlayer3D` spatial audio.
- **Hitch & Distortion Protection**: Single-frame playback rate-limiting and time-debt clamping prevent audio stacking during framerate drops or fast-forwarding.

---

## Installation

~~### Method 1: Via Godot Asset Library (AssetLib)~~
~~1. Open your project in Godot 4.
2. Click on the **AssetLib** tab at the top of the editor.
3. Search for **Animalese** and click **Download**.
4. In the install dialog, ensure the `addons/animalese/` folder is checked, then click **Install**.
5. Go to **Project** > **Project Settings** > **Plugins** and enable **Animalese**.~~
(Not yet)

### Method 2: Manual Installation
1. Clone or download this repository.
2. Copy the `addons/animalese/` folder into your Godot project's `res://addons/` directory:
   ```text
   res://addons/animalese/
   ```
3. In the Godot editor, navigate to **Project** > **Project Settings** > **Plugins** and check **Enable** next to **Animalese**.

---

## Quick Start

### 1. Basic Playback via Code

Add an `AnimalesePlayer` node to your scene (available in the "Create New Node" dialog), assign a `VoiceProfile` resource (or use the included `default_profile.tres`), and call:

```gdscript
extends Node

@onready var player: AnimalesePlayer = $AnimalesePlayer

func _ready() -> void:
    # Speaks text using the currently assigned player.profile
    player.play("Hello, world! Do you like this island?")

func stop_speech() -> void:
    player.stop()
```

### 2. Synchronizing with RichTextLabel Typewriter

To display dialogue text character-by-character in exact sync with procedural speech:

```gdscript
extends Control

@export var dialogue_label: RichTextLabel
@export var player: AnimalesePlayer

var _current_tokens: Array[VoiceToken] = []

func speak_dialogue(text_with_bbcode: String) -> void:
    # 1. Set full text upfront but hide all characters initially to avoid layout recalculation jitter
    dialogue_label.text = text_with_bbcode
    dialogue_label.visible_characters = 0
    
    # 2. Extract plain text stripped of BBCode tags for accurate phoneme generation
    var plain_text: String = dialogue_label.get_parsed_text()
    _current_tokens = AnimaleseParser.parse(plain_text)
    
    if _current_tokens.is_empty():
        dialogue_label.visible_characters = -1
        return
    
    # 3. Connect signals
    if not player.token_played.is_connected(_on_token_played):
        player.token_played.connect(_on_token_played)
        player.play_completed.connect(_on_play_completed)
    
    # 4. Start playback
    player.play_tokens(_current_tokens)

func _on_token_played(_token: VoiceToken, index: int) -> void:
    var total_chars: int = dialogue_label.get_total_character_count()
    var visible_count: int = total_chars
    
    # Advance to the start of the next token, accurately covering multi-character tokens and pauses
    if index + 1 < _current_tokens.size():
        visible_count = _current_tokens[index + 1].char_index
        
    dialogue_label.visible_characters = clampi(visible_count, 0, total_chars)

func _on_play_completed() -> void:
    dialogue_label.visible_characters = -1
```

### 3. Positional 2D / 3D Audio

To give characters spatialized voices in 2D or 3D worlds, simply attach an `AudioStreamPlayer2D` or `AudioStreamPlayer3D` node and assign it to the player's `audio_player` property:

```gdscript
@onready var player: AnimalesePlayer = $AnimalesePlayer
@onready var audio_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
    player.audio_player = audio_2d
    player.play("Hey there, traveler!")
```

---

## Interactive Demo

This repository includes a ready-to-run interactive demo scene at `examples/example_scene.tscn`:
- An editable dialogue input field.
- **Speak** and **Skip** buttons.
- Styled `RichTextLabel` with BBCode support.
- Pre-configured `default_profile.tres` and `default_phoneme_map.tres` with 32 phoneme sound samples.

To test it, open the project in Godot and press **F6** while viewing `examples/example_scene.tscn`.

---

## Unit & Integration Tests

The project includes headless test suites verifying parsing, player lifecycle, and typewriter sync:

```powershell
godot --headless -s tests/test_parser.gd
godot --headless -s tests/test_player.gd
godot --headless -s tests/test_typewriter_integration.gd
```

---

## Credits & Attribution

- **Original Unity Package**: Directly ported and enhanced from [animalese-unity](https://github.com/curefate/Animalese-Unity).
- **Phoneme Sound Samples**: Sourced from [ztc0611/Ren-py-Animalese](https://github.com/ztc0611/Ren-py-Animalese), which were originally based on work by Henry and made available for free use and modification.

---

## License

MIT License. See [LICENSE](LICENSE.md) for details.
