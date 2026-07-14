import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dead_stock_page.dart';
import 'inventory_page.dart';

enum StorageSelectionMode {
  inventory,
  deadStock,
}

class SelectStoragePage extends StatefulWidget {
  final StorageSelectionMode mode;

  const SelectStoragePage({
    super.key,
    required this.mode,
  });

  @override
  State<SelectStoragePage> createState() => _SelectStoragePageState();
}

class _SelectStoragePageState extends State<SelectStoragePage> {
  final supabase = Supabase.instance.client;

  bool loadingSites = true;
  bool loadingStorageUnits = false;
  String? errorMessage;

  List<Map<String, dynamic>> sites = [];
  List<Map<String, dynamic>> storageUnits = [];

  String? selectedSiteId;
  String? selectedSiteName;
  String? selectedStorageCode;
  String? selectedStorageName;

  @override
  void initState() {
    super.initState();
    loadSites();
  }

  Future<void> loadSites() async {
    try {
      final response = await supabase
          .from('sites')
          .select('id, site_name, client_name')
          .order('site_name');

      if (!mounted) return;

      setState(() {
        sites = List<Map<String, dynamic>>.from(response);
        loadingSites = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingSites = false;
        errorMessage = 'שגיאה בטעינת האתרים';
      });

      debugPrint('Load sites error: $e');
    }
  }

  Future<void> loadStorageUnits(String siteId) async {
    setState(() {
      loadingStorageUnits = true;
      storageUnits = [];
      selectedStorageCode = null;
      selectedStorageName = null;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('containers')
          .select()
          .eq('site_id', siteId)
          .order('container_code');

      if (!mounted) return;

      setState(() {
        storageUnits = List<Map<String, dynamic>>.from(response);
        loadingStorageUnits = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingStorageUnits = false;
        errorMessage = 'שגיאה בטעינת יחידות האחסון';
      });

      debugPrint('Load storage units error: $e');
    }
  }

  String storageDisplayName(Map<String, dynamic> unit) {
    return unit['display_name']?.toString() ??
        unit['storage_name']?.toString() ??
        unit['location_description']?.toString() ??
        unit['container_code']?.toString() ??
        'יחידת אחסון';
  }

  String get pageTitle =>
      widget.mode == StorageSelectionMode.inventory
          ? 'ספירת מלאי'
          : 'מלאי שלא זז';

  void openSelectedPage() {
    if (selectedSiteName == null || selectedStorageCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לבחור אתר ויחידת אחסון'),
        ),
      );
      return;
    }

    final Widget page = widget.mode == StorageSelectionMode.inventory
        ? InventoryPage(
            siteName: selectedSiteName!,
            storageCode: selectedStorageCode!,
            storageName: selectedStorageName ?? selectedStorageCode!,
          )
        : DeadStockPage(
            siteName: selectedSiteName!,
            storageCode: selectedStorageCode!,
            storageName: selectedStorageName ?? selectedStorageCode!,
          );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(
          title: const Text('EQP'),
          centerTitle: true,
        ),
        body: loadingSites
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  pageTitle,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text('בחר אתר ויחידת אחסון'),
                                const SizedBox(height: 24),
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'אתר',
                                    border: OutlineInputBorder(),
                                  ),
                                  value: selectedSiteId,
                                  items: sites.map((site) {
                                    final siteId =
                                        site['id']?.toString() ?? '';
                                    final siteName =
                                        site['site_name']?.toString() ?? '';
                                    final clientName =
                                        site['client_name']?.toString() ?? '';

                                    return DropdownMenuItem<String>(
                                      value: siteId,
                                      child: Text(
                                        clientName.isEmpty
                                            ? siteName
                                            : '$siteName — $clientName',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (siteId) {
                                    if (siteId == null) return;

                                    final site = sites.firstWhere(
                                      (row) =>
                                          row['id']?.toString() == siteId,
                                    );

                                    setState(() {
                                      selectedSiteId = siteId;
                                      selectedSiteName =
                                          site['site_name']?.toString() ?? '';
                                    });

                                    loadStorageUnits(siteId);
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (loadingStorageUnits)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else
                                  DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'יחידת אחסון',
                                      border: OutlineInputBorder(),
                                    ),
                                    value: selectedStorageCode,
                                    items: storageUnits.map((unit) {
                                      final code = unit['container_code']
                                              ?.toString() ??
                                          '';
                                      final name = storageDisplayName(unit);

                                      return DropdownMenuItem<String>(
                                        value: code,
                                        child: Text('$code — $name'),
                                      );
                                    }).toList(),
                                    onChanged: selectedSiteId == null
                                        ? null
                                        : (code) {
                                            if (code == null) return;

                                            final unit =
                                                storageUnits.firstWhere(
                                              (row) =>
                                                  row['container_code']
                                                      ?.toString() ==
                                                  code,
                                            );

                                            setState(() {
                                              selectedStorageCode = code;
                                              selectedStorageName =
                                                  storageDisplayName(unit);
                                            });
                                          },
                                  ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: openSelectedPage,
                                  icon: Icon(
                                    widget.mode ==
                                            StorageSelectionMode.inventory
                                        ? Icons.inventory_2_outlined
                                        : Icons.access_time,
                                  ),
                                  label: Text('פתח $pageTitle'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
