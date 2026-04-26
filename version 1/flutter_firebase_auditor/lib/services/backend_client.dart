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

  Future<Map<String, dynamic>> runPreAudit(AuditPayload payload) {
    return _postJson('/api/pre-audit', payload.toJson());
  }

  Future<Map<String, dynamic>> runAudit(AuditPayload payload) {
    return _postJson('/api/audit', payload.toJson());
  }

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

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

class AuditPayload {
  const AuditPayload({
    required this.sessionId,
    required this.protectedAttributes,
    required this.outcomeColumn,
    required this.modelType,
    required this.auditMode,
    this.modelId,
  });

  final String sessionId;
  final List<String> protectedAttributes;
  final String outcomeColumn;
  final String modelType;
  final String auditMode;
  final String? modelId;

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'protected_attributes': protectedAttributes,
      'outcome_column': outcomeColumn,
      'model_type': modelType,
      'audit_mode': auditMode,
      'model_id': modelId,
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
