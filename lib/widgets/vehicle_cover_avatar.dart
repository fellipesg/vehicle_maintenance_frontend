import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class VehicleCoverAvatar extends StatelessWidget {
  const VehicleCoverAvatar({
    super.key,
    this.coverPhotoUrl,
    this.coverPhotoPortraitUrl,
    this.coverPhotoThumbUrl,
    this.size = 48,
    this.borderRadius = 8,
  });

  final String? coverPhotoUrl;
  final String? coverPhotoPortraitUrl;
  final String? coverPhotoThumbUrl;
  final double size;
  final double borderRadius;

  String? get _displayUrl {
    final thumb = coverPhotoThumbUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }

    final portrait = coverPhotoPortraitUrl?.trim();
    if (portrait != null && portrait.isNotEmpty) {
      return portrait;
    }

    final landscape = coverPhotoUrl?.trim();
    if (landscape != null && landscape.isNotEmpty) {
      return landscape;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _displayUrl;

    if (url != null) {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheSize = (size * pixelRatio).round();

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          memCacheWidth: cacheSize,
          memCacheHeight: cacheSize,
          placeholder: (_, __) => _placeholder(context),
          errorWidget: (_, __, ___) => _fallback(context),
        ),
      );
    }

    return _fallback(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const _ShimmerBox(),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.directions_car,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: child,
        );
      },
      child: const SizedBox.expand(),
    );
  }
}
