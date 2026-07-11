import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';

/// A utility to cache decoded base64 images as Uint8List.
/// This prevents image flickering in Flutter when widgets rebuild (e.g. during animations)
/// because Flutter's Image.memory and MemoryImage compare Uint8List by reference.
class Base64ImageCache {
  static const int _maxCapacity = 200;
  
  // Use LinkedHashMap to keep track of insertion order for FIFO eviction policy
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap<String, Uint8List>();

  /// Decodes a base64 string to Uint8List, caching the result.
  /// If the same string is decoded again, it returns the exact same Uint8List reference.
  static Uint8List decode(String base64Str) {
    if (base64Str.isEmpty) {
      return Uint8List(0);
    }

    if (_cache.containsKey(base64Str)) {
      // Move to the end to mark as recently used
      final value = _cache.remove(base64Str)!;
      _cache[base64Str] = value;
      return value;
    }

    try {
      final decoded = base64Decode(base64Str);
      if (_cache.length >= _maxCapacity) {
        // Evict the oldest item
        final firstKey = _cache.keys.first;
        _cache.remove(firstKey);
      }
      _cache[base64Str] = decoded;
      return decoded;
    } catch (e) {
      // Return empty list on decode failure
      return Uint8List(0);
    }
  }

  /// Clears the cache
  static void clear() {
    _cache.clear();
  }
}
