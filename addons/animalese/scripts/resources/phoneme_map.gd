class_name PhonemeMap
extends Resource

## Phoneme audio mapping asset (PhonemeMap).
## Maps phoneme identifiers (e.g. "a", "ch", "th") to AudioStream assets,
## and provides deterministic hash-modulo fallback clips for non-English Unicode characters.

@export_group("Phoneme Mappings")
## Dictionary mapping phoneme IDs (lowercase) to AudioStream resources.
@export var entries: Dictionary[String, AudioStream] = {}:
	set(value):
		entries = value
		_invalidate_cache()

# Internal runtime cache: ordered list of valid phoneme keys for fast modulo lookup
var _cached_valid_keys: Array[String] = []
var _is_cache_dirty: bool = true


## Attempts to retrieve the AudioStream for the specified phoneme ID.
## Returns null if the phoneme is not found or the ID is empty.
func get_clip(phoneme_id: String) -> AudioStream:
	if phoneme_id.is_empty():
		return null
	
	_ensure_cache()
	var key: String = phoneme_id.strip_edges().to_lower()
	return entries.get(key, null)


## Deterministic fallback retrieval using character CodePoint modulo.
## Used for non-English characters (Chinese, Japanese, etc.) to produce consistent gibberish voices.
func get_fallback_clip(code_point: int) -> AudioStream:
	_ensure_cache()
	if _cached_valid_keys.is_empty():
		return null
	
	var index: int = absi(code_point) % _cached_valid_keys.size()
	var fallback_key: String = _cached_valid_keys[index]
	return entries.get(fallback_key, null)


## Returns the number of currently available valid phonemes.
func get_available_count() -> int:
	_ensure_cache()
	return _cached_valid_keys.size()


## Invalidates the internal cache.
func _invalidate_cache() -> void:
	_is_cache_dirty = true


## Ensures the internal runtime lookup cache is built and sorted.
func _ensure_cache() -> void:
	if not _is_cache_dirty:
		return
	
	_cached_valid_keys.clear()
	for key in entries.keys():
		if key is String and not key.is_empty() and entries[key] != null:
			_cached_valid_keys.append(key.to_lower())
	
	_cached_valid_keys.sort()
	_is_cache_dirty = false


## Convenience helper: automatically loads and populates all audio files from a directory.
## [param dir_path] E.g. "res://addons/animalese/assets/sounds/"
func populate_from_folder(dir_path: String) -> void:
	if not dir_path.ends_with("/"):
		dir_path += "/"
	
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[PhonemeMap] Failed to open audio folder: %s" % dir_path)
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var loaded_count: int = 0
	
	while not file_name.is_empty():
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			var ext := file_name.get_extension().to_lower()
			if ext in ["wav", "ogg", "mp3"]:
				var phoneme_id := file_name.get_basename().to_lower()
				var full_path := dir_path + file_name
				var stream := load(full_path) as AudioStream
				if stream != null:
					entries[phoneme_id] = stream
					loaded_count += 1
		file_name = dir.get_next()
	
	dir.list_dir_end()
	_invalidate_cache()
	print("[PhonemeMap] Successfully populated %d phonemes from %s!" % [loaded_count, dir_path])
