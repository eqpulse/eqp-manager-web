
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'site_page.dart';

class AllSitesPage extends StatefulWidget {
  const AllSitesPage({super.key});

  @override
  State<AllSitesPage> createState() => _AllSitesPageState();
}

class _AllSitesPageState extends State<AllSitesPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? errorMessage;
  String customerName = '';
  List<Map<String, dynamic>> sites = [];

  @override
  void initState() {
    super.initState();
    loadSites();
  }

  Future<void> loadSites() async {
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
        throw Exception('לא נמצא שיוך לקוח למשתמש');
      }

      final customer = await supabase
          .from('customers')
          .select('company_name')
          .eq('id', customerId)
          .maybeSingle();

      final response = await supabase
          .from('sites')
          .select('id, site_name')
          .eq('customer_id', customerId)
          .order('site_name');

      if (!mounted) return;

      setState(() {
        customerName =
            customer?['company_name']?.toString() ?? '';
        sites = List<Map<String, dynamic>>.from(response);
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = 'שגיאה בטעינת האתרים: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: const Text('אתרים ומחסנים'),
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
                          customerName,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'בחר אתר',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: sites.isEmpty
                              ? const Center(
                                  child: Text(
                                    'לא נמצאו אתרים ללקוח',
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: sites.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final site = sites[index];

                                    final siteName =
                                        site['site_name']?.toString() ?? '';

                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.location_on_outlined,
                                        ),
                                        title: Text(siteName),
                                        trailing: const Icon(
                                          Icons.chevron_left,
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SitePage(
                                                siteName: siteName,
                                                clientName: customerName,
                                              ),
                                            ),
                                          );
                                        },
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
