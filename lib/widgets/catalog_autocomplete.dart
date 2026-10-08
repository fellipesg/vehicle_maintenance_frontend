import 'package:flutter/material.dart';

/// Campo de texto com sugestões do catálogo de veículos.
///
/// Sugere, não obriga: o catálogo pode não ter um modelo recém-lançado ou um
/// importado, e o backend aceita qualquer string em `brand` e `model`. Com a
/// lista vazia (catálogo ainda carregando ou requisição falhou) o campo se
/// comporta como um `TextFormField` comum.
///
/// Usa `RawAutocomplete` em vez de `Autocomplete` para receber o controller e o
/// focus node de fora — o formulário já tem os seus e os descarta no dispose.
class CatalogAutocomplete extends StatelessWidget {
  const CatalogAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.decoration,
    this.validator,
    this.onSelected,
    this.optionsMaxHeight = 240,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;
  final InputDecoration decoration;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSelected;
  final double optionsMaxHeight;

  /// Sem texto, mostra o começo da lista para quem só quer ver o que existe.
  /// Com texto, filtra por "contém", ignorando a caixa.
  Iterable<String> _optionsFor(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();

    if (query.isEmpty) {
      return options.take(50);
    }

    return options
        .where((option) => option.toLowerCase().contains(query))
        .take(50);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: _optionsFor,
      onSelected: (selection) => onSelected?.call(selection),
      fieldViewBuilder: (
        context,
        textEditingController,
        fieldFocusNode,
        onFieldSubmitted,
      ) {
        return TextFormField(
          controller: textEditingController,
          focusNode: fieldFocusNode,
          decoration: decoration,
          textCapitalization: TextCapitalization.words,
          validator: validator,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelectedOption, optionsIterable) {
        final items = optionsIterable.toList();

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: optionsMaxHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final option = items[index];

                    return ListTile(
                      dense: true,
                      title: Text(option),
                      onTap: () => onSelectedOption(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
