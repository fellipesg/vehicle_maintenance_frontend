import 'package:flutter/material.dart';

SnackBar pdfExportProgressSnackBar({required VoidCallback onCancel}) {
  return SnackBar(
    duration: const Duration(minutes: 5),
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(
      label: 'Cancelar',
      onPressed: onCancel,
    ),
    content: const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 16),
        Expanded(child: Text('Gerando PDF...')),
      ],
    ),
  );
}
