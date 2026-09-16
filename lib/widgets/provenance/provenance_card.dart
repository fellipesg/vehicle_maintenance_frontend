import 'package:flutter/material.dart';

import '../../models/maintenance.dart';
import '../../theme/provenance.dart';
import 'provenance_marker.dart';
import 'provenance_rail.dart';

class ProvenanceCard extends StatelessWidget {
  const ProvenanceCard({
    super.key,
    required this.maintenance,
    this.onTap,
  });

  final Maintenance maintenance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final verified = maintenance.isVerified;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: verified ? FontWeight.w600 : FontWeight.w500,
          color: verified
              ? ProvenanceTheme.verifiedTitle
              : ProvenanceTheme.declaredTitle,
        );
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: verified
              ? ProvenanceTheme.verifiedBody
              : ProvenanceTheme.declaredBody,
        );
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: verified
              ? ProvenanceTheme.verifiedMetaColor
              : ProvenanceTheme.declaredMeta,
        );

    final invoiceMeta = maintenance.hasInvoices
        ? ' · NF anexada (${maintenance.invoices!.length})'
        : '';

    final semanticsLabel =
        '${maintenance.maintenanceType}. ${maintenance.provenanceLabel ?? ''}. '
        '${maintenance.provenanceSublabel ?? ''}$invoiceMeta';

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProvenanceRail(isVerified: verified, height: 56),
        const SizedBox(width: 8),
        ProvenanceMarker(
          isVerified: verified,
          workshopLogoUrl: maintenance.verifiedWorkshop?.logoUrl,
          workshopName:
              maintenance.verifiedWorkshop?.name ?? maintenance.workshopName,
          authorName: maintenance.ownerName,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(maintenance.maintenanceType, style: titleStyle),
              if (maintenance.provenanceLabel != null)
                Text(
                  maintenance.provenanceLabel!,
                  style: labelStyle,
                ),
              Text(
                '${maintenance.provenanceSublabel ?? (verified ? ProvenanceTheme.verifiedMeta : ProvenanceTheme.unverifiedMeta)}$invoiceMeta',
                style: metaStyle,
              ),
            ],
          ),
        ),
      ],
    );

    return Semantics(
      label: semanticsLabel,
      child: Material(
        color: verified ? Colors.white : ProvenanceTheme.declaredSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
