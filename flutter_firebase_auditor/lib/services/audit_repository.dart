import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../firebase_options.dart';
import '../models/audit_record.dart';

class AuditRepository {
  const AuditRepository._({
    required this.enabled,
    required this.disabledReason,
    this.firestore,
    this.auth,
    this.storage,
  });

  final bool enabled;
  final String disabledReason;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final FirebaseStorage? storage;

  User? get currentUser => auth?.currentUser;

  static AuditRepository get instance => _instance!;
  static AuditRepository? _instance;

  static Future<AuditRepository> bootstrap() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      _instance = const AuditRepository._(
        enabled: false,
        disabledReason:
            'Firebase config is not set. Build with FIREBASE_* dart-defines to enable audit history.',
      );
      return _instance!;
    }

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final auth = FirebaseAuth.instance;
      final repository = AuditRepository._(
        enabled: true,
        disabledReason: '',
        firestore: FirebaseFirestore.instance,
        auth: auth,
        storage: FirebaseStorage.instance,
      );
      await repository._completeRedirectSignIn();
      if (auth.currentUser != null) {
        await repository._upsertUserProfile(auth.currentUser!);
      }
      _instance = repository;
      return repository;
    } catch (error) {
      _instance = AuditRepository._(
        enabled: false,
        disabledReason: 'Firebase initialization failed: $error',
      );
      return _instance!;
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
          .collection('audits')
          .orderBy('createdAt', descending: true)
          .limit(50)
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
    if (!enabled || auth == null) return;
    await auth!.signOut();
  }

  Future<void> saveAudit({
    required Map<String, dynamic> rawResult,
    required String datasetName,
    required String datasetSource,
    required String outcomeColumn,
    required List<String> protectedAttributes,
  }) async {
    final user = currentUser;
    if (!enabled || firestore == null || storage == null || user == null) {
      return;
    }

    await _upsertUserProfile(user);
    final auditId = _readString(rawResult['run_id'], fallback: 'audit-${DateTime.now().microsecondsSinceEpoch}');

    String? traceStorageUrl;

    // Extract and upload trace safely
    final model = rawResult['model'] as Map<String, dynamic>?;
    if (model != null && model.containsKey('audit_trace')) {
       final traceData = model['audit_trace'];
       
       // Encode to json bytes
       final bytes = Uint8List.fromList(utf8.encode(jsonEncode(traceData)));
       final ref = storage!.ref('users/${user.uid}/traces/$auditId.json');
       
       await ref.putData(bytes, SettableMetadata(contentType: 'application/json'));
       traceStorageUrl = await ref.getDownloadURL();
       
       // Strip trace from inline document to save space
       model.remove('audit_trace');
       rawResult['model'] = model;
    }

    final record = AuditRecord.fromResult(
      result: rawResult,
      datasetName: datasetName,
      datasetSource: datasetSource,
      outcomeColumn: outcomeColumn,
      protectedAttributes: protectedAttributes,
      traceStorageUrl: traceStorageUrl,
    );

    final auditRef = firestore!
      .collection('users')
      .doc(user.uid)
      .collection('audits')
      .doc(auditId);
      
    await auditRef.set(record.toFirestore());
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
      // Intentionally ignoring typical silent exceptions on redirect 
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

String _readString(Object? value, {required String fallback}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.trim().isEmpty ? fallback : text;
}
