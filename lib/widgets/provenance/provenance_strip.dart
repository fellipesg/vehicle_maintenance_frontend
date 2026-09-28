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
    this.showFilterChips = true,
  });

  static const int _maxVisibleDots = 16;

  final List<ProvenanceSegment> segments;
  final int totalMaintenances;
  final int verifiedCount;
  final bool? verifiedFilter;
  final ValueChanged<int>? onTapSegment;
  final ValueChanged<bool?>? onFilterChanged;
  final bool showFilterChips;

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
        if (visible.isNotEmpty)
          Semantics(
            label: '$verifiedCount com selo, $_declaredCount $declaredLabel',
            child: Wrap(
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
          ),
        if (showFilterChips && onFilterChanged != null) ...[
          const SizedBox(height: 8),
          ProvenanceFilterBar(
            verifiedFilter: verifiedFilter,
            onFilterChanged: onFilterChanged!,
          ),
        ],
      ],
    );
  }
}

/// Filtro Todas / Selo / Declaradas (memória, sem nova chamada à API).
class ProvenanceFilterBar extends StatelessWidget {
  const ProvenanceFilterBar({
    super.key,
    required this.verifiedFilter,
    required this.onFilterChanged,
  });

  final bool? verifiedFilter;
  final ValueChanged<bool?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ProvenanceFilterButton(
          key: const Key('provenance_filter_all'),
          label: 'Todas',
          selected: verifiedFilter == null,
          onTap: () => onFilterChanged(null),
        ),
        _ProvenanceFilterButton(
          key: const Key('provenance_filter_verified'),
          label: ProvenanceTheme.sealLabel,
          selected: verifiedFilter == true,
          onTap: () => onFilterChanged(true),
        ),
        _ProvenanceFilterButton(
          key: const Key('provenance_filter_declared'),
          label: 'Declaradas',
          selected: verifiedFilter == false,
          onTap: () => onFilterChanged(false),
        ),
      ],
    );
  }
}

class _ProvenanceFilterButton extends StatelessWidget {
  const _ProvenanceFilterButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _inactiveBorder = Color(0xFFD1D5DB);
  static const Color _inactiveText = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ProvenanceTheme.verifiedInk : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? ProvenanceTheme.verifiedInk : _inactiveBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _inactiveText,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
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
