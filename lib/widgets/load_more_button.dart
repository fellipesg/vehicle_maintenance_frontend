import 'package:flutter/material.dart';

/// Rodapé das listas paginadas: o backend devolve 15 itens por página e sem isso
/// a lista terminava na primeira sem avisar que havia mais.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.label = 'Carregar mais',
  });

  final bool isLoading;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: isLoading
            ? const SizedBox(
                key: Key('load_more_progress'),
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton.icon(
                key: const Key('load_more_button'),
                onPressed: onPressed,
                icon: const Icon(Icons.expand_more),
                label: Text(label),
              ),
      ),
    );
  }
}
