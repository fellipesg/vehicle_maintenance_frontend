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

  Widget _initialsText(Color color) {
    return Text(
      _initials,
      style: TextStyle(
        color: color,
        fontSize: _dimension * 0.32,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _verifiedMarker() {
    final hasLogo =
        workshopLogoUrl != null && workshopLogoUrl!.trim().isNotEmpty;

    return Container(
      key: const Key('provenance_marker_verified'),
      width: _dimension,
      height: _dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasLogo ? null : ProvenanceTheme.verifiedInk,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Image.network(
              workshopLogoUrl!,
              width: _dimension,
              height: _dimension,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: ProvenanceTheme.verifiedInk,
                child: Center(child: _initialsText(Colors.white)),
              ),
            )
          : Center(child: _initialsText(Colors.white)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return _verifiedMarker();
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
      child: _initialsText(ProvenanceTheme.declaredInk),
    );
  }
}

enum ProvenanceMarkerSize { sm, md }
