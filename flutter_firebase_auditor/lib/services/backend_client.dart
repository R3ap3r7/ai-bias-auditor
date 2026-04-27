import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class AuditBackendClient {
  AuditBackendClient({
    String? apiBaseUrl,
    http.Client? httpClient,
  })  : apiBaseUrl = (apiBaseUrl ??
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'http://127.0.0.1:8000',
                ))
            .replaceAll(RegExp(r'/$'), ''),
        _httpClient = httpClient ?? http.Client();

  final String apiBaseUrl;
  final http.Client _httpClient;

  Future<List<DemoDatasetInfo>> listDemos() async {
    final body = await _getJson('/api/demos');
    final demos = body['demos'];
    if (demos is! List) return const [];
    return demos
        .map((entry) => DemoDatasetInfo.fromJson(_readMap(entry)))
        .toList();
  }

  Future<GovernanceConfig> fetchGovernanceConfig() async {
    final body = await _getJson('/api/policies');
    return GovernanceConfig.fromJson(body);
  }

  Future<DatasetSession> uploadCsv(PlatformFile file) async {
    final bytes = _requireBytes(file, 'CSV');
    final request = http.MultipartRequest('POST', _uri('/api/upload'))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );

    final body = await _sendMultipart(request);
    return DatasetSession.fromJson(body);
  }

  Future<DatasetSession> loadDemo(String demoId) async {
    final body = await _postJson('/api/demo/$demoId', const {});
    return DatasetSession.fromJson(body);
  }

  Future<UploadedModelInfo> uploadModel({
    required String sessionId,
    required PlatformFile file,
  }) async {
    final bytes = _requireBytes(file, 'model');
    final request = http.MultipartRequest('POST', _uri('/api/model'))
      ..fields['session_id'] = sessionId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );

    final body = await _sendMultipart(request);
    return UploadedModelInfo.fromJson(body);
  }

  Future<PredictionCsvInfo> uploadPredictions({
    required String sessionId,
    required PlatformFile file,
    String? datasetRowIdColumn,
    String? predictionRowIdColumn,
    String? predictionColumn,
    String? scoreColumn,
  }) async {
    final bytes = _requireBytes(file, 'prediction CSV');
    final request = http.MultipartRequest('POST', _uri('/api/predictions'))
      ..fields['session_id'] = sessionId
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );
    _addOptionalField(request, 'dataset_row_id_column', datasetRowIdColumn);
    _addOptionalField(
        request, 'prediction_row_id_column', predictionRowIdColumn);
    _addOptionalField(request, 'prediction_column', predictionColumn);
    _addOptionalField(request, 'score_column', scoreColumn);

    final body = await _sendMultipart(request);
    return PredictionCsvInfo.fromJson(body);
  }

  Future<Map<String, dynamic>> runPreAudit(AuditPayload payload) {
    return _postJson('/api/pre-audit', payload.toJson());
  }

  Future<Map<String, dynamic>> runAudit(AuditPayload payload) {
    return _postJson('/api/audit', payload.toJson());
  }

  Uri reportPdfUri(String reportId, {String? templateId}) {
    final path = '/api/report/$reportId/pdf';
    final query = templateId == null || templateId.isEmpty
        ? null
        : <String, String>{'template_id': templateId};
    return _uri(path).replace(queryParameters: query);
  }

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _httpClient.get(_uri(path));
    return _decodeResponse(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _decodeResponse(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request,
  ) async {
    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response.statusCode, response.body);
  }

  Map<String, dynamic> _decodeResponse(int statusCode, String body) {
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (statusCode >= 200 && statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      throw const AuditBackendException(
        'Backend returned an unexpected response.',
      );
    }

    final detail = decoded is Map ? decoded['detail'] : null;
    throw AuditBackendException(
      detail?.toString() ?? 'Backend request failed with HTTP $statusCode.',
    );
  }

  Uint8List _requireBytes(PlatformFile file, String label) {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw AuditBackendException('Could not read the selected $label file.');
    }
    return bytes;
  }

  void _addOptionalField(
    http.MultipartRequest request,
    String key,
    String? value,
  ) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      request.fields[key] = trimmed;
    }
  }
}

class DemoDatasetInfo {
  const DemoDatasetInfo({
    required this.id,
    required this.name,
    required this.available,
    required this.protectedAttributes,
    required this.outcomeColumn,
    required this.modelType,
  });

  final String id;
  final String name;
  final bool available;
  final List<String> protectedAttributes;
  final String outcomeColumn;
  final String modelType;

  factory DemoDatasetInfo.fromJson(Map<String, dynamic> json) {
    return DemoDatasetInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Demo dataset',
      available: json['available'] == true,
      protectedAttributes: _readStringList(json['protected_attributes']),
      outcomeColumn: json['outcome_column']?.toString() ?? '',
      modelType: json['model_type']?.toString() ?? 'compare_all',
    );
  }
}

class GovernanceConfig {
  const GovernanceConfig({
    required this.policies,
    required this.reportTemplates,
    required this.storage,
  });

  final List<OptionItem> policies;
  final List<OptionItem> reportTemplates;
  final Map<String, dynamic> storage;

  factory GovernanceConfig.fromJson(Map<String, dynamic> json) {
    final policies = json['policies'];
    final templates = json['report_templates'];
    return GovernanceConfig(
      policies: policies is List
          ? policies
              .map((entry) => OptionItem.fromPolicyJson(_readMap(entry)))
              .toList()
          : const [],
      reportTemplates: templates is List
          ? templates
              .map((entry) => OptionItem.fromTemplateJson(_readMap(entry)))
              .toList()
          : const [],
      storage: _readMap(json['storage']),
    );
  }
}

