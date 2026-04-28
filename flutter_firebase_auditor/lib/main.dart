import 'package:flutter/material.dart';

import 'app.dart';
import 'services/audit_repository.dart';
import 'services/backend_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('Starting bootstrap');
  final repository = await AuditRepository.bootstrap();
  print('Bootstrap finished');
  final backendClient = AuditBackendClient();

  runApp(
    AiBiasAuditorApp(
      auditRepository: repository,
      backendClient: backendClient,
    ),
  );
}
