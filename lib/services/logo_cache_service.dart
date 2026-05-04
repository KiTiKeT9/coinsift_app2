import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

/// Постоянный кеш логотипов в Hive.
///
/// Логотипы банков (Clearbit) и эмитентов (Tinkoff Brands CDN) часто
/// возвращают пустые или 404-ответы и каждый запуск перезагружаются с
/// нуля. Этот сервис:
///  * хранит уже скачанные bytes в Hive box `logo_cache`,
///  * при повторном запросе отдаёт их синхронно (без сети),
///  * поддерживает «отрицательный» кеш — если URL вернул не-картинку,
///    мы не дёргаем его повторно сутки.
///
/// API подобран так, чтобы быть пригодным как для FutureBuilder, так
/// и для синхронного `peek` в `build()`.
class LogoCacheService {
  LogoCacheService._();
  static final LogoCacheService instance = LogoCacheService._();

  static const String boxName = 'logo_cache';
  static const Duration _negativeTtl = Duration(hours: 24);

  Box<dynamic>? _box;
  final Map<String, Uint8List> _memCache = {};
  final Map<String, Future<Uint8List?>> _inflight = {};

  /// Открывает Hive-бокс. Должно вызываться один раз при инициализации
  /// приложения (`main.dart::_initStorage`).
  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
  }

  /// Синхронно возвращает закешированные bytes, если они уже есть в
  /// памяти. Не дёргает диск/сеть — годится для немедленного рендера.
  Uint8List? peek(String url) => _memCache[url];

  /// Достаёт картинку: память → Hive → сеть. Если URL отдал не-картинку,
  /// кеширует «отрицательный» ответ на сутки и возвращает `null`.
  Future<Uint8List?> get(String url) {
    return _inflight.putIfAbsent(url, () => _load(url)).whenComplete(() {
      _inflight.remove(url);
    });
  }

  Future<Uint8List?> _load(String url) async {
    final mem = _memCache[url];
    if (mem != null) return mem;

    final box = _box;
    if (box != null) {
      final raw = box.get(url);
      if (raw is Uint8List) {
        _memCache[url] = raw;
        return raw;
      }
      if (raw is Map) {
        final ts = raw['negativeAt'];
        if (ts is int) {
          final at = DateTime.fromMillisecondsSinceEpoch(ts);
          if (DateTime.now().difference(at) < _negativeTtl) return null;
        }
      }
    }

    try {
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 &&
          resp.bodyBytes.isNotEmpty &&
          _looksLikeImage(resp.bodyBytes)) {
        _memCache[url] = resp.bodyBytes;
        await box?.put(url, resp.bodyBytes);
        return resp.bodyBytes;
      }
      // Сервер ответил, но это не картинка (404, HTML-заглушка и т.п.) —
      // помечаем URL как «битый» на сутки, чтобы не дёргать его на каждом
      // скролле списка.
      await box?.put(url, {
        'negativeAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      // Таймаут/нет сети — НЕ помечаем как битый: при следующей попытке
      // попробуем снова. Иначе логотипы пропадают на сутки после одного
      // плохого пакета.
      debugPrint('LogoCache fetch failed for $url: $e');
    }
    return null;
  }

  /// Проверяет «магические» байты: PNG / JPEG / GIF / WEBP / SVG.
  /// Защищает от того, что Clearbit вернул HTML-заглушку с 200.
  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // GIF: 47 49 46
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // RIFF...WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // SVG: <svg ... или <?xml
    final head = String.fromCharCodes(
      bytes.take(64).where((b) => b > 0 && b < 128),
    ).toLowerCase();
    if (head.contains('<svg') || head.contains('<?xml')) return true;
    return false;
  }
}
