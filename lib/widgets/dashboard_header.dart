import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const DashboardHeader({
    super.key,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'לוח בקרה',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        const Text(
          'Equipment Platform Pulse',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('רענון דשבורד'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('התנתקות'),
        ),
      ],
    );
  }
}