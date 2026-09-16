import 'package:flutter/material.dart';

class VehicleCoverAvatar extends StatelessWidget {
  const VehicleCoverAvatar({
    super.key,
    this.coverPhotoUrl,
    this.coverPhotoPortraitUrl,
    this.size = 48,
    this.borderRadius = 8,
  });

  final String? coverPhotoUrl;
  final String? coverPhotoPortraitUrl;
  final double size;
  final double borderRadius;

  String? get _displayUrl {
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
        ),
      );
    }

    return _fallback(context);
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
