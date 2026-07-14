import 'package:flutter/material.dart';

class DashboardActionBar extends StatelessWidget {
  final VoidCallback onInventory;
  final VoidCallback onDeadStock;

  const DashboardActionBar({
    super.key,
    required this.onInventory,
    required this.onDeadStock,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 520,
        height: 40,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onInventory,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('ספירת מלאי'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDeadStock,
                icon: const Icon(Icons.access_time, size: 18),
                label: const Text('מלאי שלא זז'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}