class OptionItem {
  const OptionItem({
    required this.id,
    required this.label,
    this.description = '',
    this.version,
  });

  final String id;
  final String label;
  final String description;
  final String? version;

  factory OptionItem.fromPolicyJson(Map<String, dynamic> json) {
    final version = json['version']?.toString();
    final name = json['name']?.toString() ?? json['policy_id']?.toString();
    return OptionItem(
      id: json['policy_id']?.toString() ?? '',
      label: version == null || version.isEmpty
          ? name ?? 'Policy'
          : '$name ($version)',
      description: json['description']?.toString() ?? '',
      version: version,
    );
  }

  factory OptionItem.fromTemplateJson(Map<String, dynamic> json) {
    return OptionItem(
      id: json['template_id']?.toString() ?? '',
      label: json['title']?.toString() ?? 'Report template',
      description: json['description']?.toString() ?? '',
    );
  }
}

class AuditBackendException implements Exception {
  const AuditBackendException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DatasetSession {
  const DatasetSession({
    required this.sessionId,
    required this.source,
    required this.profile,
    required this.defaults,
    this.displayName,
  });

  final String sessionId;
  final String source;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> defaults;
  final String? displayName;

  factory DatasetSession.fromJson(Map<String, dynamic> json) {
    return DatasetSession(
      sessionId: json['session_id'].toString(),
      source: json['source']?.toString() ?? 'Dataset',
      profile: _readMap(json['profile']),
      defaults: _readMap(json['defaults']),
      displayName: json['name']?.toString(),
    );
  }

  List<String> get columns {
    final values = profile['column_names'];
    if (values is List) return values.map((value) => value.toString()).toList();
    return const [];
  }

  int get rowCount => _readInt(profile['rows']);
  int get columnCount => _readInt(profile['columns']);
  String get name => displayName ?? source;
}

class UploadedModelInfo {
  const UploadedModelInfo({
    required this.modelId,
    required this.filename,
    required this.className,
    required this.warning,
  });

  final String modelId;
  final String filename;
  final String className;
  final String warning;

  factory UploadedModelInfo.fromJson(Map<String, dynamic> json) {
    return UploadedModelInfo(
      modelId: json['model_id'].toString(),
      filename: json['filename']?.toString() ?? 'uploaded model',
      className: json['class_name']?.toString() ?? 'Unknown model',
      warning: json['warning']?.toString() ?? '',
    );
  }
}

class PredictionCsvInfo {
  const PredictionCsvInfo({
    required this.artifactId,
    required this.filename,
    required this.rows,
    required this.details,
  });

  final String artifactId;
  final String filename;
  final int rows;
  final Map<String, dynamic> details;

  factory PredictionCsvInfo.fromJson(Map<String, dynamic> json) {
    return PredictionCsvInfo(
      artifactId: json['prediction_artifact_id'].toString(),
      filename: json['filename']?.toString() ?? 'predictions.csv',
      rows: _readInt(json['rows']),
      details: _readMap(json['details']),
    );
  }

  String get summary {
    final predictionColumn =
        details['selected_prediction_column'] ?? details['selected_column'];
    final scoreColumn = details['selected_score_column'];
    final matchedRows = details['matched_rows'] ?? rows;
    final extraRows = details['extra_predictions'] ?? 0;
    final scoreText = scoreColumn == null ? '' : ', score: $scoreColumn';
    return '$filename: $matchedRows matched rows, prediction: $predictionColumn$scoreText, extra predictions: $extraRows';
  }
}

class AuditPayload {
  const AuditPayload({
    required this.sessionId,
    required this.protectedAttributes,
    required this.outcomeColumn,
    required this.modelType,
    required this.auditMode,
    this.modelId,
    this.predictionArtifactId,
    this.policyId = 'default_governance_v1',
    this.reportTemplate = 'full_report',
    this.controlFeatures = const [],
    this.groupingOverrides = const {},
    this.modelSelectionPriority,
    this.persistenceMode = 'anonymized_traces',
    this.userId,
    this.projectId,
    this.organizationId,
  });

  final String sessionId;
  final List<String> protectedAttributes;
  final String outcomeColumn;
  final String modelType;
  final String auditMode;
  final String? modelId;
  final String? predictionArtifactId;
  final String policyId;
  final String reportTemplate;
  final List<String> controlFeatures;
  final Map<String, dynamic> groupingOverrides;
  final double? modelSelectionPriority;
  final String persistenceMode;
  final String? userId;
  final String? projectId;
  final String? organizationId;

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'protected_attributes': protectedAttributes,
      'outcome_column': outcomeColumn,
      'model_type': modelType,
      'audit_mode': auditMode,
      'model_id': modelId,
      'prediction_artifact_id': predictionArtifactId,
      'policy_id': policyId,
      'report_template': reportTemplate,
      'control_features': controlFeatures,
      'grouping_overrides': groupingOverrides,
      'model_selection_priority': modelSelectionPriority,
      'persistence_mode': persistenceMode,
      'user_id': userId,
      'project_id': projectId,
      'organization_id': organizationId,
    };
  }
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, inner) => MapEntry(key.toString(), inner));
  }
  return {};
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _readStringList(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  return const [];
}
