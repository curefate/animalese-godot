class_name VoiceProfile
extends Resource

## Voice profile configuration asset for Animalese characters.
## Defines pitch, jitter, rate, articulation step, and optional filters.

@export_group("Phoneme Asset Mapping")
## Phoneme map asset used by this character.
@export var phoneme_map: PhonemeMap

@export_group("Pitch & Volume")
## Base volume scale (0.0 ~ 2.0).
@export_range(0.0, 2.0, 0.05) var volume: float = 1.0

## Base pitch of the character voice (0.5 = deep/giant, 1.0 = normal, 1.5+ = high/childish).
@export_range(0.5, 2.5, 0.01) var base_pitch: float = 1.0

## Random pitch jitter range (0 = flat/robotic, higher values sound more energetic).
@export_range(0.0, 0.5, 0.01) var pitch_jitter: float = 0.08

## Pitch rise amount applied at the end of questions.
@export_range(0.0, 1.0, 0.05) var question_pitch_rise: float = 0.35

@export_group("Timing & Speed")
## Speech rate multiplier (higher values mean faster speech).
@export_range(0.2, 3.0, 0.1) var speech_rate: float = 1.0

## Base interval in seconds between consecutive phonemes.
@export_range(0.01, 0.2, 0.005) var base_interval: float = 0.06

@export_group("Articulation")
## Phoneme playback step: 1 = play every phoneme, 2 = play every 2nd phoneme.
@export_range(1, 4, 1) var phoneme_step: int = 1

@export_group("Low-Pass Filter")
## Whether to enable low-pass filter effect.
@export var enable_low_pass: bool = false
## Cutoff frequency for low-pass filter in Hz.
@export_range(10.0, 22000.0, 100.0) var low_pass_cutoff: float = 5000.0
## Resonance (Q factor) for low-pass filter.
@export_range(1.0, 10.0, 0.1) var low_pass_resonance: float = 1.0

@export_group("High-Pass Filter")
## Whether to enable high-pass filter effect.
@export var enable_high_pass: bool = false
## Cutoff frequency for high-pass filter in Hz.
@export_range(10.0, 22000.0, 100.0) var high_pass_cutoff: float = 1000.0
## Resonance (Q factor) for high-pass filter.
@export_range(1.0, 10.0, 0.1) var high_pass_resonance: float = 1.0
