import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/logo_cache_service.dart';

/// Картинка-логотип с персистентным кешем.
///
/// Стратегия рендера:
///  1. Если bytes уже в памяти — рисуем их сразу (никакого «мерцания»
///     placeholder при последующих заходах на экран).
///  2. Иначе показываем `placeholder`, в фоне грузим из Hive/сети,
///     по готовности — анимированно подменяем.
///  3. Если URL вернул не-картинку или сеть упала, остаёмся на
///     placeholder, и [LogoCacheService] помечает URL как «плохой» на
///     сутки, чтобы не дёргать его на каждом скролле списка.
class CachedLogoImage extends StatefulWidget {
  const CachedLogoImage({
    super.key,
    required this.url,
    required this.placeholder,
    required this.size,
    this.radius = 8,
    this.fit = BoxFit.contain,
    this.background = Colors.white,
  });

  final String url;
  final Widget placeholder;
  final double size;
  final double radius;
  final BoxFit fit;
  final Color background;

  @override
  State<CachedLogoImage> createState() => _CachedLogoImageState();
}

class _CachedLogoImageState extends State<CachedLogoImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final cache = LogoCacheService.instance;
    final mem = cache.peek(widget.url);
    if (mem != null) {
      setState(() => _bytes = mem);
      return;
    }
    final fetched = await cache.get(widget.url);
    if (!mounted) return;
    if (fetched != null) setState(() => _bytes = fetched);
  }

  @override
  Widget build(BuildContext context) {
    final clip = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _bytes == null
            ? widget.placeholder
            : Container(
                color: widget.background,
                child: Image.memory(
                  _bytes!,
                  width: widget.size,
                  height: widget.size,
                  fit: widget.fit,
                  gaplessPlayback: true,
                ),
              ),
      ),
    );
    return clip;
  }
}
