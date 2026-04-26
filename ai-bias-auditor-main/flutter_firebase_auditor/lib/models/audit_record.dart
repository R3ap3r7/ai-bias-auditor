import 'package:cloud_firestore/cloud_firestore.dart';

class AuditRecord {
  const AuditRecord({
    required this.auditId,
    required this.createdAt,
    required this.datasetName,
    required this.datasetSource,
    required this.rowCount,
    required this.columnCount,
    required this.protectedAttributes,
    required this.outcomeColumn,
    required this.overallSeverity,
    required this.preAuditSeverity,
    this.postAuditSeverity,
    this.modelUsed,
    required this.llmReport,
    required this.rawResults,
    required this.runId,
    this.traceStorageUrl,
  });

  final String auditId;
  final DateTime createdAt;
  final String datasetName;
  final String datasetSource;
  final int rowCount;
  final int columnCount;
  final List<String> protectedAttributes;
  final String outcomeColumn;
  final String overallSeverity;
  final String preAuditSeverity;
  final String? postAuditSeverity;
  final String? modelUsed;
  final Map<String, dynamic> llmReport;
  final Map<String, dynamic> rawResults;
  final String runId;
  final String? traceStorageUrl;

  factory AuditRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    final timestamp = data['createdAt'];
    
    return AuditRecord(
      auditId: snapshot.id,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      datasetName: _readString(data['datasetName'], fallback: 'Dataset'),
      datasetSource: _readString(data['datasetSource'], fallback: 'upload'),
      rowCount: _readInt(data['rowCount']),
      columnCount: _readInt(data['columnCount']),
      protectedAttributes: _readStringList(data['protectedAttributes']),
      outcomeColumn: _readString(data['outcomeColumn'], fallback: 'Outcome'),
      overallSeverity: _readString(data['overallSeverity'], fallback: 'Info'),
      preAuditSeverity: _readString(data['preAuditSeverity'], fallback: 'Info'),
      postAuditSeverity: data['postAuditSeverity'] as String?,
      modelUsed: data['modelUsed'] as String?,
      llmReport: _readMap(data['llmReport']),
      rawResults: _readMap(data['rawResults']),
      runId: _readString(data['runId'], fallback: snapshot.id),
      traceStorageUrl: data['traceStorageUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'auditId': auditId,
      'createdAt': Timestamp.fromDate(createdAt),
      'datasetName': datasetName,
      'datasetSource': datasetSource,
      'rowCount': rowCount,
      'columnCount': columnCount,
      'protectedAttributes': protectedAttributes,
      'outcomeColumn': outcomeColumn,
      'overallSeverity': overallSeverity,
      'preAuditSeverity': preAuditSeverity,
      'postAuditSeverity': postAuditSeverity,
      'modelUsed': modelUsed,
      'llmReport': llmReport,
      'rawResults': rawResults,
      'runId': runId,
      'traceStorageUrl': traceStorageUrl,
    };
  }

  factory AuditRecord.fromResult({
    required Map<String, dynamic> result,
    required String datasetName,
    required String datasetSource,
    required String outcomeColumn,
    required List<String> protectedAttributes,
    String? traceStorageUrl,
  }) {
    final dataset = _readMap(result['dataset']);
    final preAudit = _readMap(result['pre_audit']);
    final postAudit = _readMap(result['model']);
    final report = _readMap(result['report']);
    final traceability = _readMap(result['traceability']);
    
    final id = _readString(
      traceability['run_id'],
      fallback: _readString(result['run_id'], fallback: _stableId()),
    );

    String overallSev = _readString(result['severity'], fallback: 'Info');
    String preSev = _readString(result['pre_audit_severity'], fallback: overallSev);
    String? postSev = postAudit.isNotEmpty ? overallSev : null;

    final clonedRaw = _cloneMap(result);

    return AuditRecord(
      auditId: id,
      createdAt: DateTime.now().toUtc(),
      datasetName: datasetName,
      datasetSource: datasetSource,
      rowCount: _readInt(dataset['rows']),
      columnCount: _readInt(dataset['columns']),
      protectedAttributes: protectedAttributes,
      outcomeColumn: outcomeColumn,
      overallSeverity: overallSev,
      preAuditSeverity: preSev,
      postAuditSeverity: postSev,
      modelUsed: postAudit['model_type'] as String?,
      llmReport: report,
      rawResults: clonedRaw,
      runId: id,
      traceStorageUrl: traceStorageUrl,
    );
  }

  static String _stableId() => 'audit-${DateTime.now().toUtc().microsecondsSinceEpoch}';
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, inner) => MapEntry(key.toString(), inner));
  }
  return {};
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

Map<String, dynamic> _cloneMap(Map<String, dynamic> map) {
  return map.map((key, value) {
    if (value is Map<String, dynamic>) {
      return MapEntry(key, _cloneMap(value));
    }
    if (value is Map) {
      return MapEntry(key, _cloneMap(value.map((k, v) => MapEntry(k.toString(), v))));
    }
    if (value is List) {
      return MapEntry(key, value.map((v) {
        if (v is Map<String, dynamic>) return _cloneMap(v);
        if (v is Map) return _cloneMap(v.map((k, val) => MapEntry(k.toString(), val)));
        return v;
      }).toList());
    }
    return MapEntry(key, value);
  });
}
