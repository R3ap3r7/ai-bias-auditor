import 'package:cloud_firestore/cloud_firestore.dart';

class AuditRecord {
  const AuditRecord({
    required this.id,
    required this.createdAt,
    required this.datasetName,
    required this.severity,
    required this.modelName,
    required this.outcomeColumn,
    required this.protectedAttributes,
    required this.reportSource,
    required this.traceRecordCount,
    required this.status,
    this.ownerId,
    this.reportId,
  });

  final String id;
  final DateTime createdAt;
  final String datasetName;
  final String severity;
  final String modelName;
  final String outcomeColumn;
  final List<String> protectedAttributes;
  final String reportSource;
  final int traceRecordCount;
  final String status;
  final String? ownerId;
  final String? reportId;

  factory AuditRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final timestamp = data['createdAt'];
    return AuditRecord(
      id: snapshot.id,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      datasetName: _readString(data['datasetName'], fallback: 'Dataset'),
      severity: _readString(data['severity'], fallback: 'Unknown'),
      modelName: _readString(data['modelName'], fallback: 'Model'),
      outcomeColumn: _readString(data['outcomeColumn'], fallback: 'Outcome'),
      protectedAttributes: _readStringList(data['protectedAttributes']),
      reportSource: _readString(data['reportSource'], fallback: 'Local'),
      traceRecordCount: _readInt(data['traceRecordCount']),
      status: _readString(data['status'], fallback: 'completed'),
      ownerId: data['ownerId'] as String?,
      reportId: data['reportId'] as String?,
    );
  }

  factory AuditRecord.fromResult({
    required Map<String, dynamic> result,
    required String datasetName,
    required String outcomeColumn,
    required List<String> protectedAttributes,
  }) {
    final traceability = _readMap(result['traceability']);
    final model = _readMap(result['model']);
    final report = _readMap(result['report']);
    final auditTrace = _readMap(model['audit_trace']);
    final dataset = _readMap(result['dataset']);
    final traceRecords = _readList(auditTrace['records']);
    final id = _readString(
      traceability['run_id'],
      fallback: _readString(result['run_id'], fallback: _stableId()),
    );

    return AuditRecord(
      id: id,
      createdAt: DateTime.now().toUtc(),
      datasetName: datasetName,
      severity: _readString(result['severity'], fallback: 'Unknown'),
      modelName: _readString(
        model['model_type'],
        fallback: _readString(dataset['model_type'], fallback: 'Model'),
      ),
      outcomeColumn: outcomeColumn,
      protectedAttributes: protectedAttributes,
      reportSource: _readString(report['source'], fallback: 'Local'),
      traceRecordCount: traceRecords.length,
      status: 'completed',
      reportId: result['report_id'] as String?,
    );
  }

  Map<String, dynamic> toFirestore(String ownerId) {
    return {
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'datasetName': datasetName,
      'severity': severity,
      'modelName': modelName,
      'outcomeColumn': outcomeColumn,
      'protectedAttributes': protectedAttributes,
      'reportSource': reportSource,
      'traceRecordCount': traceRecordCount,
      'status': status,
      'reportId': reportId,
    };
  }

  static String _stableId() =>
      'audit-${DateTime.now().toUtc().microsecondsSinceEpoch}';
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

List<String> _readStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

String _readString(Object? value, {required String fallback}) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.trim().isEmpty ? fallback : text;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
