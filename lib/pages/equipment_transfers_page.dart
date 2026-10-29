
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EquipmentTransfersPage extends StatefulWidget {
  const EquipmentTransfersPage({super.key});

  @override
  State<EquipmentTransfersPage> createState() =>
      _EquipmentTransfersPageState();
}

class _EquipmentTransfersPageState extends State<EquipmentTransfersPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  String? processingId;
  List<Map<String, dynamic>> alerts = [];

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('equipment_alerts')
          .select('''
            id,
            status,
            detection_count,
            first_detected_at,
            items(item_name),
            source:containers!equipment_alerts_expected_container_id_fkey(container_code),
            destination:containers!equipment_alerts_detected_container_id_fkey(container_code)
          ''')
          .eq('status', 'open')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        alerts = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        loading = false;
      });
    }
  }

  Future<void> reviewAlert(String alertId, bool approve) async {
    setState(() => processingId = alertId);

    try {
      await supabase.rpc(
        'review_equipment_alert',
        params: {
          'p_alert_id': alertId,
          'p_approve': approve,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'ההעברה אושרה' : 'ההעברה נדחתה',
          ),
        ),
      );

      await loadAlerts();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => processingId = null);
      }
    }
  }

  Future<void> confirmReview(String alertId, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'אישור העברה' : 'דחיית העברה'),
        content: Text(
          approve
              ? 'האם לאשר את העברת הציוד למכולה החדשה?'
              : 'האם לדחות את העברת הציוד?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('אישור'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await reviewAlert(alertId, approve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('העברות ציוד לאישור'),
          actions: [
            IconButton(
              onPressed: loading ? null : loadAlerts,
              icon: const Icon(Icons.refresh),
              tooltip: 'רענון',
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text('שגיאה בטעינת התראות: $errorMessage'))
                : alerts.isEmpty
                    ? const Center(
                        child: Text(
                          'אין העברות ציוד הממתינות לאישור',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          final alert = alerts[index];

                          final item = alert['items'] as Map<String, dynamic>?;
                          final source =
                              alert['source'] as Map<String, dynamic>?;
                          final destination =
                              alert['destination'] as Map<String, dynamic>?;

                          final id = alert['id'].toString();
                          final busy = processingId != null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item?['item_name']?.toString() ?? 'ציוד',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'מכולת מקור: ${source?['container_code'] ?? '-'}',
                                  ),
                                  Text(
                                    'זוהה במכולה: ${destination?['container_code'] ?? '-'}',
                                  ),
                                  Text(
                                    'מספר סריקות: ${alert['detection_count']}',
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => confirmReview(id, true),
                                        icon: const Icon(Icons.check),
                                        label: const Text('אשר העברה'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => confirmReview(id, false),
                                        icon: const Icon(Icons.close),
                                        label: const Text('דחה העברה'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
