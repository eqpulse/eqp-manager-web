
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetectedFromOtherPage extends StatefulWidget {
  final String siteName;
  final String storageCode;
  final String storageName;

  const DetectedFromOtherPage({
    super.key,
    required this.siteName,
    required this.storageCode,
    required this.storageName,
  });

  @override
  State<DetectedFromOtherPage> createState() =>
      _DetectedFromOtherPageState();
}

class _DetectedFromOtherPageState
    extends State<DetectedFromOtherPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> alerts = [];

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    try {
      final sites = await supabase
    .from('sites')
    .select('id')
    .eq('site_name', widget.siteName);

if (sites.length != 1) {
  throw Exception('לא נמצא אתר יחיד המתאים לשם האתר');
}

final containers = await supabase
    .from('containers')
    .select('id')
    .eq('container_code', widget.storageCode)
    .eq('site_id', sites.first['id']);

      if (containers.length != 1) {
        throw Exception(
          'לא נמצא מחסן יחיד המתאים לאתר ולמספר המחסן',
        );
      }

      final containerId = containers.first['id'] as String;

     final data = await supabase
    .from('equipment_alerts')
    .select('''
      id,
      first_detected_at,
      last_detected_at,
      detection_count,
      status,
      items!equipment_alerts_item_id_fkey(
        item_name,
        serial_number
      ),
      containers!equipment_alerts_expected_container_id_fkey(
        container_code
      )
    ''')
    .eq('detected_container_id', containerId)
    .inFilter('status', ['suspected', 'open'])
    .order('last_detected_at', ascending: false);
      if (!mounted) return;

      setState(() {
        alerts = List<Map<String, dynamic>>.from(data);
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> reviewAlert(
  String alertId,
  bool approve,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(approve ? 'אישור מעבר ציוד' : 'דחיית מעבר ציוד'),
      content: Text(
        approve
            ? 'האם לאשר את העברת הציוד למחסן ${widget.storageCode}?'
            : 'האם לדחות את מעבר הציוד?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(approve ? 'אשר מעבר' : 'דחה מעבר'),
        ),
      ],
    ),
  );

  if (confirmed != true || !mounted) return;

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
          approve ? 'מעבר הציוד אושר בהצלחה' : 'המעבר נדחה',
        ),
      ),
    );

    await loadAlerts();
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('שגיאה בטיפול בהתראה: $e')),
    );
  }
}

  String formatDate(dynamic value) {
    if (value == null) return 'לא ידוע';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'לא ידוע';

    final local = date.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ציוד שזוהה ממחסן אחר'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.siteName} | ${widget.storageName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : errorMessage != null
                        ? Center(
                            child: Text(
                              'שגיאה בטעינת הנתונים:\n$errorMessage',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : alerts.isEmpty
                            ? const Center(
                                child: Text(
                                  'לא נמצאו התראות על ציוד ממחסן אחר',
                                ),
                              )
                            : ListView.builder(
                                itemCount: alerts.length,
                                itemBuilder: (context, index) {
                                  final alert = alerts[index];

                                  final item =
                                      alert['items'] as Map<String, dynamic>? ??
                                          {};

                                  final source = alert['containers']
                                          as Map<String, dynamic>? ??
                                      {};

                                  final site = source['sites']
                                          as Map<String, dynamic>? ??
                                      {};

                                  final status =
                                      alert['status']?.toString() ?? '';

                                  final isOpen = status == 'open';

                                  return Card(
                                    margin: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['item_name']?.toString() ??
                                                'ציוד ללא שם',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'מספר סידורי: ${item['serial_number'] ?? '-'}',
                                          ),
                                          Text(
                                            'מחסן משויך: ${source['container_code'] ?? '-'}',
                                          ),
                                          Text(
                                            'אתר מקור: ${site['site_name'] ?? '-'}',
                                          ),
                                          Text(
                                            'זיהוי אחרון: ${formatDate(alert['last_detected_at'])}',
                                          ),
                                          Text(
                                            'מספר זיהויים: ${alert['detection_count'] ?? 0}',
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isOpen
                                                ? 'התראה מאומתת — ממתינה לבדיקה'
                                                : 'זיהוי ראשוני',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isOpen
                                                  ? Colors.red
                                                  : Colors.orange,
                                            ),
                                          ),
                                          if (isOpen) ...[
  const SizedBox(height: 16),
  Row(
    children: [
      ElevatedButton.icon(
        onPressed: () {
          reviewAlert(
            alert['id'].toString(),
            true,
          );
        },
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('אשר מעבר'),
      ),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: () {
          reviewAlert(
            alert['id'].toString(),
            false,
          );
        },
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('דחה מעבר'),
      ),
    ],
  ),
],
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
