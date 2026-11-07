import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/dashboard_action_bar.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/kpi_card.dart';
import '../widgets/sites_table.dart';
import 'select_storage_page.dart';
import 'inactive_items_page.dart';
import 'site_page.dart';
import 'equipment_transfers_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  String? customerName;
  String? customerNameError;
  List<Map<String, dynamic>> sites = [];

  @override
  void initState() {
    super.initState();
    loadCustomerName();
    loadDashboard();
  }

  Future<void> loadCustomerName() async {
    if (mounted) {
      setState(() {
        customerName = null;
        customerNameError = null;
      });
    }

    String stage = 'auth';
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('EQP customer lookup: no authenticated user');
        if (mounted) setState(() => customerNameError = 'לא מחובר משתמש');
        return;
      }

      stage = 'eqp_users';
      final membership = await supabase
          .from('eqp_users')
          .select('customer_id')
          .eq('id', user.id)
          .maybeSingle();

      final customerId = membership?['customer_id']?.toString();
      if (customerId == null || customerId.isEmpty) {
        debugPrint('EQP customer lookup: no visible eqp_users membership');
        if (mounted) {
          setState(() => customerNameError = 'לא נמצא שיוך לקוח למשתמש המחובר');
        }
        return;
      }

      stage = 'customers';
      final customer = await supabase
          .from('customers')
          .select('company_name')
          .eq('id', customerId)
          .maybeSingle();

      if (!mounted) return;
      final name = customer?['company_name']?.toString().trim();
      if (name == null || name.isEmpty) {
        debugPrint('EQP customer lookup: customer record not visible or name empty');
        setState(() => customerNameError = 'שם החברה לא נמצא או שאין הרשאת צפייה');
        return;
      }

      debugPrint('EQP customer lookup: company name loaded successfully');
      setState(() {
        customerName = name;
        customerNameError = null;
      });
    } on PostgrestException catch (e) {
      debugPrint('EQP customer lookup failed at $stage: code=${e.code}; message=${e.message}');
      if (mounted) {
        setState(() => customerNameError =
            'שגיאה בשליפת פרטי החברה ($stage, ${e.code ?? 'unknown'})');
      }
    } catch (e) {
      debugPrint('EQP customer lookup failed at $stage: $e');
      if (mounted) {
        setState(() => customerNameError = 'לא ניתן לטעון שם לקוח ($stage)');
      }
    }
  }

  Future<void> exportInventoryExcel() async {
  debugPrint('EXCEL BUTTON PRESSED');
try {
 final scope = await showDialog<String>(
  context: context,
  builder: (dialogContext) => Directionality(
    textDirection: TextDirection.rtl,
    child: SimpleDialog(
      title: const Text('בחר היקף דוח מלאי'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'all'),
          child: const Text('כל החברה'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'site'),
          child: const Text('אתר מסוים'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'container'),
          child: const Text('מחסן / מכולה מסוימים'),
        ),
      ],
    ),
  ),
);

  if (scope == null) return;

final rows = await supabase
    .from('v_inventory_export')
    .select()
    .order('site_name');

if (scope == 'site') {
  final siteNames = rows
      .map((item) => item['site_name']?.toString() ?? '')
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  if (!mounted) return;

  final selectedSite = await showDialog<String>(
  context: context,
  builder: (dialogContext) => Directionality(
    textDirection: TextDirection.rtl,
    child: SimpleDialog(
      title: const Text('בחר אתר'),
      children: siteNames.map((name) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, name),
          child: Text(name),
        );
      }).toList(),
    ),
  ),
);

if (selectedSite == null) return;

rows.removeWhere(
  (item) => item['site_name'] != selectedSite,
);
}

