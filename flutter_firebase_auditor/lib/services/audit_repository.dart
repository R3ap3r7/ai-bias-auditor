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
      final repository = AuditRepository._(
        enabled: true,
        disabledReason: '',
        firestore: FirebaseFirestore.instance,
        auth: auth,
      );
      await repository._completeRedirectSignIn();
      if (auth.currentUser != null) {
        await repository._upsertUserProfile(auth.currentUser!);
      }
      return repository;
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
          .collection('users')
          .doc(user.uid)
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
    UserCredential credential;
    try {
      credential = await auth!.signInWithPopup(provider);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'popup-blocked' &&
          error.code != 'popup-closed-by-user' &&
          error.code != 'cancelled-popup-request') {
        rethrow;
      }
      await auth!.signInWithRedirect(provider);
      return;
    }
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
    final userRef = firestore!.collection('users').doc(user.uid);
    final auditRef = userRef.collection('auditRuns').doc(record.id);
    await auditRef.set(record.toFirestore(user.uid));
    await userRef.collection('reports').doc(record.id).set({
      'ownerId': user.uid,
      'createdAt': Timestamp.now(),
      'reportId': record.reportId,
      'result': _sanitizeResultForFirestore(rawResult),
    });

    final model = _readMap(rawResult['model']);
    final trace = _readMap(model['audit_trace']);
    final records = _readList(trace['records']).take(20).toList();
    final batch = firestore!.batch();
    var traceWrites = 0;
    for (final entry in records) {
      final recordMap = _readMap(entry);
      if (recordMap.isEmpty) continue;
      final rowId = recordMap['row_id']?.toString() ??
          'trace-${DateTime.now().microsecondsSinceEpoch}';
      batch.set(
          auditRef.collection('traceRecords').doc(_firestoreDocId(rowId)), {
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
      traceWrites += 1;
    }
    if (traceWrites > 0) {
      await batch.commit();
    }
  }

  Future<void> _completeRedirectSignIn() async {
    if (!enabled || auth == null) return;
    try {
      final credential = await auth!.getRedirectResult();
      final user = credential.user ?? auth!.currentUser;
      if (user != null) {
        await _upsertUserProfile(user);
      }
    } on FirebaseAuthException {
      // The interactive sign-in surface reports actionable errors to the user.
    }
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

String _firestoreDocId(String value) {
  final sanitized = value
      .trim()
      .replaceAll(RegExp(r'[/#?\[\]*]'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
  if (sanitized.isEmpty) {
    return 'trace-${DateTime.now().microsecondsSinceEpoch}';
  }
  return sanitized.length <= 120 ? sanitized : sanitized.substring(0, 120);
}

Map<String, dynamic> _sanitizeResultForFirestore(Map<String, dynamic> result) {
  final cloned = jsonSafeMap(result);
  final model = _readMap(cloned['model']);
  final trace = _readMap(model['audit_trace']);
  final records = _readList(trace['records']).take(20).map((entry) {
    final record = _readMap(entry);
    record.remove('raw_row');
    return record;
  }).toList();
  trace['records'] = records;
  model['audit_trace'] = trace;
  cloned['model'] = model;
  cloned['post_audit'] = model;
  return cloned;
}

Map<String, dynamic> jsonSafeMap(Map<String, dynamic> value) {
  return value.map((key, inner) {
    if (inner is Map<String, dynamic>) {
      return MapEntry(key, jsonSafeMap(inner));
    }
    if (inner is Map) {
      return MapEntry(
        key,
        jsonSafeMap(inner
            .map((mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue))),
      );
    }
    if (inner is List) {
      return MapEntry(
          key,
          inner.map((item) {
            if (item is Map<String, dynamic>) return jsonSafeMap(item);
            if (item is Map) {
              return jsonSafeMap(item.map(
                  (mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue)));
            }
            return item;
          }).toList());
    }
    return MapEntry(key, inner);
  });
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
