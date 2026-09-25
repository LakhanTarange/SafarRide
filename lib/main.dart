import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'config/theme.dart';
import 'firebase_options.dart';
import 'screens/auth/welcome_page.dart';
import 'screens/customer/customer_dashboard.dart';
import 'screens/partner/partner_dashboard.dart';
import 'screens/profile/profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SafarRideApp());
}

class SafarRideApp extends StatelessWidget {
  const SafarRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      home: const WelcomePage(),
      routes: {
        '/customer-dashboard': (context) =>
            const CustomerDashboard(),
        '/partner-dashboard': (context) =>
            const PartnerDashboard(),
        '/profile': (context) =>
            const ProfilePage(),
      },
    );
  }
}