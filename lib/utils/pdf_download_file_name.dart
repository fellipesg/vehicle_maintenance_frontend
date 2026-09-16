String pdfDownloadFileName({
  String? fromApi,
  required String fallback,
}) {
  final raw = (fromApi ?? fallback).trim();
  final name = raw.isEmpty ? fallback : raw.replaceAll(RegExp(r'[/\\]'), '_');

  return name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf';
}
