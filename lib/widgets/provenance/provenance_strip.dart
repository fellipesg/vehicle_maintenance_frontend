import 'package:flutter/material.dart';

import '../../models/provenance_segment.dart';
import '../../theme/provenance.dart';

class ProvenanceStrip extends StatelessWidget {
  const ProvenanceStrip({
    super.key,
    required this.segments,
    required this.totalMaintenances,
    required this.verifiedCount,
    this.verifiedFilter,
    this.onTapSegment,
    this.onFilterChanged,
  });

  static const int _maxVisibleDots = 16;

  final List<ProvenanceSegment> segments;
  final int totalMaintenances;
  final int verifiedCount;
  final bool? verifiedFilter;
  final ValueChanged<int>? onTapSegment;
  final ValueChanged<bool?>? onFilterChanged;

  int get _declaredCount => totalMaintenances - verifiedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = segments.take(_maxVisibleDots).toList();
    final overflow = segments.length - visible.length;
    final declaredLabel = _declaredCount == 1 ? 'declarada' : 'declaradas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF374151),
            ),
            children: [
              TextSpan(
                text: '$verifiedCount',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ProvenanceTheme.verifiedInk,
                ),
              ),
              const TextSpan(text: ' com selo · '),
              TextSpan(
                text: '$_declaredCount',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ProvenanceTheme.declaredInk,
                ),
              ),
              TextSpan(text: ' $declaredLabel'),
            ],
          ),
        ),
        if (visible.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: ProvenanceTheme.dotGap,
            runSpacing: ProvenanceTheme.dotGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < visible.length; i++)
                _ProvenanceDot(
                  key: Key('provenance_strip_segment_$i'),
                  segment: visible[i],
                  onTap: onTapSegment == null
                      ? null
                      : () => onTapSegment!(visible[i].maintenanceId),
                ),
              if (overflow > 0)
                Text(
                  '+$overflow',
                  key: const Key('provenance_strip_overflow'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('provenance_filter_all'),
              label: const Text('Todas'),
              selected: verifiedFilter == null,
              onSelected: (_) => onFilterChanged?.call(null),
            ),
            ChoiceChip(
              key: const Key('provenance_filter_verified'),
              label: const Text(ProvenanceTheme.sealLabel),
              selected: verifiedFilter == true,
              onSelected: (_) => onFilterChanged?.call(true),
            ),
            ChoiceChip(
              key: const Key('provenance_filter_declared'),
              label: const Text('Declaradas'),
              selected: verifiedFilter == false,
              onSelected: (_) => onFilterChanged?.call(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProvenanceDot extends StatelessWidget {
  const _ProvenanceDot({
    super.key,
    required this.segment,
    this.onTap,
  });

  final ProvenanceSegment segment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: segment.isVerified ? 'Selo da oficina' : 'Declarada',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: _ProvenanceDotPainter(isVerified: segment.isVerified),
          size: const Size(
            ProvenanceTheme.dotSize,
            ProvenanceTheme.dotSize,
          ),
        ),
      ),
    );
  }
}

class _ProvenanceDotPainter extends CustomPainter {
  _ProvenanceDotPainter({required this.isVerified});

  final bool isVerified;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (isVerified) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = ProvenanceTheme.verifiedInk,
      );
      return;
    }

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = ProvenanceTheme.declaredSurface
        ..style = PaintingStyle.fill,
    );

    final borderPaint = Paint()
      ..color = ProvenanceTheme.declaredInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashCount = 12;
    const twoPi = 3.141592653589793 * 2;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * twoPi;
      final sweep = (twoPi / dashCount) * 0.45;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1),
        startAngle,
        sweep,
        false,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProvenanceDotPainter oldDelegate) =>
      oldDelegate.isVerified != isVerified;
}
