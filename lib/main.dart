import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kalfayszcbvvepwhzdar.supabase.co',
    anonKey: 'sb_publishable_uG5ASdERlsfn-gLh4XxH8Q_MELAk7Az',
  );

  runApp(const EqManagerApp());
}

class EqManagerApp extends StatelessWidget {
  const EqManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EQP Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: const DashboardPage(),
    );
  }
}