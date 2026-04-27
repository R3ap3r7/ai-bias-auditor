import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/backend_client.dart';
import '../../services/audit_repository.dart';
import '../../widgets/navbar.dart';
import 'widgets/dataset_selection.dart';
import 'widgets/column_config.dart';
import 'widgets/audit_results.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as import_ui;
import '../../../widgets/gradient_button.dart';
import '../../../widgets/grid_background.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _highlightPostAudit = false;

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

  void _showSaveSuccessAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✓ Audit saved to your history'),
        backgroundColor: const Color(0xFF27272A), // surface color
        behavior: SnackBarBehavior.floating,
        shape: const Border(left: BorderSide(color: AppColors.accentPrimary, width: 4)),
      ),
    );
  }

  void _showGuestWarningAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sign in to save this audit to your history'),
        backgroundColor: const Color(0xFF27272A),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Sign In',
          textColor: AppColors.accentPrimary,
          onPressed: () => Navigator.pushNamed(context, '/auth'),
        ),
      ),
    );
  }

  Future<void> _handleAuditResultSaving(Map<String, dynamic> result, AuditPayload payload) async {
    if (FirebaseAuth.instance.currentUser != null) {
      await AuditRepository.instance.saveAudit(
        rawResult: result,
        datasetName: _session?.name ?? 'Dataset',
        datasetSource: _session?.source ?? 'upload',
        outcomeColumn: payload.outcomeColumn,
        protectedAttributes: payload.protectedAttributes,
      );
      if (mounted) _showSaveSuccessAlert();
    } else {
      if (mounted) _showGuestWarningAlert();
    }
  }

  Future<void> _runPreAudit(AuditPayload payload) async {
    setState(() => _isLoading = true);
    try {
      final result = await _client.runPreAudit(payload);
      if (mounted) {
        await _handleAuditResultSaving(result, payload);
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
         await _handleAuditResultSaving(result, payload);
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
      _highlightPostAudit = false;
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
      extendBody: true,
      body: GridBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32).copyWith(bottom: 72 + 32),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _buildCurrentPhase(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _currentPhase == AuditPhase.results && _results != null && _results!['model'] == null
          ? _buildPreAuditBottomBar()
          : null,
    );
  }

  Widget _buildPreAuditBottomBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: import_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(15, 15, 20, 0.8), // Matches AppTheme background
            border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              final buttons = [
                OutlinedAccentButton(
                  text: '← Home',
                  icon: const Icon(Icons.home, size: 16),
                  onPressed: () => Navigator.pushNamed(context, '/'),
                ),
                GradientButton(
                  text: 'Run Post-Model Audit',
                  icon: const Icon(Icons.bolt, size: 16),
                  onPressed: () {
                    setState(() {
                      _currentPhase = AuditPhase.columnConfiguration;
                      _highlightPostAudit = true;
                    });
                  },
                ),
                OutlinedAccentButton(
                  text: 'New Audit',
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: _startOver,
                ),
              ];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: isCompact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buttons[1], // Priority action center stage
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [buttons[0], buttons[2]],
                          )
                        ],
                      )
                    : SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buttons[0],
                            buttons[1],
                            buttons[2],
                          ],
                        ),
                      ),
              );
            },
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
        highlightPostAudit: _highlightPostAudit,
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
