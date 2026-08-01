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
          .from('v_missing_items_status')
          .select()
          .eq('site_name', widget.siteName)
          .eq('container_code', widget.storageCode)
          .order('cost', ascending: false);

      if (!mounted) return;

      setState(() {
        items = List<Map<String, dynamic>>.from(response);
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

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

  String statusLabel(dynamic value) {
    switch (value?.toString()) {
      case 'repair':
        return 'בתיקון';
      case 'loaned':
        return 'בהשאלה';
      case 'equipment_center':
        return 'במרכז ציוד';
      case 'inactive':
        return 'יצא משימוש';
      case 'missing':
        return 'חסר';
      default:
        return 'חסר';
    }
  }

  Color statusColor(dynamic value) {
    switch (value?.toString()) {
      case 'repair':
        return Colors.orange;
      case 'loaned':
        return Colors.amber.shade800;
      case 'equipment_center':
        return Colors.blue;
      case 'inactive':
        return Colors.blueGrey;
      default:
        return Colors.red;
    }
  }

  double get totalValue =>
      items.fold(0, (sum, item) => sum + toDouble(item['cost']));

  Future<void> showStatusDialog(Map<String, dynamic> item) async {
    final itemId = item['item_id']?.toString();

    if (itemId == null || itemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא נמצא מזהה לפריט')),
      );
      return;
    }

    final currentStatus = item['status']?.toString();

    String selectedStatus = {
      'missing',
      'repair',
      'loaned',
      'equipment_center',
      'inactive',
    }.contains(currentStatus)
        ? currentStatus!
        : 'missing';

    final noteController = TextEditingController(
      text: item['status_note']?.toString() ?? '',
    );

    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveStatus() async {
              if (saving) return;

              setDialogState(() {
                saving = true;
              });

              final note = noteController.text.trim();
              const updatedBy = 'manager_web';

              try {
                final result = await supabase.rpc(
                  'update_item_business_status',
                  params: {
                    'p_item_id': itemId,
                    'p_status': selectedStatus,
                    'p_note': note,
                    'p_updated_by': updatedBy,
                  },
                );

                debugPrint('RPC RESULT: $result');

                if (!mounted) return;

                // שומרים את ה-Messenger לפני סגירת חלון הדיאלוג,
                // כדי לא להשתמש ב-context שכבר יצא מעץ ה-Widgets.
                final messenger = ScaffoldMessenger.of(this.context);

                Navigator.of(dialogContext).pop();
                await loadItems();

                if (!mounted) return;

                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('הסטטוס עודכן בהצלחה'),
                  ),
                );
              } catch (e) {
                debugPrint('Status update error: $e');

                if (!dialogContext.mounted) return;

                setDialogState(() {
                  saving = false;
                });

                if (!mounted) return;

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('שגיאה בעדכון הסטטוס: $e'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                item['item_name']?.toString() ?? 'עדכון פריט',
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('אתר: ${widget.siteName}'),
                    Text('מכולה: ${widget.storageCode}'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'סטטוס',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'missing',
                          child: Text('חסר'),
                        ),
                        DropdownMenuItem(
                          value: 'repair',
                          child: Text('בתיקון'),
                        ),
                        DropdownMenuItem(
                          value: 'loaned',
                          child: Text('בהשאלה'),
                        ),
                        DropdownMenuItem(
                          value: 'equipment_center',
                          child: Text('במרכז ציוד'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('יצא משימוש'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedStatus = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      enabled: !saving,
                      maxLength: 200,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'הערה',
                        hintText: 'לדוגמה: נשלח למעבדת מקיטה',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('ביטול'),
                ),
                FilledButton(
                  onPressed: saving ? null : saveStatus,
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('שמור'),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: Text('ציוד חסר ${widget.storageCode}'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: loadItems,
              icon: const Icon(Icons.refresh),
              tooltip: 'רענון',
            ),
          ],
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
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'סטטוס',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'נראה לאחרונה',
                                          textAlign: TextAlign.center,
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
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = items[index];

                                            return InkWell(
                                              onTap: () {
                                                showStatusDialog(item);
                                              },
                                              child: Padding(
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
                                                        textAlign:
                                                            TextAlign.end,
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        statusLabel(
                                                          item['status'],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: statusColor(
                                                            item['status'],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        formatDate(
                                                          item['last_seen'],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
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
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.black54),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
