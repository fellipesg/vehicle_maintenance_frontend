import 'package:flutter/material.dart';

class TermsScrollAcceptance extends StatefulWidget {
  final String content;
  final ValueChanged<bool> onAcceptedChanged;

  const TermsScrollAcceptance({
    super.key,
    required this.content,
    required this.onAcceptedChanged,
  });

  @override
  State<TermsScrollAcceptance> createState() => _TermsScrollAcceptanceState();
}

class _TermsScrollAcceptanceState extends State<TermsScrollAcceptance> {
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToEnd = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final atEnd = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 8;

    if (atEnd != _scrolledToEnd) {
      setState(() {
        _scrolledToEnd = atEnd;
        if (!atEnd) {
          _accepted = false;
        }
      });
      widget.onAcceptedChanged(_accepted && _scrolledToEnd);
    }
  }

  void _toggleAccepted(bool? value) {
    final next = value ?? false;
    setState(() {
      _accepted = next;
    });
    widget.onAcceptedChanged(_accepted && _scrolledToEnd);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Termos de uso',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Role até o final para habilitar o aceite.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  child: Text(widget.content),
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: _scrolledToEnd ? _toggleAccepted : null,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Li e aceito os termos. Declaro que as informações prestadas são verdadeiras e de minha responsabilidade.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
