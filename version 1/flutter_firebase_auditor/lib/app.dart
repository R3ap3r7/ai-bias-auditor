import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'services/audit_repository.dart';
import 'services/backend_client.dart';
import 'theme/app_theme.dart';

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
      title: 'AI Bias Auditor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: DashboardScreen(
        auditRepository: auditRepository,
        backendClient: backendClient,
      ),
    );
  }
}
