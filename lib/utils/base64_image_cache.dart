import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter/material.dart';

/// A utility to cache decoded base64 images as Uint8List and MemoryImage providers.
/// This prevents image flickering and GPU re-decoding lag in Flutter when widgets rebuild
class Base64ImageCache {
  static const int _maxCapacity = 200;
  
  // Use LinkedHashMap to keep track of insertion order for FIFO eviction policy
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap<String, Uint8List>();
  static final LinkedHashMap<String, MemoryImage> _providerCache = LinkedHashMap<String, MemoryImage>();

  /// Decodes a base64 string to Uint8List, caching the result.
  static Uint8List decode(String base64Str) {
    if (base64Str.isEmpty) {
      return Uint8List(0);
    }

    if (_cache.containsKey(base64Str)) {
      final value = _cache.remove(base64Str)!;
      _cache[base64Str] = value;
      return value;
    }

    try {
      final decoded = base64Decode(base64Str);
      if (_cache.length >= _maxCapacity) {
        final firstKey = _cache.keys.first;
        _cache.remove(firstKey);
      }
      _cache[base64Str] = decoded;
      return decoded;
    } catch (e) {
      return Uint8List(0);
    }
  }

  /// Returns a cached MemoryImage provider for the base64 string.
  static MemoryImage? getMemoryImage(String base64Str) {
    if (base64Str.isEmpty) return null;
    final clean = base64Str.contains(',') ? base64Str.split(',')[1] : base64Str;
    final trimmed = clean.trim();
    if (trimmed.isEmpty) return null;

    if (_providerCache.containsKey(trimmed)) {
      final provider = _providerCache.remove(trimmed)!;
      _providerCache[trimmed] = provider;
      return provider;
    }

    final bytes = decode(trimmed);
    if (bytes.isEmpty) return null;

    final provider = MemoryImage(bytes);
    if (_providerCache.length >= _maxCapacity) {
      _providerCache.remove(_providerCache.keys.first);
    }
    _providerCache[trimmed] = provider;
    return provider;
  }

  /// Clears the cache
  static void clear() {
    _cache.clear();
    _providerCache.clear();
  }
}
