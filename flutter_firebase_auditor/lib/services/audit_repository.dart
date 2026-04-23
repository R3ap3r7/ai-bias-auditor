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
  });

  final bool enabled;
  final String disabledReason;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  User? get currentUser => auth?.currentUser;

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
      return AuditRepository._(
        enabled: true,
        disabledReason: '',
        firestore: FirebaseFirestore.instance,
        auth: auth,
      );
    } catch (error) {
      return AuditRepository._(
        enabled: false,
        disabledReason: 'Firebase initialization failed: $error',
      );
    }
  }

  Stream<List<AuditRecord>> watchRecentAudits() {
    if (!enabled || firestore == null || auth == null) {
      return Stream.value(const []);
    }

    return auth!.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(const <AuditRecord>[]);
      }

      return firestore!
          .collection('auditRuns')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(25)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(AuditRecord.fromFirestore).toList(),
          );
    });
  }

  Stream<User?> authStateChanges() {
    if (!enabled || auth == null) {
      return Stream.value(null);
    }
    return auth!.authStateChanges();
  }

  Future<void> signInWithGoogle() async {
    if (!enabled || auth == null || firestore == null) {
      throw StateError(disabledReason);
    }

    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    final credential = await auth!.signInWithPopup(provider);
    final user = credential.user;
    if (user != null) {
      await _upsertUserProfile(user);
    }
  }

  Future<void> signOut() async {
    if (!enabled || auth == null) {
      return;
    }
    await auth!.signOut();
  }

  Future<void> saveAudit({
    required AuditRecord record,
    required Map<String, dynamic> rawResult,
  }) async {
    final user = currentUser;
    if (!enabled || firestore == null || user == null) {
      return;
    }

    await _upsertUserProfile(user);
    final auditRef = firestore!.collection('auditRuns').doc(record.id);
    await auditRef.set(record.toFirestore(user.uid));

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

  Future<void> _upsertUserProfile(User user) async {
    if (firestore == null) return;

    final userRef = firestore!.collection('users').doc(user.uid);
    final existing = await userRef.get();
    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoURL,
      'providerIds':
          user.providerData.map((provider) => provider.providerId).toList(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await userRef.set(data, SetOptions(merge: true));
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
