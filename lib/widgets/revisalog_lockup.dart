import 'package:flutter/material.dart';

/// Horizontal RevisaLog mark: odometer icon + wordmark (no baked PNG frame).
class RevisalogLockupHorizontal extends StatelessWidget {
  const RevisalogLockupHorizontal({super.key, this.height = 32});

  final double height;

  static const Color _teal = Color(0xFF2EC4B6);

  @override
  Widget build(BuildContext context) {
    final fontSize = height * 0.72;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/brand/app-icon.png',
          height: height,
          width: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(width: height * 0.28),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              height: 1,
            ),
            children: const [
              TextSpan(
                text: 'Revisa',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'Log',
                style: TextStyle(color: _teal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
