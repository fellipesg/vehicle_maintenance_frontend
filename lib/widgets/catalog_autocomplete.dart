import 'package:flutter/material.dart';

/// Campo de marca ou modelo: busca dentro do catálogo e só aceita valor dele.
///
/// O portal web usa `<select>` fechado nos dois campos, e o catálogo é curado
/// pelo admin (/admin/marcas, /admin/modelos). O app segue o mesmo contrato —
/// nada fora do catálogo — mas com busca, porque rolar vinte e tantas marcas (e
/// os modelos de uma marca grande) é ruim em tela de celular.
///
/// Duas saídas deliberadas:
/// - `options` vazio (catálogo carregando ou requisição falhou) desliga a
///   checagem: sem catálogo não dá para validar contra ele, e travar o cadastro
///   por falha de rede seria pior que aceitar o texto.
/// - Valor legado continua válido se o formulário o incluir em `options`, como
///   o web faz ao injetar o modelo atual que saiu do catálogo.
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
    required this.requiredMessage,
    required this.invalidMessage,
    this.enabled = true,
    this.onSelected,
    this.optionsMaxHeight = 240,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;
  final InputDecoration decoration;
  final String requiredMessage;
  final String invalidMessage;
  final bool enabled;
  final ValueChanged<String>? onSelected;
  final double optionsMaxHeight;

  String? _validate(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) {
      return requiredMessage;
    }

    // Sem catálogo não há contra o que validar.
    if (options.isEmpty) {
      return null;
    }

    return options.contains(text) ? null : invalidMessage;
  }

  /// Sem texto, mostra o começo da lista para quem só quer ver o que existe.
  /// Com texto, filtra por "contém", ignorando a caixa.
  Iterable<String> _optionsFor(TextEditingValue value) {
    if (!enabled) {
      return const Iterable<String>.empty();
    }

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
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          validator: enabled ? _validate : null,
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
