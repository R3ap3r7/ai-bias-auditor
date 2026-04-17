import 'package:flutter/material.dart';

import 'app.dart';
import 'services/audit_repository.dart';
import 'services/backend_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = await AuditRepository.bootstrap();
  final backendClient = AuditBackendClient();

  runApp(
    AiBiasAuditorApp(
      auditRepository: repository,
      backendClient: backendClient,
    ),
  );
}
