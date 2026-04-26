import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/backend_client.dart';
import '../../services/audit_repository.dart';
import '../../widgets/navbar.dart';
import 'widgets/dataset_selection.dart';
import 'widgets/column_config.dart';
import 'widgets/audit_results.dart';

enum AuditPhase { datasetSelection, columnConfiguration, results }

class AuditScreen extends StatefulWidget {
  final String? demoId;
  const AuditScreen({super.key, this.demoId});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final AuditBackendClient _client = AuditBackendClient();
  
  AuditPhase _currentPhase = AuditPhase.datasetSelection;
  DatasetSession? _session;
  Map<String, dynamic>? _results;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.demoId != null && widget.demoId!.isNotEmpty) {
      _loadDemo(widget.demoId!);
    }
  }

  Future<void> _handleFileUpload(PlatformFile file) async {
    setState(() => _isLoading = true);
    try {
      final session = await _client.uploadCsv(file);
      setState(() {
        _session = session;
        _currentPhase = AuditPhase.columnConfiguration;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDemo(String demoId) async {
    setState(() => _isLoading = true);
    try {
      final session = await _client.loadDemo(demoId);
      setState(() {
        _session = session;
        _currentPhase = AuditPhase.columnConfiguration;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runPreAudit(AuditPayload payload) async {
    setState(() => _isLoading = true);
    try {
      final result = await _client.runPreAudit(payload);
      if (mounted) {
        await AuditRepository.instance.saveAudit(
          rawResult: result,
          datasetName: _session?.name ?? 'Dataset',
          datasetSource: _session?.source ?? 'upload',
          outcomeColumn: payload.outcomeColumn,
          protectedAttributes: payload.protectedAttributes,
        );
      }
      setState(() {
        _results = result;
        _currentPhase = AuditPhase.results;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runPostAudit(AuditPayload payload) async {
    setState(() => _isLoading = true);
    try {
      final result = await _client.runAudit(payload);
      if (mounted) {
        await AuditRepository.instance.saveAudit(
          rawResult: result,
          datasetName: _session?.name ?? 'Dataset',
          datasetSource: _session?.source ?? 'upload',
          outcomeColumn: payload.outcomeColumn,
          protectedAttributes: payload.protectedAttributes,
        );
      }
      setState(() {
        _results = result;
        _currentPhase = AuditPhase.results;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.bodyMedium.copyWith(color: AppColors.textWhite)),
        backgroundColor: AppColors.severityCritical,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startOver() {
    setState(() {
      _session = null;
      _results = null;
      _currentPhase = AuditPhase.datasetSelection;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TheAppBar(
        showBack: true,
        actions: _currentPhase != AuditPhase.datasetSelection
            ? [
                TextButton(
                  onPressed: _isLoading ? null : _startOver,
                  child: Text('New Audit', style: AppTypography.titleMedium.copyWith(color: AppColors.accentPrimary)),
                )
              ]
            : [],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildCurrentPhase(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    if (_currentPhase == AuditPhase.datasetSelection) {
      return DatasetSelection(
        key: const ValueKey('dataset'),
        isLoading: _isLoading,
        onFileUploaded: _handleFileUpload,
        onDemoSelected: _loadDemo,
      );
    } else if (_currentPhase == AuditPhase.columnConfiguration && _session != null) {
      return ColumnConfig(
        key: const ValueKey('config'),
        session: _session!,
        isLoading: _isLoading,
        onStartOver: _startOver,
        onRunPreAudit: _runPreAudit,
        onRunPostAudit: _runPostAudit,
      );
    } else if (_currentPhase == AuditPhase.results && _results != null) {
      return AuditResults(
        key: const ValueKey('results'),
        result: _results!,
        reportPdfUrl: _client.reportPdfUri(_results!['report_id']?.toString() ?? '').toString(),
      );
    }
    return const SizedBox.shrink();
  }
}
