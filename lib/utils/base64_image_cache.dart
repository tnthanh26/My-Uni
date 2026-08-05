import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// A utility to cache decoded base64 images and downloaded network images as Uint8List in memory.
/// This prevents image flickering, GPU re-decoding lag, and default image fallbacks when widgets rebuild or scroll.
class Base64ImageCache {
  static const int _maxCapacity = 500;

  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap<String, Uint8List>();
  static final LinkedHashMap<String, MemoryImage> _providerCache = LinkedHashMap<String, MemoryImage>();
  static final LinkedHashMap<String, String> _userAvatarMap = LinkedHashMap<String, String>();
  static final Set<String> _pendingDownloads = <String>{};

  static void _putInCache(String key, Uint8List bytes) {
    if (bytes.isEmpty) return;
    if (_cache.length >= _maxCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = bytes;
  }

  /// Returns cached bytes for either a base64 string OR a network URL if already downloaded
  static Uint8List? getCachedBytes(String? imageUrl) {
    if (imageUrl == null) return null;
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) return null;

    if (_cache.containsKey(cleanUrl)) {
      final value = _cache.remove(cleanUrl)!;
      _cache[cleanUrl] = value;
      return value;
    }

    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      final bytes = decode(cleanUrl);
      if (bytes.isNotEmpty) return bytes;
    }

    return null;
  }

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
      _putInCache(sanitized, decoded);
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

  /// Updates or registers a user's latest avatar photo string in memory
  static void updateUserAvatar(String userId, String? photoUrl) {
    if (userId.isEmpty || photoUrl == null || photoUrl.isEmpty) return;
    _userAvatarMap[userId] = photoUrl;
  }

  /// Returns the latest cached avatar photo string for a user ID if available
  static String? getCachedUserAvatar(String userId) {
    return _userAvatarMap[userId];
  }

  /// Preloads a network image URL into memory cache in background
  static Future<Uint8List?> preloadNetworkImage(String? imageUrl) async {
    if (imageUrl == null) return null;
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) return null;

    final existing = getCachedBytes(cleanUrl);
    if (existing != null) return existing;

    if (_pendingDownloads.contains(cleanUrl)) return null;
    _pendingDownloads.add(cleanUrl);

    try {
      final response = await http.get(Uri.parse(cleanUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _putInCache(cleanUrl, response.bodyBytes);
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Preload image failed: $cleanUrl -> $e');
    } finally {
      _pendingDownloads.remove(cleanUrl);
    }
    return null;
  }

  /// Preloads a list of network image URLs into memory in background
  static void preloadImages(List<String?> imageUrls) {
    for (final url in imageUrls) {
      if (url != null && url.trim().isNotEmpty && url.trim().startsWith('http')) {
        preloadNetworkImage(url);
      }
    }
  }

  /// Returns a Widget that safely displays an image (Base64 memory image or Network image).
  /// Once an image is loaded, it is saved in memory RAM cache so subsequent views and rebuilds
  /// render the actual image IMMEDIATELY (0ms, synchronous) without showing any default fallback image.
  static Widget buildSmartImage({
    required String? imageUrl,
    required double height,
    required double width,
    BoxFit fit = BoxFit.cover,
    String fallbackAsset = 'assets/images/news.png',
  }) {
    return _SmartImageWidget(
      imageUrl: imageUrl,
      height: height,
      width: width,
      fit: fit,
      fallbackAsset: fallbackAsset,
    );
  }

  /// Clears the cache
  static void clear() {
    _cache.clear();
    _providerCache.clear();
    _userAvatarMap.clear();
    _pendingDownloads.clear();
  }
}

class _SmartImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double height;
  final double width;
  final BoxFit fit;
  final String fallbackAsset;

  const _SmartImageWidget({
    required this.imageUrl,
    required this.height,
    required this.width,
    required this.fit,
    required this.fallbackAsset,
  });

  @override
  State<_SmartImageWidget> createState() => _SmartImageWidgetState();
}

class _SmartImageWidgetState extends State<_SmartImageWidget> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _checkAndLoadImage();
  }

  @override
  void didUpdateWidget(covariant _SmartImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _checkAndLoadImage();
    }
  }

  void _checkAndLoadImage() {
    final cleanUrl = widget.imageUrl?.trim() ?? '';
    if (cleanUrl.isEmpty) return;

    final bytes = Base64ImageCache.getCachedBytes(cleanUrl);
    if (bytes != null) {
      _cachedBytes = bytes;
      return;
    }

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      Base64ImageCache.preloadNetworkImage(cleanUrl).then((fetchedBytes) {
        if (mounted && fetchedBytes != null) {
          setState(() {
            _cachedBytes = fetchedBytes;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = widget.imageUrl?.trim() ?? '';
    if (cleanUrl.isEmpty) {
      return Image.asset(
        widget.fallbackAsset,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFF2F4F7)),
      );
    }

    // 1. Check if RAM cache has the decoded/downloaded bytes
    final currentBytes = _cachedBytes ?? Base64ImageCache.getCachedBytes(cleanUrl);
    if (currentBytes != null && currentBytes.isNotEmpty) {
      return Image.memory(
        currentBytes,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          widget.fallbackAsset,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
        ),
      );
    }

    // 2. Base64 string fallback check
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      final decodedBytes = Base64ImageCache.decode(cleanUrl);
      if (decodedBytes.isNotEmpty) {
        return Image.memory(
          decodedBytes,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            widget.fallbackAsset,
            height: widget.height,
            width: widget.width,
            fit: widget.fit,
          ),
        );
      }
    }

    // 3. First time download ever seen: Stack fallback under Image.network until bytes arrive
    return Stack(
      children: [
        Image.asset(
          widget.fallbackAsset,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFF2F4F7)),
        ),
        Image.network(
          cleanUrl,
          height: widget.height,
          width: widget.width,
          fit: widget.fit,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return const SizedBox.shrink();
          },
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
