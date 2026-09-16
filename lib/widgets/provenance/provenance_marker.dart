import 'package:flutter/material.dart';

import '../../theme/provenance.dart';

class ProvenanceMarker extends StatelessWidget {
  const ProvenanceMarker({
    super.key,
    required this.isVerified,
    this.workshopLogoUrl,
    this.workshopName,
    this.authorName,
    this.size = ProvenanceMarkerSize.md,
  });

  final bool isVerified;
  final String? workshopLogoUrl;
  final String? workshopName;
  final String? authorName;
  final ProvenanceMarkerSize size;

  double get _dimension => size == ProvenanceMarkerSize.sm
      ? ProvenanceTheme.markerSizeSm
      : ProvenanceTheme.markerSize;

  String get _initials {
    final source = (isVerified ? workshopName : authorName) ?? '?';
    final parts = source.trim().split(RegExp(r'\s+'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.substring(0, 1).toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return CircleAvatar(
        key: const Key('provenance_marker_verified'),
        radius: _dimension / 2,
        backgroundColor: ProvenanceTheme.verifiedInk,
        backgroundImage: workshopLogoUrl != null && workshopLogoUrl!.isNotEmpty
            ? NetworkImage(workshopLogoUrl!)
            : null,
        child: workshopLogoUrl == null || workshopLogoUrl!.isEmpty
            ? Text(
                _initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _dimension * 0.32,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      );
    }

    return Container(
      key: const Key('provenance_marker_declared'),
      width: _dimension,
      height: _dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ProvenanceTheme.declaredSurface,
        border: Border.all(
          color: ProvenanceTheme.declaredInk,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: ProvenanceTheme.declaredInk,
          fontSize: _dimension * 0.32,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum ProvenanceMarkerSize { sm, md }
