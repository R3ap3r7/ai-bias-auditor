import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/audit_record.dart';

class AuditRepository {
  const AuditRepository._({
    required this.enabled,
    required this.disabledReason,
    this.firestore,
    this.auth,
    this.ownerId,
  });

  final bool enabled;
  final String disabledReason;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final String? ownerId;

  static Future<AuditRepository> bootstrap() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      return const AuditRepository._(
        enabled: false,
        disabledReason:
            'Firebase config is not set. Build with FIREBASE_* dart-defines to enable audit history.',
      );
    }

    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      final auth = FirebaseAuth.instance;
      final credential = await auth.signInAnonymously();
      return AuditRepository._(
        enabled: true,
        disabledReason: '',
        firestore: FirebaseFirestore.instance,
        auth: auth,
        ownerId: credential.user?.uid,
      );
    } catch (error) {
      return AuditRepository._(
        enabled: false,
        disabledReason: 'Firebase initialization failed: $error',
      );
    }
  }

  Stream<List<AuditRecord>> watchRecentAudits() {
    if (!enabled || firestore == null || ownerId == null) {
      return Stream.value(const []);
    }

    return firestore!
        .collection('auditRuns')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(AuditRecord.fromFirestore).toList(),
        );
  }

  Future<void> saveAudit({
    required AuditRecord record,
    required Map<String, dynamic> rawResult,
  }) async {
    if (!enabled || firestore == null || ownerId == null) {
      return;
    }

    final auditRef = firestore!.collection('auditRuns').doc(record.id);
    await auditRef.set(record.toFirestore(ownerId!));

    final model = _readMap(rawResult['model']);
    final trace = _readMap(model['audit_trace']);
    final records = _readList(trace['records']).take(20).toList();
    final batch = firestore!.batch();
    for (final entry in records) {
      final recordMap = _readMap(entry);
      if (recordMap.isEmpty) continue;
      final rowId = recordMap['row_id']?.toString() ??
          'trace-${DateTime.now().microsecondsSinceEpoch}';
      batch.set(auditRef.collection('traceRecords').doc(rowId), {
        'createdAt': Timestamp.now(),
        'rowId': rowId,
        'prediction': recordMap['prediction'],
        'actual': recordMap['actual'],
        'decisionScore': recordMap['decision_score'],
        'reason': recordMap['risk_reason'] ?? recordMap['reason'],
        'protectedAttributes': recordMap['protected_attributes'],
        'topContributors':
            recordMap['top_contributions'] ?? recordMap['top_contributors'],
      });
    }
    await batch.commit();
  }
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, inner) => MapEntry(key.toString(), inner));
  }
  return {};
}

List<Object?> _readList(Object? value) {
  if (value is List) return value;
  return const [];
}
