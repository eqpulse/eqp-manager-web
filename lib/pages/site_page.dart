
import 'storage_unit_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SitePage extends StatefulWidget {
  final String siteName;
  final String clientName;

  const SitePage({
    super.key,
    required this.siteName,
    required this.clientName,
  });

  @override
  State<SitePage> createState() => _SitePageState();
}

class _SitePageState extends State<SitePage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  List<Map<String, dynamic>> storageUnits = [];

  @override
  void initState() {
    super.initState();
    loadStorageUnits();
  }

  Future<void> loadStorageUnits() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('אין משתמש מחובר');
      }

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
          .select('id')
          .eq('customer_id', customerId)
          .eq('site_name', widget.siteName);

      if (siteRows.length != 1) {
        throw Exception('לא נמצא אתר יחיד מתאים');
      }

      final siteId = siteRows.first['id'];

      // Load every storage unit belonging to this site.
      final containers = await supabase
          .from('containers')
          .select('id, container_code, location_description')
          .eq('customer_id', customerId)
          .eq('site_id', siteId)
          .order('container_code');

      // Missing-equipment figures remain sourced from the existing view.
      final missingRows = await supabase
          .from('v_missing_by_container_live')
          .select()
          .eq('site_name', widget.siteName);

      final missingByCode = <String, Map<String, dynamic>>{};

      for (final row in missingRows) {
        final code = row['container_code']?.toString() ?? '';
        if (code.isNotEmpty) {
          missingByCode[code] = Map<String, dynamic>.from(row);
        }
      }

      final units = <Map<String, dynamic>>[];

      for (final container in containers) {
        final code = container['container_code']?.toString() ?? '';
        final missing = missingByCode[code];

        units.add({
          'container_code': code,
          'storage_name':
              container['location_description']?.toString().trim().isNotEmpty == true
                  ? container['location_description'].toString()
                  : code,
          'missing_items': missing?['missing_items'] ?? 0,
          'missing_value': missing?['missing_value'] ?? 0,
        });
      }

      if (!mounted) return;

      setState(() {
        storageUnits = units;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      debugPrint('SitePage error: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'שגיאה בטעינת המחסנים: $e';
      });
    }
  }

  String money(dynamic value) {
    final n = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;

    return '₪${n.toStringAsFixed(0)}';
  }

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: Text(widget.siteName),
          centerTitle: true,
        ),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : errorMessage != null
                ? Center(
                    child: Text(errorMessage!),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.clientName,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'יחידות אחסון',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                                        flex: 3,
                                        child: Text(
                                          'קוד',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          'שם יחידה',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'חוסרים',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'שווי חסר',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'כניסה',
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
                                  child: storageUnits.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'לא נמצאו מחסנים באתר זה',
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: storageUnits.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final unit = storageUnits[index];

                                            final code =
                                                unit['container_code']
                                                        ?.toString() ??
                                                    '';

                                            final name =
                                                unit['storage_name']
                                                        ?.toString() ??
                                                    code;

                                            return InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        StorageUnitPage(
                                                      siteName:
                                                          widget.siteName,
                                                      clientName:
                                                          widget.clientName,
                                                      storageCode: code,
                                                      storageName: name,
                                                      missingItems: toInt(
                                                        unit['missing_items'],
                                                      ),
                                                      missingValue: money(
                                                        unit['missing_value'],
                                                      ),
                                                    ),
                                                  ),
                                                );
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
                                                      flex: 3,
                                                      child: Text(
                                                        code,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(name),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        '${toInt(unit['missing_items'])}',
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        money(
                                                          unit['missing_value'],
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                    const Expanded(
                                                      flex: 1,
                                                      child: Icon(
                                                        Icons.chevron_left,
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
