import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:supabase_flutter/supabase_flutter.dart';

class InactiveItemsPage extends StatefulWidget {
  const InactiveItemsPage({super.key});

  @override
  State<InactiveItemsPage> createState() => _InactiveItemsPageState();
}

class _InactiveItemsPageState extends State<InactiveItemsPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String? errorMessage;
  String? restoringItemId;
  List<Map<String, dynamic>> items = [];
  final Map<String, String> siteNames = {};
  final Map<String, String> containerCodes = {};

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  Future<void> loadItems() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('items')
          .select('id,item_name,status,status_note,status_updated_at,site_id,container_id,active')
          .eq('active', false)
          .eq('status', 'inactive')
          .order('item_name');

      final loadedItems = List<Map<String, dynamic>>.from(response);

      final siteIds = loadedItems
          .map((e) => e['site_id']?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      final containerIds = loadedItems
          .map((e) => e['container_id']?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      final newSiteNames = <String, String>{};
      final newContainerCodes = <String, String>{};

      if (siteIds.isNotEmpty) {
        final sitesResponse = await supabase
            .from('sites')
            .select('id,site_name')
            .inFilter('id', siteIds);

        for (final row in List<Map<String, dynamic>>.from(sitesResponse)) {
          final id = row['id']?.toString();
          if (id != null) {
            newSiteNames[id] = row['site_name']?.toString() ?? '--';
          }
        }
      }

      if (containerIds.isNotEmpty) {
        final containersResponse = await supabase
            .from('containers')
            .select('id,container_code')
            .inFilter('id', containerIds);

        for (final row in List<Map<String, dynamic>>.from(containersResponse)) {
          final id = row['id']?.toString();
          if (id != null) {
            newContainerCodes[id] = row['container_code']?.toString() ?? '--';
          }
        }
      }

      if (!mounted) return;

      setState(() {
        items = loadedItems;
        siteNames
          ..clear()
          ..addAll(newSiteNames);
        containerCodes
          ..clear()
          ..addAll(newContainerCodes);
        loading = false;
      });
    } catch (e) {
      debugPrint('Inactive items load error: $e');
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'שגיאה בטעינת ציוד לא פעיל';
      });
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return '--';
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return intl.DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (_) {
      return value.toString();
    }
  }

  String siteNameFor(Map<String, dynamic> item) {
    final id = item['site_id']?.toString();
    return id == null ? '--' : (siteNames[id] ?? '--');
  }

  String containerCodeFor(Map<String, dynamic> item) {
    final id = item['container_id']?.toString();
    return id == null ? '--' : (containerCodes[id] ?? '--');
  }

  Future<void> restoreItem(Map<String, dynamic> item) async {
    final itemId = item['id']?.toString();
    final itemName = item['item_name']?.toString() ?? 'הפריט';
    if (itemId == null || itemId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('החזר לשימוש'),
        content: Text(
          'להחזיר את "$itemName" למעקב הפעיל?\n\n'
          'הפריט יחזור כ"חסר" עד שהבקר יזהה אותו בסריקה.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('החזר לשימוש'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => restoringItemId = itemId);

    try {
      await supabase.rpc(
        'update_item_business_status',
        params: {
          'p_item_id': itemId,
          'p_status': 'missing',
          'p_note': 'הוחזר לשימוש לאחר סימון כיצא משימוש',
          'p_updated_by': 'manager_web',
        },
      );

      if (!mounted) return;
      setState(() {
        items.removeWhere((row) => row['id']?.toString() == itemId);
        restoringItemId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$itemName הוחזר לשימוש')),
      );
    } catch (e) {
      debugPrint('Restore inactive item error: $e');
      if (!mounted) return;
      setState(() => restoringItemId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה בהחזרת הפריט לשימוש: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: const Text('ציוד לא פעיל'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: loading ? null : loadItems,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(errorMessage!),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: loadItems,
                          icon: const Icon(Icons.refresh),
                          label: const Text('נסה שוב'),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          color: Colors.amber.shade50,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'מסך זה מיועד לשחזור פריטים שסומנו כ"יצא משימוש".',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'פריטים לא פעילים: ${items.length}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: items.isEmpty
                              ? const Center(
                                  child: Text(
                                    'אין כרגע ציוד לא פעיל',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    final id = item['id']?.toString() ?? '';
                                    final restoring = restoringItemId == id;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['item_name']?.toString() ?? '',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text('אתר: ${siteNameFor(item)}'),
                                                  Text('מכולה: ${containerCodeFor(item)}'),
                                                  Text(
                                                    'הערה: ${item['status_note']?.toString().trim().isNotEmpty == true ? item['status_note'] : '--'}',
                                                  ),
                                                  Text('עודכן: ${formatDate(item['status_updated_at'])}'),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            FilledButton.icon(
                                              onPressed: restoring ? null : () => restoreItem(item),
                                              icon: restoring
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : const Icon(Icons.settings_backup_restore),
                                              label: const Text('החזר לשימוש'),
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
    );
  }
}
