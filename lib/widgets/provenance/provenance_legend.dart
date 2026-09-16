import 'package:flutter/material.dart';

import '../../theme/provenance.dart';
import 'provenance_marker.dart';

class ProvenanceLegend extends StatelessWidget {
  const ProvenanceLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProvenanceMarker(
          isVerified: true,
          workshopName: 'OF',
          size: ProvenanceMarkerSize.sm,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${ProvenanceTheme.sealLabel} (${ProvenanceTheme.verifiedMeta})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 16),
        ProvenanceMarker(
          isVerified: false,
          authorName: 'PR',
          size: ProvenanceMarkerSize.sm,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Declarada (${ProvenanceTheme.unverifiedMeta})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
