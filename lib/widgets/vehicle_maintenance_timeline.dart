import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VehicleMaintenanceTimeline extends StatefulWidget {
  final Map<String, dynamic> timeline;

  const VehicleMaintenanceTimeline({
    super.key,
    required this.timeline,
  });

  @override
  State<VehicleMaintenanceTimeline> createState() =>
      _VehicleMaintenanceTimelineState();
}

class _VehicleMaintenanceTimelineState extends State<VehicleMaintenanceTimeline> {
  late List<Map<String, dynamic>> _events;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _events = (widget.timeline['events'] as List<dynamic>? ?? [])
        .map((event) => Map<String, dynamic>.from(event as Map))
        .toList();

    _expandedIndex = _events.indexWhere(
      (event) => event['is_current'] == true,
    );
    if (_expandedIndex == -1 && _events.isNotEmpty) {
      _expandedIndex = _events.length - 1;
    }
  }

  String _formatKm(dynamic value) {
    if (value == null) {
      return '—';
    }

    return '${NumberFormat.decimalPattern('pt_BR').format(value)} km';
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '—';
    }

    final date = DateTime.tryParse(value);
    if (date == null) {
      return value;
    }

    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatMoney(dynamic value) {
    final amount = (value is num) ? value.toDouble() : 0;
    return NumberFormat.simpleCurrency(locale: 'pt_BR').format(amount);
  }

  IconData _iconForEvent(Map<String, dynamic> event) {
    return switch (event['type']) {
      'registration' => Icons.directions_car,
      'upcoming' => Icons.schedule,
      _ => Icons.build_circle_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return const SizedBox.shrink();
    }

    final summary = Map<String, dynamic>.from(
      widget.timeline['summary'] as Map? ?? {},
    );
    final vehicle = Map<String, dynamic>.from(
      widget.timeline['vehicle'] as Map? ?? {},
    );
    final progress = (summary['progress_percent'] as num?)?.toDouble();
    final remaining = summary['kilometers_remaining'];
    final nextDue = summary['next_due_kilometers'];
    final isOverdue = summary['is_overdue'] == true;
    final approxAnnualKm = summary['approximate_annual_kilometers'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Linha do tempo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''} · '
              '${_formatKm(summary['last_kilometers'])} · '
              '${summary['maintenance_count'] ?? 0} manutenção(ões) · '
              '${_formatMoney(summary['total_spent'])} em itens'
              '${approxAnnualKm != null ? ' · ~${_formatKm(approxAnnualKm)}/ano (aprox.)' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (nextDue != null) ...[
              const SizedBox(height: 16),
              _ProgressHeader(
                currentKm: summary['last_kilometers'],
                nextDueKm: nextDue,
                remainingKm: remaining,
                progressPercent: progress,
                isOverdue: isOverdue,
                formatKm: _formatKm,
              ),
            ],
            const SizedBox(height: 20),
            ...List.generate(_events.length, (index) {
              final event = _events[index];
              final isLast = index == _events.length - 1;
              final isExpanded = _expandedIndex == index;
              final isUpcoming = event['type'] == 'upcoming';
              final isCurrent = event['is_current'] == true;

              return _TimelineRow(
                event: event,
                isExpanded: isExpanded,
                isLast: isLast,
                isUpcoming: isUpcoming,
                isCurrent: isCurrent,
                icon: _iconForEvent(event),
                formatKm: _formatKm,
                formatDate: _formatDate,
                formatMoney: _formatMoney,
                onTap: () => setState(() {
                  _expandedIndex = isExpanded ? null : index;
                }),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final dynamic currentKm;
  final dynamic nextDueKm;
  final dynamic remainingKm;
  final double? progressPercent;
  final bool isOverdue;
  final String Function(dynamic) formatKm;

  const _ProgressHeader({
    required this.currentKm,
    required this.nextDueKm,
    required this.remainingKm,
    required this.progressPercent,
    required this.isOverdue,
    required this.formatKm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (progressPercent ?? 0) / 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Odômetro atual: ${formatKm(currentKm)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: isOverdue ? colorScheme.error : colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOverdue
                ? 'Revisão estimada em ${formatKm(nextDueKm)} — em atraso'
                : 'Faltam ${formatKm(remainingKm)} para ${formatKm(nextDueKm)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOverdue ? colorScheme.error : null,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isExpanded;
  final bool isLast;
  final bool isUpcoming;
  final bool isCurrent;
  final IconData icon;
  final String Function(dynamic) formatKm;
  final String Function(String?) formatDate;
  final String Function(dynamic) formatMoney;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.event,
    required this.isExpanded,
    required this.isLast,
    required this.isUpcoming,
    required this.isCurrent,
    required this.icon,
    required this.formatKm,
    required this.formatDate,
    required this.formatMoney,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = isUpcoming
        ? colorScheme.outline
        : (isCurrent ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.7));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                formatKm(event['kilometers']),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isUpcoming ? colorScheme.outline : colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUpcoming ? Colors.transparent : primaryColor,
                      border: Border.all(
                        color: primaryColor,
                        width: isUpcoming ? 2 : 0,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: isExpanded ? 24 : 12,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: isUpcoming
                          ? colorScheme.outline.withValues(alpha: 0.35)
                          : colorScheme.outlineVariant,
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isUpcoming
                            ? colorScheme.outline.withValues(alpha: 0.6)
                            : (isCurrent
                                ? colorScheme.primary
                                : colorScheme.outlineVariant),
                        width: isCurrent ? 2 : 1,
                      ),
                      color: isCurrent
                          ? colorScheme.primary.withValues(alpha: 0.06)
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isUpcoming
                                    ? colorScheme.outline
                                    : colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event['label']?.toString() ?? 'Evento',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (event['date'] != null)
                                      Text(
                                        formatDate(event['date']?.toString()),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      )
                                    else if (isUpcoming)
                                      Text(
                                        'Estimativa · ${formatKm(event['kilometers_remaining'] ?? event['kilometers'])} restantes',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: _EventDetails(
                              event: event,
                              formatKm: formatKm,
                              formatDate: formatDate,
                              formatMoney: formatMoney,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
  }
}

class _EventDetails extends StatelessWidget {
  final Map<String, dynamic> event;
  final String Function(dynamic) formatKm;
  final String Function(String?) formatDate;
  final String Function(dynamic) formatMoney;

  const _EventDetails({
    required this.event,
    required this.formatKm,
    required this.formatDate,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final items = (event['items'] as List<dynamic>? ?? []);
    final isUpcoming = event['type'] == 'upcoming';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event['workshop_name'] != null)
          Text(
            event['workshop_name'].toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (event['description'] != null && event['description'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              event['description'].toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (!isUpcoming) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InfoTile(
                label: 'Quilometragem',
                value: formatKm(event['kilometers']),
              ),
              _InfoTile(
                label: 'Total itens',
                value: formatMoney(event['total_amount']),
              ),
            ],
          ),
        ],
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              isUpcoming
                  ? 'Marco estimado para a próxima revisão preventiva.'
                  : 'Sem itens registrados.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...items.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          map['name']?.toString() ?? 'Item',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${map['quantity']}x',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(map['total_price']),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
