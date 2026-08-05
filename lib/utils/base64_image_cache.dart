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

    final clean = base64Str.contains(',') ? base64Str.split(',')[1] : base64Str;
    final sanitized = clean.replaceAll(RegExp(r'\s+'), '');
    if (sanitized.isEmpty) return Uint8List(0);

    if (_cache.containsKey(sanitized)) {
      final value = _cache.remove(sanitized)!;
      _cache[sanitized] = value;
      return value;
    }

    try {
      final decoded = base64Decode(sanitized);
      if (_cache.length >= _maxCapacity) {
        final firstKey = _cache.keys.first;
        _cache.remove(firstKey);
      }
      _cache[sanitized] = decoded;
      return decoded;
    } catch (e) {
      return Uint8List(0);
    }
  }

  /// Returns a cached MemoryImage provider for the base64 string.
  static MemoryImage? getMemoryImage(String base64Str) {
    if (base64Str.isEmpty) return null;
    final clean = base64Str.contains(',') ? base64Str.split(',')[1] : base64Str;
    final sanitized = clean.replaceAll(RegExp(r'\s+'), '');
    if (sanitized.isEmpty || sanitized.length < 10) return null;

    if (_providerCache.containsKey(sanitized)) {
      final provider = _providerCache.remove(sanitized)!;
      _providerCache[sanitized] = provider;
      return provider;
    }

    final bytes = decode(sanitized);
    if (bytes.isEmpty) return null;

    final provider = MemoryImage(bytes);
    if (_providerCache.length >= _maxCapacity) {
      _providerCache.remove(_providerCache.keys.first);
    }
    _providerCache[sanitized] = provider;
    return provider;
  }

  /// Safely returns an ImageProvider (NetworkImage or MemoryImage) for avatar rendering
  /// without throwing 'No host specified in URI' or base64 decoding errors.
  static ImageProvider? getAvatarProvider(String? photoUrl) {
    if (photoUrl == null) return null;
    final trimmed = photoUrl.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'none') return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        if (uri.hasScheme && uri.hasAuthority && uri.host.isNotEmpty) {
          return NetworkImage(trimmed);
        }
      } catch (_) {
        return null;
      }
    }

    return getMemoryImage(trimmed);
  }

  static final LinkedHashMap<String, String> _userAvatarMap = LinkedHashMap<String, String>();

  /// Updates or registers a user's latest avatar photo string in memory
  static void updateUserAvatar(String userId, String? photoUrl) {
    if (userId.isEmpty || photoUrl == null || photoUrl.isEmpty) return;
    _userAvatarMap[userId] = photoUrl;
  }

  /// Returns the latest cached avatar photo string for a user ID if available
  static String? getCachedUserAvatar(String userId) {
    return _userAvatarMap[userId];
  }

  /// Clears the cache
  static void clear() {
    _cache.clear();
    _providerCache.clear();
    _userAvatarMap.clear();
  }
}
