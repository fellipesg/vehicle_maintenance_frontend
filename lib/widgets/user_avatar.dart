import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 50,
  });

  final String? name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(context),
        ),
      );
    }

    return _initialsAvatar(context);
  }

  Widget _initialsAvatar(BuildContext context) {
    final initial = (name != null && name!.isNotEmpty)
        ? name!.substring(0, 1).toUpperCase()
        : 'U';

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.72,
          color: Colors.white,
        ),
      ),
    );
  }
}
