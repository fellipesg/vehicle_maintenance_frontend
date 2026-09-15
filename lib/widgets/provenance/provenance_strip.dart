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

  final List<ProvenanceSegment> segments;
  final int totalMaintenances;
  final int verifiedCount;
  final bool? verifiedFilter;
  final ValueChanged<int>? onTapSegment;
  final ValueChanged<bool?>? onFilterChanged;

  int get _declaredCount => totalMaintenances - verifiedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: ProvenanceTheme.stripHeight,
          child: CustomPaint(
            painter: _StripPainter(segments: segments),
            child: Row(
              children: [
                for (var i = 0; i < segments.length; i++)
                  Expanded(
                    child: GestureDetector(
                      key: Key('provenance_strip_segment_$i'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          onTapSegment?.call(segments[i].maintenanceId),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$totalMaintenances manutenções · $verifiedCount com selo de oficina · $_declaredCount declaradas',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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

class _StripPainter extends CustomPainter {
  _StripPainter({required this.segments});

  final List<ProvenanceSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) {
      return;
    }

    final segmentWidth = size.width / segments.length;
    for (var i = 0; i < segments.length; i++) {
      final rect = Rect.fromLTWH(i * segmentWidth + (i > 0 ? 0.5 : 0), 0,
          segmentWidth - 0.5, size.height);
      if (segments[i].isVerified) {
        canvas.drawRect(rect, Paint()..color = ProvenanceTheme.verifiedInk);
      } else {
        final paint = Paint()..color = const Color(0xFFF59E0B);
        canvas.save();
        canvas.clipRect(rect);
        const spacing = 4.0;
        for (double x = -size.height;
            x < rect.width + size.height;
            x += spacing) {
          canvas.drawLine(
            Offset(rect.left + x, rect.top),
            Offset(rect.left + x + size.height, rect.bottom),
            paint..strokeWidth = 1,
          );
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StripPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