if (scope == 'container') {
  final containers = rows
      .map((item) => {
            'site': item['site_name']?.toString() ?? '',
            'container': item['container_code']?.toString() ?? '',
          })
      .where((item) => item['container']!.isNotEmpty)
      .toList();

  final uniqueContainers = {
    for (final item in containers)
      '${item['site']}|${item['container']}': item,
  }.values.toList();

  if (!mounted) return;

  final selected = await showDialog<Map<String, String>>(
  context: context,
  builder: (dialogContext) => Directionality(
    textDirection: TextDirection.rtl,
    child: SimpleDialog(
      title: const Text('בחר מחסן / מכולה'),
      children: uniqueContainers.map((item) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, item),
          child: Text('${item['site']} — ${item['container']}'),
        );
      }).toList(),
    ),
  ),
);
  if (selected == null) return;

  rows.removeWhere(
    (item) =>
        item['site_name']?.toString() != selected['site'] ||
        item['container_code']?.toString() != selected['container'],
  );
}
        debugPrint('EXCEL ROWS: ${rows.length}');

    final excel = Excel.createExcel();
excel.rename('Sheet1', 'Inventory');
final sheet = excel['Inventory'];
sheet.isRTL = true;

    sheet.appendRow([
      TextCellValue('אתר'),
      TextCellValue('מכולה'),
      TextCellValue('שם ציוד'),
      TextCellValue('מספר סידורי'),
      TextCellValue('עלות'),
      TextCellValue('סטטוס'),
      TextCellValue('נראה לאחרונה'),
    ]);

    for (final item in rows) {
      sheet.appendRow([
        TextCellValue(item['site_name']?.toString() ?? ''),
        TextCellValue(item['container_code']?.toString() ?? ''),
        TextCellValue(item['item_name']?.toString() ?? ''),
        TextCellValue(item['serial_number']?.toString() ?? ''),
        TextCellValue(item['cost']?.toString() ?? ''),
        TextCellValue(item['status']?.toString() ?? ''),
        TextCellValue(
  item['last_seen'] == null
      ? 'לא נראה'
      : '${DateTime.parse(item['last_seen'].toString()).toLocal().day.toString().padLeft(2, '0')}/${DateTime.parse(item['last_seen'].toString()).toLocal().month.toString().padLeft(2, '0')}/${DateTime.parse(item['last_seen'].toString()).toLocal().year} ${DateTime.parse(item['last_seen'].toString()).toLocal().hour.toString().padLeft(2, '0')}:${DateTime.parse(item['last_seen'].toString()).toLocal().minute.toString().padLeft(2, '0')}',
),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'EQP_Inventory',
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  } catch (e) {
    debugPrint('Excel export error: $e');
  }
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

          final inventoryTest = await supabase
    .from('v_inventory_export')
    .select('item_id, item_name, site_name, container_code');

debugPrint('EQP INVENTORY TEST: ${inventoryTest.length} items');
debugPrint('EQP INVENTORY DATA: $inventoryTest');

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

  void openInactiveItems() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InactiveItemsPage(),
      ),
    ).then((_) => loadDashboard());
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
             : SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                      DashboardHeader(
  onRefresh: () {
    loadCustomerName();
    loadDashboard();
  },
  onLogout: () async {
    await Supabase.instance.client.auth.signOut();
  },
),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.business_outlined, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                customerName != null
                                    ? 'לקוח: $customerName'
                                    : customerNameError ?? 'טוען פרטי לקוח...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DashboardActionBar(
  onInventory: openInventoryFlow,
  onDeadStock: openDeadStockFlow,
  onInactiveItems: openInactiveItems,
),
const SizedBox(height: 12),

ElevatedButton.icon(
  onPressed: exportInventoryExcel,
  icon: const Icon(Icons.download),
  label: const Text('ייצוא מלאי לאקסל'),
),
const SizedBox(height: 12),

ElevatedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EquipmentTransfersPage(),
      ),
    );
  },
  icon: const Icon(Icons.swap_horiz),
  label: const Text('העברות ציוד לאישור'),
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 16),
    textStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    ),
  ),
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
                        SizedBox(
  height: 400,
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