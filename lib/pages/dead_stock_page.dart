import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

class DeadStockPage extends StatefulWidget {
  final String siteName;
  final String storageCode;
  final String storageName;

  const DeadStockPage({
    super.key,
    required this.siteName,
    required this.storageCode,
    required this.storageName,
  });

  @override
  State<DeadStockPage> createState() => _DeadStockPageState();
}

class _DeadStockPageState extends State<DeadStockPage> {
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
          .from('v_unseen_items')
          .select()
          .eq('site_name', widget.siteName)
          .eq('container_code', widget.storageCode)
          .order('days_unseen', ascending: false);

      setState(() {
        items = List<Map<String, dynamic>>.from(response);
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'שגיאה בטעינת מלאי שלא זז';
      });
      debugPrint('DeadStock error: $e');
    }
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
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
      return intl.DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  double get totalValue =>
      items.fold(0, (sum, item) => sum + toDouble(item['item_value']));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: Text('מלאי שלא זז ${widget.storageCode}'),
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
                        Text(widget.storageName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(widget.siteName),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            child: Wrap(
                              spacing: 32,
                              runSpacing: 10,
                              children: [
                                _InfoLine(icon: Icons.access_time, label: 'פריטים שלא זזו', value: '${items.length}'),
                                _InfoLine(icon: Icons.payments_outlined, label: 'שווי', value: money(totalValue)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('מלאי שלא זז', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Card(
                            child: Column(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 4, child: Text('פריט', style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('ימים', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text('שווי', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 3, child: Text('נראה לאחרונה', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: items.isEmpty
                                      ? const Center(child: Text('אין מלאי שלא זז'))
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
                                                  Expanded(flex: 2, child: Text('${toInt(item['days_unseen'])}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                  Expanded(flex: 2, child: Text(money(item['item_value']), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                  Expanded(flex: 3, child: Text(formatDate(item['last_seen_at']), textAlign: TextAlign.center)),
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

  const _InfoLine({required this.icon, required this.label, required this.value});

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
