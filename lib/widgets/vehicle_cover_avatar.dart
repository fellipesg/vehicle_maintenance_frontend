import 'package:flutter/material.dart';

class VehicleCoverAvatar extends StatelessWidget {
  const VehicleCoverAvatar({
    super.key,
    this.coverPhotoUrl,
    this.size = 48,
    this.borderRadius = 8,
  });

  final String? coverPhotoUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = coverPhotoUrl?.trim();

    if (url != null && url.isNotEmpty) {
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
