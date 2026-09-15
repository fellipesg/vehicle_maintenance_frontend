import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vehicle.dart';

enum VehicleIdentitySize { card, hero }

class VehicleIdentity extends StatelessWidget {
  const VehicleIdentity({
    super.key,
    required this.vehicle,
    this.size = VehicleIdentitySize.card,
    this.showCopy = false,
  });

  final Vehicle vehicle;
  final VehicleIdentitySize size;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    final isHero = size == VehicleIdentitySize.hero;
    final chassisStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: isHero ? 1.2 : 1,
          fontWeight: FontWeight.w600,
          fontSize: isHero ? 18 : 14,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHASSI',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1,
              ),
        ),
        const SizedBox(height: 4),
        if (vehicle.chassis != null && vehicle.chassis!.isNotEmpty)
          Row(
            children: [
              Expanded(child: Text(vehicle.chassis!, style: chassisStyle)),
              if (showCopy)
                IconButton(
                  key: const Key('copy_chassis_button'),
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: vehicle.chassis!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Chassi copiado')),
                    );
                  },
                ),
            ],
          )
        else
          Chip(
            label: const Text('Chassi não informado'),
            backgroundColor: Colors.amber.shade50,
            side: BorderSide(color: Colors.amber.shade300),
          ),
        const SizedBox(height: 8),
        if (vehicle.displayPlate.isNotEmpty)
          Chip(
            label: Text('Placa atual ${vehicle.displayPlate}'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
