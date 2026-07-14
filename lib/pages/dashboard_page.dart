import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/dashboard_action_bar.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/kpi_card.dart';
import '../widgets/sites_table.dart';
import 'select_storage_page.dart';
import 'site_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> sites = [];

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('v_missing_by_site_live')
          .select()
          .order('missing_value', ascending: false);

      if (!mounted) return;

      setState(() {
        sites = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'שגיאה בטעינת לוח הבקרה';
      });
      debugPrint('Dashboard error: $e');
    }
  }

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String money(dynamic value) {
    final n = toDouble(value);
    return '₪${n.toStringAsFixed(0)}';
  }

  int get totalMissingItems =>
      sites.fold(0, (sum, site) => sum + toInt(site['missing_items']));

  double get totalMissingValue => sites.fold(
        0,
        (sum, site) => sum + toDouble(site['missing_value']),
      );

  void openInventoryFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectStoragePage(
          mode: StorageSelectionMode.inventory,
        ),
      ),
    );
  }

  void openDeadStockFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectStoragePage(
          mode: StorageSelectionMode.deadStock,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: const Text('EQP'),
          centerTitle: true,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DashboardHeader(onRefresh: loadDashboard),
                        const SizedBox(height: 14),
                        DashboardActionBar(
                          onInventory: openInventoryFlow,
                          onDeadStock: openDeadStockFlow,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: KpiCard(
                                icon: Icons.location_on_outlined,
                                title: 'אתרים עם חוסרים',
                                value: '${sites.length}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: KpiCard(
                                icon: Icons.warning_amber_outlined,
                                title: 'פריטים חסרים',
                                value: '$totalMissingItems',
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: KpiCard(
                                icon: Icons.payments_outlined,
                                title: 'שווי ציוד חסר',
                                value: money(totalMissingValue),
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: KpiCard(
                                icon: Icons.schedule,
                                title: 'עודכן לאחרונה',
                                value: '--:--',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'אתרים עם חוסרים',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SitesTable(
                            sites: sites,
                            toInt: toInt,
                            money: money,
                            onSiteTap: (site) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SitePage(
                                    siteName:
                                        site['site_name']?.toString() ?? '',
                                    clientName:
                                        site['client_name']?.toString() ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
