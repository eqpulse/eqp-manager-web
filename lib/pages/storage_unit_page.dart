import 'package:flutter/material.dart';

import 'dead_stock_page.dart';
import 'inventory_page.dart';
import 'missing_items_page.dart';

class StorageUnitPage extends StatelessWidget {
  final String siteName;
  final String clientName;
  final String storageCode;
  final String storageName;
  final int missingItems;
  final String missingValue;

  const StorageUnitPage({
    super.key,
    required this.siteName,
    required this.clientName,
    required this.storageCode,
    required this.storageName,
    required this.missingItems,
    required this.missingValue,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: Text(storageCode),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(clientName, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Text(siteName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(storageName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'ספירת מלאי',
                      subtitle: 'המלאי שנקלט בקריאה האחרונה',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InventoryPage(
                              siteName: siteName,
                              storageCode: storageCode,
                              storageName: storageName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.warning_amber_outlined,
                      title: 'ציוד חסר',
                      subtitle: '$missingItems פריטים | $missingValue',
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MissingItemsPage(
                              siteName: siteName,
                              storageCode: storageCode,
                              storageName: storageName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.access_time,
                      title: 'מלאי שלא זז',
                      subtitle: 'ציוד שלא נראה תקופה ארוכה',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeadStockPage(
                              siteName: siteName,
                              storageCode: storageCode,
                              storageName: storageName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.blueGrey;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 38, color: effectiveColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: effectiveColor),
              ),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
