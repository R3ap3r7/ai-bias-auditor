import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/audit/audit_screen.dart';
import 'services/audit_repository.dart';
import 'services/backend_client.dart';
import 'core/theme/app_theme.dart';

class AiBiasAuditorApp extends StatelessWidget {
  const AiBiasAuditorApp({
    super.key,
    required this.auditRepository,
    required this.backendClient,
  });

  final AuditRepository auditRepository;
  final AuditBackendClient backendClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Themis — AI Fairness Auditor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/audit': (context) => const AuditScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/audit') {
          final args = settings.arguments as String?;
          return MaterialPageRoute(builder: (context) => AuditScreen(demoId: args));
        }
        return null;
      },
    );
  }
}
