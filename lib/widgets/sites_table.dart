import 'package:flutter/material.dart';

class SitesTable extends StatelessWidget {
  final List<Map<String, dynamic>> sites;
  final int Function(dynamic value) toInt;
  final String Function(dynamic value) money;
  final void Function(Map<String, dynamic> site) onSiteTap;

  const SitesTable({
    super.key,
    required this.sites,
    required this.toInt,
    required this.money,
    required this.onSiteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('אתר', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('לקוח', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('חוסרים', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('שווי חסר', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('כניסה', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sites.isEmpty
                ? const Center(
                    child: Text(
                      'אין חוסרים כרגע',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: sites.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final site = sites[index];

                      return InkWell(
                        onTap: () => onSiteTap(site),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  site['site_name']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(site['client_name']?.toString() ?? ''),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${toInt(site['missing_items'])}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  money(site['missing_value']),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Expanded(
                                flex: 1,
                                child: Icon(Icons.chevron_left),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}