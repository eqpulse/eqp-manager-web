import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryPage extends StatefulWidget {
  final String siteName;
  final String storageCode;
  final String storageName;

  const InventoryPage({
    super.key,
    required this.siteName,
    required this.storageCode,
    required this.storageName,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> items = [];
  final ScrollController _itemsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  Future<void> loadInventory() async {
    try {
      final response = await supabase
          .from('v_container_inventory_live')
          .select()
          .eq('site_name', widget.siteName)
          .eq('container_code', widget.storageCode)
          .order('item_name');

          debugPrint('Inventory rows: ${response.length}');

      setState(() {
        items = List<Map<String, dynamic>>.from(response);
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'שגיאה בטעינת ספירת מלאי';
      });
      debugPrint('Inventory error: $e');
    }
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String money(dynamic value) {
    final formatter = intl.NumberFormat.currency(
      locale: 'en_US',
      symbol: '₪',
      decimalDigits: 0,
    );
    return formatter.format(toDouble(value));
  }

  double get totalValue =>
      items.fold(0, (sum, item) => sum + toDouble(item['cost']));

  String get scanDate {
    if (items.isEmpty) return '--';
    final raw = items.first['last_seen'];
    if (raw == null) return '--';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return intl.DateFormat('dd/MM/yyyy   HH:mm').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

 
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: Text('ספירת מלאי ${widget.storageCode}'),
          centerTitle: true,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.storageName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.siteName),
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            child: Wrap(
                              spacing: 32,
                              runSpacing: 10,
                              alignment: WrapAlignment.start,
                              children: [
                                _InfoLine(
                                  icon: Icons.calendar_month_outlined,
                                  label: 'תאריך ספירה',
                                  value: scanDate,
                                ),
                                _InfoLine(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'פריטים שנספרו',
                                  value: '${items.length}',
                                ),
                                _InfoLine(
                                  icon: Icons.payments_outlined,
                                  label: 'שווי מלאי',
                                  value: money(totalValue),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'פריטים שנקלטו בקריאה האחרונה',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            child: Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          'פריט',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'תג BLE',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'שווי',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: items.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'לא נמצאו פריטים בספירה האחרונה',
                                          ),
                                        )
                                      : Scrollbar(
                                          controller: _itemsScrollController,
                                          thumbVisibility: true,
                                          child: ListView.separated(
                                            controller: _itemsScrollController,
                                            primary: false,
                                            itemCount: items.length,
                                            separatorBuilder: (_, __) =>
                                                const Divider(height: 1),
                                            itemBuilder: (context, index) {
                                            final item = items[index];
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      item['item_name']
                                                              ?.toString() ??
                                                          '',
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      item['ble_mac_address']
                                                              ?.toString() ??
                                                          '',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      money(item['cost']),
                                                      textAlign: TextAlign.end,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            },
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
