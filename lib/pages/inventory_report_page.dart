import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({super.key});

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String? error;
  String scope = 'all'; // all or site
  String? selectedSite;
  String? selectedContainerKey;
  List<Map<String, dynamic>> inventory = [];
  List<Map<String, dynamic>> missing = [];
  List<String> availableSites = [];
  Map<String, List<String>> availableContainersBySite = {};

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final inventoryResult = await supabase
          .from('v_inventory_export').select().order('site_name');
      final missingResult = await supabase
          .from('v_missing_items_export').select().order('site_name');
      // Populate selection lists from the customer's actual sites and containers,
      // including those without equipment in the export views.
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('אין משתמש מחובר');
      final membership = await supabase
          .from('eqp_users')
          .select('customer_id')
          .eq('id', user.id)
          .eq('active', true)
          .maybeSingle();
      final customerId = membership?['customer_id']?.toString();
      if (customerId == null || customerId.isEmpty) {
        throw Exception('לא נמצא שיוך לקוח');
      }
      final siteRows = await supabase
          .from('sites')
          .select('id, site_name')
          .eq('customer_id', customerId)
          .order('site_name');
      final containerRows = await supabase
          .from('containers')
          .select('site_id, container_code')
          .eq('customer_id', customerId)
          .order('container_code');
      final siteNamesById = <String, String>{};
      final names = <String>{};
      for (final site in siteRows) {
        final id = site['id']?.toString() ?? '';
        final name = site['site_name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          siteNamesById[id] = name;
          names.add(name);
        }
      }
      final codesBySite = <String, Set<String>>{};
      for (final container in containerRows) {
        final site = siteNamesById[container['site_id']?.toString()];
        final code = container['container_code']?.toString() ?? '';
        if (site != null && code.isNotEmpty) {
          codesBySite.putIfAbsent(site, () => <String>{}).add(code);
        }
      }
      if (!mounted) return;
      setState(() {
        availableSites = names.toList()..sort();
        availableContainersBySite = {
          for (final entry in codesBySite.entries)
            entry.key: entry.value.toList()..sort(),
        };
        inventory = List<Map<String, dynamic>>.from(inventoryResult);
        missing = List<Map<String, dynamic>>.from(missingResult);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'שגיאה בטעינת הדוח: $e';
      });
    }
  }

  String siteOf(Map<String, dynamic> item) =>
      item['site_name']?.toString() ?? '';
  String containerOf(Map<String, dynamic> item) =>
      item['container_code']?.toString() ?? '';
  String containerKey(Map<String, dynamic> item) =>
      '${siteOf(item)}|${containerOf(item)}';
  String display(dynamic value) =>
      value == null || value.toString().isEmpty ? '--' : value.toString();

  String date(dynamic value) {
    if (value == null) return '--';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return display(value);
    final dt = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  bool inScope(Map<String, dynamic> item) {
    if (scope == 'site') {
      return siteOf(item) == selectedSite &&
          (selectedContainerKey == null ||
              containerKey(item) == selectedContainerKey);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sites = availableSites;
    final containers = availableContainersBySite[selectedSite] ?? <String>[];

    final hasSelection = scope == 'all' || selectedSite != null;
    final scopedInventory = hasSelection ? inventory.where(inScope).toList() : <Map<String, dynamic>>[];
    final missingRows = hasSelection ? missing.where(inScope).toList() : <Map<String, dynamic>>[];
    final missingIds = missingRows
        .map((i) => i['item_id']?.toString())
        .whereType<String>()
        .toSet();
    final activeRows = scopedInventory
        .where((i) => !missingIds.contains(i['item_id']?.toString()))
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F4FA),
          appBar: AppBar(
            title: const Text('צפייה בדוח מלאי'),
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: loadReport,
                icon: const Icon(Icons.refresh),
                tooltip: 'רענון',
              ),
            ],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text(error!))
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'בחירת היקף הדוח',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: scope,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'היקף',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'all', child: Text('כל החברה')),
                                      DropdownMenuItem(value: 'site', child: Text('אתר')),
                                    ],
                                    onChanged: (value) => setState(() {
                                      scope = value ?? 'all';
                                      selectedSite = null;
                                      selectedContainerKey = null;
                                    }),
                                  ),
                                  if (scope != 'all') ...[
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      key: ValueKey('site-$scope-$selectedSite'),
                                      value: selectedSite,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'בחר אתר',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: sites.map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s, overflow: TextOverflow.ellipsis),
                                      )).toList(),
                                      onChanged: (value) => setState(() {
                                        selectedSite = value;
                                        selectedContainerKey = null;
                                      }),
                                    ),
                                  ],
                                  if (scope == 'site' && selectedSite != null) ...[
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      key: ValueKey('container-$selectedSite'),
                                      value: selectedContainerKey ?? '__all_containers__',
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'מחסנים באתר',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: [
                                        const DropdownMenuItem<String>(
                                          value: '__all_containers__',
                                          child: Text('כל המחסנים באתר'),
                                        ),
                                        ...containers.map((code) => DropdownMenuItem<String>(
                                          value: '$selectedSite|$code',
                                          child: Text(code, overflow: TextOverflow.ellipsis),
                                        )),
                                      ],
                                      onChanged: (value) => setState(() {
                                        selectedContainerKey = value == '__all_containers__'
                                            ? null : value;
                                      }),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (scope == 'all')
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'כל החברה: ${availableSites.length} אתרים, '
                                '${availableContainersBySite.values.fold<int>(0, (sum, codes) => sum + codes.length)} מחסנים רשומים. '
                                'מחסנים ללא פריטים אינם יוצרים שורות בדוח.',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          const TabBar(tabs: [
                            Tab(text: 'מלאי ציוד'),
                            Tab(text: 'ציוד חסר'),
                          ]),
                          Expanded(
                            child: !hasSelection
                                ? const Center(child: Text('בחר אתר להצגת הדוח'))
                                : TabBarView(children: [
                                    _ReportTable(
                                      rows: activeRows,
                                      headers: const ['אתר', 'מכולה', 'שם ציוד', 'מספר סידורי', 'עלות', 'סטטוס', 'נראה לאחרונה'],
                                      values: (i) => [
                                        siteOf(i), containerOf(i),
                                        display(i['item_name']), display(i['serial_number']),
                                        display(i['cost']), display(i['status']),
                                        date(i['last_seen']),
                                      ],
                                    ),
                                    _ReportTable(
                                      rows: missingRows,
                                      headers: const ['אתר', 'מכולה', 'שם ציוד', 'מספר סידורי', 'עלות', 'סריקה אחרונה'],
                                      values: (i) => [
                                        siteOf(i), containerOf(i),
                                        display(i['item_name']), display(i['serial_number']),
                                        display(i['cost']), date(i['latest_scan_completed_at']),
                                      ],
                                    ),
                                  ]),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final List<String> headers;
  final List<String> Function(Map<String, dynamic>) values;

  const _ReportTable({
    required this.rows,
    required this.headers,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    const widths = <double>[170, 120, 220, 150, 100, 140, 175];
    final totalWidth = widths.take(headers.length).fold<double>(0, (sum, w) => sum + w);

    Widget cells(List<String> texts, {bool heading = false}) => Row(
      children: [
        for (var i = 0; i < texts.length; i++)
          SizedBox(
            width: widths[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                texts[i],
                maxLines: heading ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: heading ? const TextStyle(fontWeight: FontWeight.bold) : null,
              ),
            ),
          ),
      ],
    );

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth > constraints.maxWidth ? totalWidth : constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(children: [
              cells(headers, heading: true),
              const Divider(height: 1),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('אין פריטים להצגה בהיקף שנבחר'))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) => cells(values(rows[index])),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
