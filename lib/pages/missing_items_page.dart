import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

class MissingItemsPage extends StatefulWidget {
  final String siteName;
  final String storageCode;
  final String storageName;

  const MissingItemsPage({
    super.key,
    required this.siteName,
    required this.storageCode,
    required this.storageName,
  });

  @override
  State<MissingItemsPage> createState() => _MissingItemsPageState();
}

class _MissingItemsPageState extends State<MissingItemsPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    try {
      final response = await supabase
          .from('v_missing_items_live')
          .select()
          .eq('site_name', widget.siteName)
          .eq('container_code', widget.storageCode)
          .order('cost', ascending: false);

      setState(() {
        items = List<Map<String, dynamic>>.from(response);
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'שגיאה בטעינת ציוד חסר';
      });
      debugPrint('MissingItems error: $e');
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

  String formatDate(dynamic value) {
    if (value == null) return '--';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return intl.DateFormat('dd/MM/yyyy   HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  double get totalValue =>
      items.fold(0, (sum, item) => sum + toDouble(item['cost']));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: Text('ציוד חסר ${widget.storageCode}'),
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
                        Text(
                          widget.storageName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(widget.siteName),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Wrap(
                              spacing: 32,
                              runSpacing: 10,
                              children: [
                                _InfoLine(
                                  icon: Icons.warning_amber_outlined,
                                  label: 'פריטים חסרים',
                                  value: '${items.length}',
                                  color: Colors.red,
                                ),
                                _InfoLine(
                                  icon: Icons.payments_outlined,
                                  label: 'שווי חסר',
                                  value: money(totalValue),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'פריטים חסרים',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                      Expanded(flex: 4, child: Text('פריט', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 3, child: Text('תג BLE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('שווי', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 3, child: Text('נראה לאחרונה', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: items.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'אין ציוד חסר כרגע',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: items.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                children: [
                                                  Expanded(flex: 4, child: Text(item['item_name']?.toString() ?? '')),
                                                  Expanded(flex: 3, child: Text(item['ble_mac_address']?.toString() ?? '', textAlign: TextAlign.center)),
                                                  Expanded(flex: 2, child: Text(money(item['cost']), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                                                  Expanded(flex: 3, child: Text(formatDate(item['last_seen']), textAlign: TextAlign.center)),
                                                ],
                                              ),
                                            );
                                          },
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
  final Color? color;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.blueGrey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: effectiveColor),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.black54)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: effectiveColor)),
      ],
    );
  }
}
