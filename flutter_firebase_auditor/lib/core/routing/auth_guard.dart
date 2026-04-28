import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/audit_repository.dart';

bool isAuthenticated() => AuditRepository.instance.currentUser != null;

void requireAuth(BuildContext context, {String fallbackRoute = '/auth'}) {
  if (!isAuthenticated()) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, fallbackRoute);
      }
    });
  }
}

void requireGuest(BuildContext context, {String fallbackRoute = '/dashboard'}) {
  if (isAuthenticated()) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, fallbackRoute);
      }
    });
  }
}
