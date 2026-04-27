import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/audit/audit_screen.dart';
import 'services/audit_repository.dart';
import 'services/backend_client.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/auth_guard.dart';
import 'screens/auth/auth_screen.dart';

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
        '/dashboard': (context) {
          requireAuth(context);
          return const DashboardScreen();
        },
        '/auth': (context) {
          requireGuest(context);
          return const AuthScreen();
        },
        '/audit': (context) => const AuditScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/audit') {
          final args = settings.arguments as String?;
          return MaterialPageRoute(builder: (context) => AuditScreen(demoId: args));
        }
        
        if (settings.name != null && settings.name!.startsWith('/audit/results/')) {
          final parts = settings.name!.split('/');
          if (parts.length == 4) {
            final auditId = parts[3];
            return MaterialPageRoute(
              builder: (context) {
                requireAuth(context);
                // Return a loading scaffold that fetches the AuditRecord
                // But the user's Dashboard flow triggers a push() manually 
                // passing rawResults. Why have a route /audit/results/:id 
                // if we just pass the object directly from list tap? 
                // The prompt says: "Tapping an audit item loads full results. Navigate to /audit/results/{auditId}. Pass the AuditRecord to the results screen so it loads from Firestore data, not from a live API call."
                // To pass complex objects in named routes, we use arguments.
                final recordArgs = settings.arguments as Map<String, dynamic>?;
                if (recordArgs == null) {
                  return const Scaffold(body: Center(child: Text('Invalid Audit Record Scope')));
                }
                
                return Scaffold(
                  appBar: const _ResultAppBar(showBack: true), // Placeholder
                  body: Center(child: Text('Results view placeholder for ID: $auditId')),
                );
              }
            );
          }
        }
        return null;
      },
    );
  }
}

class _ResultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  const _ResultAppBar({this.showBack = false});
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Themis Results'),
        leading: showBack ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) : null,
      );
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
