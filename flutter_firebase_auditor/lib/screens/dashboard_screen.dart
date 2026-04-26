import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/audit_record.dart';
import '../services/audit_repository.dart';
import '../services/backend_client.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_shell.dart';

enum _AuditPage { workspace, results, history }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.auditRepository,
    required this.backendClient,
  });

  final AuditRepository auditRepository;
  final AuditBackendClient backendClient;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DatasetSession? _dataset;
  UploadedModelInfo? _uploadedModel;
  PredictionCsvInfo? _predictionCsv;
  final Set<String> _protectedAttributes = {};
  final Set<String> _controlFeatures = {};
  String? _outcomeColumn;
  String _auditMode = 'train';
  String _modelType = 'compare_all';
  String _policyId = 'default_governance_v1';
  String _reportTemplate = 'full_report';
  double _modelSelectionPriority = 0.55;
  bool _busy = false;
  String? _statusMessage;
  String? _errorMessage;
  Map<String, dynamic>? _preAuditResult;
  Map<String, dynamic>? _auditResult;
  _AuditPage _selectedPage = _AuditPage.workspace;
  final TextEditingController _predictionColumnController =
      TextEditingController();
  final TextEditingController _scoreColumnController = TextEditingController();
  final TextEditingController _datasetRowIdController = TextEditingController();
  final TextEditingController _predictionRowIdController =
      TextEditingController();

  static const _demoDatasets = {
    'compas': 'COMPAS',
    'adult': 'UCI Adult',
    'german': 'German Credit',
  };

  static const _modelOptions = {
    'compare_all': 'Compare all tuned models',
    'logistic_regression': 'Logistic Regression',
    'decision_tree': 'Decision Tree',
    'random_forest': 'Random Forest',
    'extra_trees': 'Extra Trees',
    'gradient_boosting': 'Gradient Boosting',
    'ada_boost': 'AdaBoost',
    'linear_svm': 'Linear SVM',
    'knn': 'K-Nearest Neighbors',
    'gaussian_nb': 'Gaussian Naive Bayes',
  };

  static const _policyOptions = {
    'default_governance_v1': 'Default Governance',
    'employment_screening_strict': 'Employment Screening',
    'credit_lending_strict': 'Credit Lending',
    'medical_triage_strict': 'Medical Triage',
    'low_risk_internal_tool': 'Low-Risk Internal Tool',
  };

  static const _reportTemplateOptions = {
    'full_report': 'Full Report',
    'executive_summary': 'Executive Summary',
    'technical_audit': 'Technical Audit',
    'compliance_review': 'Compliance Review',
    'model_card': 'Model Card',
  };

  @override
  void dispose() {
    _predictionColumnController.dispose();
    _scoreColumnController.dispose();
    _datasetRowIdController.dispose();
    _predictionRowIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: widget.auditRepository.authStateChanges(),
        builder: (context, authSnapshot) {
          final user = authSnapshot.data;
          if (user == null) {
            return _buildLoginGate();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 980;
              final content = _buildPageContent(compact, user);
              if (compact) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _AuditNavigationRail(
                        repository: widget.auditRepository,
                        user: user,
                        selectedPage: _selectedPage,
                        onSelect: (page) =>
                            setState(() => _selectedPage = page),
                        onNewAudit: _startNewAudit,
                      ),
                      content,
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    child: _AuditNavigationRail(
                      repository: widget.auditRepository,
                      user: user,
                      selectedPage: _selectedPage,
                      onSelect: (page) => setState(() => _selectedPage = page),
                      onNewAudit: _startNewAudit,
                    ),
                  ),
                  Expanded(child: content),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoginGate() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final intro = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill(
                label: 'AI Governance Layer',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryContainer,
              ),
              const SizedBox(height: 24),
              Text(
                'AI Bias Auditor',
                style: Theme.of(context)
                    .textTheme
                    .headlineLarge
                    ?.copyWith(fontSize: compact ? 34 : 42),
              ),
              const SizedBox(height: 12),
              Text(
                'Audit datasets and model decisions before they become operational risk.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await widget.auditRepository.signInWithGoogle();
                      } catch (error) {
                        setState(() => _errorMessage = error.toString());
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                SurfacePanel(
                  backgroundColor:
                      AppColors.errorContainer.withValues(alpha: 0.24),
                  accentColor: AppColors.error,
                  child: Text(_errorMessage!),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'CSV files are processed by the audit engine and are not stored in Firebase.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          );
          final workflow = SurfacePanel(
            backgroundColor: AppColors.surfaceLow,
            accentColor: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Governance workflow',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                _workflowStep('01', 'Data audit',
                    'Representation balance and proxy-risk checks'),
                _workflowStep('02', 'Model audit',
                    'Fairness metrics across protected groups'),
                _workflowStep('03', 'Decision trace',
                    'Risky rows and feature contributors'),
                _workflowStep(
                    '04', 'Gemini report', 'Plain-English recommendations'),
              ],
            ),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: compact
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          intro,
                          const SizedBox(height: 24),
                          workflow,
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 5, child: intro),
                        const SizedBox(width: 32),
                        Expanded(flex: 4, child: workflow),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _workflowStep(String number, String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            StatusPill(label: number, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(bool compact, User? user) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(user),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                SurfacePanel(
                  backgroundColor:
                      AppColors.errorContainer.withValues(alpha: 0.22),
                  accentColor: AppColors.error,
                  child: Text(_errorMessage!),
                ),
                const SizedBox(height: 16),
              ],
              if (_statusMessage != null) ...[
                SurfacePanel(
                  backgroundColor:
                      AppColors.primaryContainer.withValues(alpha: 0.42),
                  accentColor: AppColors.primary,
                  child: Text(_statusMessage!),
                ),
                const SizedBox(height: 16),
              ],
              if (_selectedPage == _AuditPage.workspace) ...[
                _buildWorkspaceOverview(),
                const SizedBox(height: 20),
                _buildConfiguration(compact),
                const SizedBox(height: 20),
                _buildProgressLane(),
              ] else if (_selectedPage == _AuditPage.results) ...[
                _buildResultsOverview(),
                const SizedBox(height: 20),
                _buildPreAuditSection(),
                const SizedBox(height: 20),
                _buildPostAuditSection(),
                const SizedBox(height: 20),
                _buildTraceSection(),
                const SizedBox(height: 20),
                _buildGeminiSection(),
              ] else ...[
                _HistoryReview(
                  repository: widget.auditRepository,
                  backendClient: widget.backendClient,
                  user: user,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(User? user) {
    final severity = _readString(_auditResult?['severity'], fallback: '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI Bias Auditor',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                _selectedPage == _AuditPage.workspace
                    ? 'New audit workspace'
                    : _selectedPage == _AuditPage.results
                        ? 'Results review'
                        : 'Saved audit history',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (user != null) _UserBadge(user: user),
        const SizedBox(width: 8),
        if (severity.isNotEmpty) _severityPill(severity),
      ],
    );
  }

  Widget _buildWorkspaceOverview() {
    final dataset = _dataset;
    return SurfacePanel(
      accentColor: AppColors.primary,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          MetricTile(
            label: 'Dataset',
            value: dataset == null ? 'None' : dataset.rowCount.toString(),
            detail:
                dataset == null ? 'Upload CSV or choose demo' : dataset.name,
          ),
          MetricTile(
            label: 'Protected attrs',
            value: _protectedAttributes.length.toString(),
            detail: 'Selected group columns',
          ),
          MetricTile(
            label: 'Outcome',
            value: _outcomeColumn ?? '-',
            detail: 'Binary target column',
          ),
          MetricTile(
            label: 'Model source',
            value: _auditMode == 'prediction_csv' ? 'Predictions' : 'Trained',
            detail: _auditMode == 'prediction_csv'
                ? _predictionCsv?.filename ?? 'Awaiting prediction CSV'
                : _modelOptions[_modelType],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsOverview() {
    final report = _readMap(_auditResult?['report']);
    final model = _readMap(_auditResult?['model']);
    final trace = _readMap(model['audit_trace']);
    final proxyCount =
        _readList(_readMap(_preAuditResult?['pre_audit'])['proxy_flags'])
            .length;
    return SurfacePanel(
      accentColor: _severityColor(
          _readString(_auditResult?['severity'], fallback: 'Pending')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Audit review',
            subtitle: _auditResult == null
                ? 'Run an audit to populate the review workspace.'
                : _readString(report['source'],
                    fallback: 'Report source pending'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricTile(
                label: 'Severity',
                value:
                    _readString(_auditResult?['severity'], fallback: 'Pending'),
                color: _severityColor(
                  _readString(_auditResult?['severity'], fallback: 'Pending'),
                ),
              ),
              MetricTile(
                label: 'Accuracy',
                value: _percent(_readMap(model['performance'])['accuracy']),
                detail:
                    _readString(model['model_type'], fallback: 'No model yet'),
              ),
              MetricTile(
                label: 'Proxy risks',
                value: proxyCount.toString(),
                color: proxyCount > 0 ? AppColors.error : AppColors.success,
              ),
              MetricTile(
                label: 'Trace records',
                value: _readList(trace['records']).length.toString(),
                detail: 'Risky decisions captured',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLane() {
    final hasDataset = _dataset != null;
    final hasPreAudit = _preAuditResult != null;
    final hasAudit = _auditResult != null;
    final stages = [
      ('Data cleaning', hasDataset),
      ('Pre-audit', hasPreAudit),
      ('Model audit', hasAudit),
      ('Audit trace', hasAudit),
      ('Gemini report', hasAudit),
    ];
    return SurfacePanel(
      backgroundColor: AppColors.surfaceLow,
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Execution lane',
            subtitle: 'Audit stages update as data moves through the pipeline.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stages.map((stage) {
              return StatusPill(
                label: stage.$1,
                color: stage.$2 ? AppColors.success : AppColors.muted,
                backgroundColor: stage.$2
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.surfaceHigh,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguration(bool compact) {
    final columns = _dataset?.columns ?? const <String>[];
    return SurfacePanel(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Audit setup',
            subtitle: _dataset == null
                ? 'Choose a dataset to unlock the audit controls.'
                : '${_dataset!.rowCount} rows, ${_dataset!.columnCount} columns from ${_dataset!.name}',
            trailing: _busy ? const CircularProgressIndicator() : null,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _busy ? null : _pickCsv,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload CSV'),
              ),
              ..._demoDatasets.entries.map(
                (entry) => OutlinedButton(
                  onPressed: _busy ? null : () => _loadDemo(entry.key),
                  child: Text(entry.value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_dataset == null)
            const EmptyState(message: 'No dataset loaded.')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColumnPicker(columns),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: compact ? double.infinity : 300,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                            'outcome-${_dataset?.sessionId}-$_outcomeColumn'),
                        initialValue: _outcomeColumn,
                        decoration:
                            const InputDecoration(labelText: 'Outcome column'),
                        items: columns
                            .map(
                              (column) => DropdownMenuItem(
                                value: column,
                                child: Text(column),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _outcomeColumn = value),
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 300,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('audit-mode-$_auditMode'),
                        initialValue: _auditMode,
                        decoration:
                            const InputDecoration(labelText: 'Model source'),
                        items: const [
                          DropdownMenuItem(
                            value: 'train',
                            child: Text('Train inside auditor'),
                          ),
                          DropdownMenuItem(
                            value: 'prediction_csv',
                            child: Text('Use prediction CSV'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) =>
                                setState(() => _auditMode = value ?? 'train'),
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 320,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('model-type-$_modelType'),
                        initialValue: _modelType,
                        decoration:
                            const InputDecoration(labelText: 'Training model'),
                        items: _modelOptions.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: _busy || _auditMode != 'train'
                            ? null
                            : (value) => setState(
                                  () => _modelType = value ?? 'compare_all',
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGovernanceControls(columns, compact),
                if (_auditMode == 'prediction_csv') ...[
                  const SizedBox(height: 16),
                  _buildPredictionUpload(),
                ],
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _runPreAudit,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Run pre-audit'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _runFullAudit,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run full audit'),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildColumnPicker(List<String> columns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Protected attributes',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: columns.map((column) {
              final selected = _protectedAttributes.contains(column);
              return CheckboxListTile(
                value: selected,
                title: Text(column),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: _busy
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked ?? false) {
                            _protectedAttributes.add(column);
                          } else {
                            _protectedAttributes.remove(column);
                          }
                        });
                      },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prediction CSV',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _predictionCsv?.summary ??
                'Upload externally generated binary predictions. Optional row IDs align predictions without relying on row order.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _predictionColumnController,
                  decoration: const InputDecoration(
                    labelText: 'Prediction column',
                    hintText: 'prediction',
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _scoreColumnController,
                  decoration: const InputDecoration(
                    labelText: 'Score column',
                    hintText: 'score',
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _datasetRowIdController,
                  decoration: const InputDecoration(
                    labelText: 'Dataset row ID',
                    hintText: 'optional',
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _predictionRowIdController,
                  decoration: const InputDecoration(
                    labelText: 'Prediction row ID',
                    hintText: 'optional',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickPredictionCsv,
                icon: const Icon(Icons.table_rows),
                label: const Text('Upload predictions'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceControls(List<String> columns, bool compact) {
    final outcome = _outcomeColumn;
    final availableControls = columns
        .where((column) =>
            column != outcome && !_protectedAttributes.contains(column))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: compact ? double.infinity : 300,
              child: DropdownButtonFormField<String>(
                initialValue: _policyId,
                decoration:
                    const InputDecoration(labelText: 'Governance policy'),
                items: _policyOptions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _policyId = value ?? 'default_governance_v1',
                        ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 300,
              child: DropdownButtonFormField<String>(
                initialValue: _reportTemplate,
                decoration: const InputDecoration(labelText: 'Report template'),
                items: _reportTemplateOptions.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                        () => _reportTemplate = value ?? 'full_report'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Model priority',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Slider(
                    value: _modelSelectionPriority,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label:
                        '${(_modelSelectionPriority * 100).round()}% accuracy',
                    onChanged: _busy
                        ? null
                        : (value) =>
                            setState(() => _modelSelectionPriority = value),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Same-background controls',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableControls.map((column) {
            return FilterChip(
              label: Text(column),
              selected: _controlFeatures.contains(column),
              onSelected: _busy
                  ? null
                  : (selected) {
                      setState(() {
                        if (selected) {
                          _controlFeatures.add(column);
                        } else {
                          _controlFeatures.remove(column);
                        }
                      });
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreAuditSection() {
    final result = _preAuditResult ?? _auditResult;
    final preAudit = _readMap(result?['pre_audit']);
    final cleaning = _readMap(result?['cleaning']);
    final missing = _readList(cleaning['missing_value_actions']);
    final representation =
        _flattenRepresentation(_readList(preAudit['representation']));
    final proxies = _readList(preAudit['proxy_flags']);
    final severity =
        _readString(result?['pre_audit_severity'], fallback: 'Pending');

    return SurfacePanel(
      accentColor: _severityColor(severity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Pre-model audit',
            subtitle: 'Raw data checks before a model is trained or loaded.',
            trailing: _severityPill(severity),
          ),
          const SizedBox(height: 16),
          if (result == null)
            const EmptyState(message: 'Run a pre-audit or full audit.')
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricTile(
                  label: 'Missing actions',
                  value: missing.length.toString(),
                  detail: 'Cleaning operations applied',
                ),
                MetricTile(
                  label: 'Representation checks',
                  value: representation.length.toString(),
                  detail: 'Group outcome-rate comparisons',
                ),
                MetricTile(
                  label: 'Proxy risks',
                  value: proxies.length.toString(),
                  color: proxies.isEmpty ? AppColors.success : AppColors.error,
                  detail: 'Feature links to protected attributes',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Representation',
              rows: representation,
              empty: 'No representation warnings returned.',
              preferredColumns: const [
                'protected_attribute',
                'group',
                'count',
                'positive_rate',
                'ratio_to_highest',
                'status',
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Proxy variables',
              rows: proxies,
              empty: 'No proxy variables returned.',
              preferredColumns: const [
                'feature',
                'protected_attribute',
                'association',
                'method',
                'risk',
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostAuditSection() {
    final result = _auditResult;
    final model = _readMap(result?['model']);
    final performance = _readMap(model['performance']);
    final conditionalFairness = _readMap(model['conditional_fairness']);
    final intersectionalBias = _readMap(model['intersectional_bias']);
    final fairness = _readList(model['bias_metrics']);
    final comparison = _readList(model['model_comparison']);
    final conditional = _readList(conditionalFairness['results']);
    final intersectional = _readList(intersectionalBias['groups']);
    final accuracy = _readString(performance['accuracy'], fallback: '0');
    final precision = _readString(performance['precision'], fallback: '0');
    final recall = _readString(performance['recall'], fallback: '0');

    return SurfacePanel(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Post-model audit',
            subtitle: 'Decision checks after model predictions are produced.',
          ),
          const SizedBox(height: 16),
          if (result == null)
            const EmptyState(message: 'Run a full audit.')
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricTile(label: 'Accuracy', value: _percent(accuracy)),
                MetricTile(label: 'Precision', value: _percent(precision)),
                MetricTile(label: 'Recall', value: _percent(recall)),
                MetricTile(
                  label: 'Selected model',
                  value: _readString(model['model_type'],
                      fallback: _modelOptions[_modelType] ?? 'Model'),
                  detail: _readString(
                    _readMap(result['report'])['source'],
                    fallback: 'Report source pending',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Fairness scorecard',
              rows: fairness,
              empty: 'No post-model fairness metrics returned.',
              preferredColumns: const [
                'protected_attribute',
                'demographic_parity_difference',
                'equalized_odds_difference',
                'disparate_impact_ratio',
                'status',
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Model comparison',
              rows: comparison,
              empty: 'Run compare-all to populate model comparison.',
              preferredColumns: const [
                'model',
                'balanced_accuracy',
                'accuracy',
                'max_demographic_parity_difference',
                'max_equalized_odds_difference',
                'audit_selection_score',
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Conditional fairness',
              rows: conditional,
              empty: 'No matched-background disparities returned.',
              preferredColumns: const [
                'protected_attribute',
                'control_features',
                'cohorts_analyzed',
                'weighted_selection_gap',
                'status',
                'worst_cohorts',
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Intersectional groups',
              rows: intersectional,
              empty: 'No intersectional group results returned.',
              preferredColumns: const [
                'group',
                'count',
                'selection_rate',
                'accuracy',
                'ratio_to_highest',
                'status',
                'small_group_warning',
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTraceSection() {
    final model = _readMap(_auditResult?['model']);
    final trace = _readMap(model['audit_trace']);
    final records = _readList(trace['records']);
    return SurfacePanel(
      accentColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Audit trace',
            subtitle: _readString(
              trace['method_description'],
              fallback: 'Row-level decision trace for risky outcomes.',
            ),
          ),
          const SizedBox(height: 16),
          if (_auditResult == null)
            const EmptyState(message: 'Run a full audit.')
          else
            _dynamicTable(
              title: 'Risky decisions',
              rows: records,
              empty: 'No risky decisions returned.',
              preferredColumns: const [
                'row_id',
                'prediction',
                'actual',
                'decision_score',
                'risk_reason',
                'top_contributions',
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGeminiSection() {
    final report = _readMap(_auditResult?['report']);
    final reportId = _readString(_auditResult?['report_id'], fallback: '');
    final text = _readString(report['text'], fallback: '');
    final source = _readString(report['source'], fallback: 'Gemini analysis');
    return SurfacePanel(
      accentColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Gemini analysis',
            subtitle: source,
            trailing: reportId.isEmpty
                ? null
                : OutlinedButton.icon(
                    onPressed: () => _downloadPdf(reportId),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
          ),
          const SizedBox(height: 16),
          if (_auditResult == null)
            const EmptyState(message: 'Run a full audit.')
          else
            SelectableText(
              text.isEmpty ? 'No report text returned.' : text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _dynamicTable({
    required String title,
    required List<Object?> rows,
    required String empty,
    required List<String> preferredColumns,
  }) {
    final mappedRows =
        rows.map(_readMap).where((row) => row.isNotEmpty).toList();
    if (mappedRows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          EmptyState(message: empty),
        ],
      );
    }

    final allColumns = <String>{
      ...preferredColumns
          .where((column) => mappedRows.any((row) => row.containsKey(column))),
      ...mappedRows.expand((row) => row.keys),
    }.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceHigh),
              dataRowMinHeight: 48,
              dataRowMaxHeight: 72,
              columns: allColumns
                  .map(
                    (column) => DataColumn(
                      label: Text(_labelize(column)),
                    ),
                  )
                  .toList(),
              rows: mappedRows.take(12).map((row) {
                return DataRow(
                  cells: allColumns
                      .map(
                        (column) => DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              _formatCell(row[column]),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    await _guarded('Uploading dataset...', () async {
      final dataset = await widget.backendClient.uploadCsv(result.files.single);
      _applyDataset(dataset);
    });
  }

  Future<void> _loadDemo(String demoId) async {
    await _guarded('Loading ${_demoDatasets[demoId]}...', () async {
      final dataset = await widget.backendClient.loadDemo(demoId);
      _applyDataset(dataset);
    });
  }

  Future<void> _pickPredictionCsv() async {
    final dataset = _dataset;
    if (dataset == null) {
      setState(() =>
          _errorMessage = 'Load a dataset before uploading prediction CSV.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    await _guarded('Uploading predictions...', () async {
      final predictions = await widget.backendClient.uploadPredictions(
        sessionId: dataset.sessionId,
        file: result.files.single,
        predictionColumn: _predictionColumnController.text,
        scoreColumn: _scoreColumnController.text,
        datasetRowIdColumn: _datasetRowIdController.text,
        predictionRowIdColumn: _predictionRowIdController.text,
      );
      setState(() {
        _predictionCsv = predictions;
        _statusMessage = predictions.summary;
      });
    });
  }

  Future<void> _runPreAudit() async {
    final payload = _buildPayload();
    if (payload == null) return;

    await _guarded('Running pre-audit...', () async {
      final result = await widget.backendClient.runPreAudit(payload);
      setState(() {
        _preAuditResult = result;
        _auditResult = null;
        _selectedPage = _AuditPage.results;
        _statusMessage = 'Pre-audit completed.';
      });
    });
  }

  Future<void> _runFullAudit() async {
    final payload = _buildPayload();
    final dataset = _dataset;
    if (payload == null || dataset == null) return;

    await _guarded('Running full audit...', () async {
      final result = await widget.backendClient.runAudit(payload);
      final record = AuditRecord.fromResult(
        result: result,
        datasetName: dataset.name,
        outcomeColumn: payload.outcomeColumn,
        protectedAttributes: payload.protectedAttributes,
      );
      if (widget.auditRepository.currentUser != null) {
        await widget.auditRepository
            .saveAudit(record: record, rawResult: result);
      }
      setState(() {
        _auditResult = result;
        _preAuditResult = result;
        _selectedPage = _AuditPage.results;
        _statusMessage = widget.auditRepository.currentUser != null
            ? 'Full audit completed and saved to Firebase.'
            : 'Full audit completed. Firebase history is not enabled.';
      });
    });
  }

  Future<void> _downloadPdf(String reportId) async {
    final uri = widget.backendClient.reportPdfUri(
      reportId,
      templateId: _reportTemplate,
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _errorMessage = 'Could not open PDF report: $uri');
    }
  }

  AuditPayload? _buildPayload() {
    final dataset = _dataset;
    final outcome = _outcomeColumn;
    if (dataset == null) {
      setState(() => _errorMessage = 'Load a dataset first.');
      return null;
    }
    if (_protectedAttributes.isEmpty) {
      setState(
          () => _errorMessage = 'Select at least one protected attribute.');
      return null;
    }
    if (outcome == null || outcome.isEmpty) {
      setState(() => _errorMessage = 'Select an outcome column.');
      return null;
    }
    if (_auditMode == 'prediction_csv' && _predictionCsv == null) {
      setState(() => _errorMessage =
          'Upload a prediction CSV before running prediction-only audit.');
      return null;
    }

    final user = widget.auditRepository.currentUser;
    setState(() => _errorMessage = null);
    return AuditPayload(
      sessionId: dataset.sessionId,
      protectedAttributes: _protectedAttributes.toList(),
      outcomeColumn: outcome,
      modelType: _auditMode == 'train' ? _modelType : 'logistic_regression',
      auditMode: _auditMode,
      modelId: _uploadedModel?.modelId,
      predictionArtifactId: _predictionCsv?.artifactId,
      policyId: _policyId,
      reportTemplate: _reportTemplate,
      controlFeatures: _controlFeatures.toList(),
      groupingOverrides: const {},
      modelSelectionPriority: _modelSelectionPriority,
      persistenceMode: 'anonymized_traces',
      userId: user?.uid,
      projectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    );
  }

  void _applyDataset(DatasetSession dataset) {
    final defaultProtected =
        _readStringList(dataset.defaults['protected_attributes']);
    final defaultOutcome = _readString(
      dataset.defaults['outcome_column'],
      fallback: dataset.columns.isEmpty ? '' : dataset.columns.last,
    );
    final defaultModel = _readString(
      dataset.defaults['model_type'],
      fallback: 'compare_all',
    );
    final defaultControls =
        _readStringList(dataset.defaults['control_features']);
    final defaultPolicy = _readString(
      dataset.defaults['policy_id'],
      fallback: 'default_governance_v1',
    );

    setState(() {
      _dataset = dataset;
      _protectedAttributes
        ..clear()
        ..addAll(defaultProtected);
      _controlFeatures
        ..clear()
        ..addAll(defaultControls);
      _outcomeColumn = defaultOutcome.isEmpty ? null : defaultOutcome;
      _modelType = _modelOptions.containsKey(defaultModel)
          ? defaultModel
          : 'compare_all';
      _policyId = _policyOptions.containsKey(defaultPolicy)
          ? defaultPolicy
          : 'default_governance_v1';
      _reportTemplate = 'full_report';
      _modelSelectionPriority = 0.55;
      _auditMode = 'train';
      _uploadedModel = null;
      _predictionCsv = null;
      _predictionColumnController.clear();
      _scoreColumnController.clear();
      _datasetRowIdController.clear();
      _predictionRowIdController.clear();
      _preAuditResult = null;
      _auditResult = null;
      _selectedPage = _AuditPage.workspace;
      _statusMessage = '${dataset.name} loaded.';
      _errorMessage = null;
    });
  }

  void _startNewAudit() {
    setState(() {
      _dataset = null;
      _uploadedModel = null;
      _predictionCsv = null;
      _protectedAttributes.clear();
      _controlFeatures.clear();
      _outcomeColumn = null;
      _auditMode = 'train';
      _modelType = 'compare_all';
      _policyId = 'default_governance_v1';
      _reportTemplate = 'full_report';
      _modelSelectionPriority = 0.55;
      _predictionColumnController.clear();
      _scoreColumnController.clear();
      _datasetRowIdController.clear();
      _predictionRowIdController.clear();
      _busy = false;
      _statusMessage = null;
      _errorMessage = null;
      _preAuditResult = null;
      _auditResult = null;
      _selectedPage = _AuditPage.workspace;
    });
  }

  Future<void> _guarded(String message, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _statusMessage = message;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _AuditNavigationRail extends StatelessWidget {
  const _AuditNavigationRail({
    required this.repository,
    required this.user,
    required this.selectedPage,
    required this.onSelect,
    required this.onNewAudit,
  });

  final AuditRepository repository;
  final User? user;
  final _AuditPage selectedPage;
  final ValueChanged<_AuditPage> onSelect;
  final VoidCallback onNewAudit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Bias Auditor',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Governance workspace for datasets, models, traces, and saved review history.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            _identityPanel(context),
            const SizedBox(height: 20),
            _navButton(
              context,
              icon: Icons.add_circle_outline,
              label: 'New audit',
              selected: selectedPage == _AuditPage.workspace,
              onPressed: onNewAudit,
            ),
            _navButton(
              context,
              icon: Icons.analytics_outlined,
              label: 'Results review',
              selected: selectedPage == _AuditPage.results,
              onPressed: () => onSelect(_AuditPage.results),
            ),
            _navButton(
              context,
              icon: Icons.history,
              label: 'Saved history',
              selected: selectedPage == _AuditPage.history,
              onPressed: () => onSelect(_AuditPage.history),
            ),
            const SizedBox(height: 20),
            Text('Recent runs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _recentRuns(context),
          ],
        ),
      ),
    );
  }

  Widget _identityPanel(BuildContext context) {
    if (user != null) {
      return SurfacePanel(
        padding: const EdgeInsets.all(14),
        backgroundColor: AppColors.surface,
        accentColor: AppColors.success,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(
              label: 'Signed in',
              color: AppColors.success,
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 10),
            Text(
              user!.displayName ?? 'Google account',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              user!.email ?? user!.uid,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: repository.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      );
    }

    return SurfacePanel(
      padding: const EdgeInsets.all(14),
      backgroundColor: AppColors.surface,
      accentColor: AppColors.error,
      child: Text(
        repository.enabled
            ? 'Sign in to save audit history.'
            : repository.disabledReason,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.muted),
      ),
    );
  }

  Widget _navButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Align(alignment: Alignment.centerLeft, child: Text(label)),
          style: TextButton.styleFrom(
            foregroundColor: selected ? AppColors.primary : AppColors.text,
            backgroundColor:
                selected ? AppColors.primaryContainer : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _recentRuns(BuildContext context) {
    if (user == null || !repository.enabled) {
      return const EmptyState(message: 'Sign in to save and review runs.');
    }

    return StreamBuilder<List<AuditRecord>>(
      stream: repository.watchRecentAudits(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 3);
        }
        final records = snapshot.data ?? const <AuditRecord>[];
        if (records.isEmpty) {
          return const EmptyState(message: 'No saved audits yet.');
        }
        return Column(
          children: records.take(5).map((record) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfacePanel(
                padding: const EdgeInsets.all(12),
                backgroundColor: AppColors.surface,
                accentColor: _severityColor(record.severity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.datasetName,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _severityPill(record.severity),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM d, HH:mm')
                          .format(record.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoURL;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryContainer,
            backgroundImage: photoUrl == null || photoUrl.isEmpty
                ? null
                : NetworkImage(photoUrl),
            child: photoUrl == null || photoUrl.isEmpty
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              user.displayName ?? user.email ?? 'Google account',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.text,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryReview extends StatelessWidget {
  const _HistoryReview({
    required this.repository,
    required this.backendClient,
    required this.user,
  });

  final AuditRepository repository;
  final AuditBackendClient backendClient;
  final User? user;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Saved audit history',
            subtitle:
                'Firebase stores run metadata and trace snippets for retrospective review.',
          ),
          const SizedBox(height: 16),
          if (!repository.enabled)
            EmptyState(message: repository.disabledReason)
          else if (user == null)
            const EmptyState(
              message:
                  'Sign in with Google to persist audit runs to Firestore.',
            )
          else
            StreamBuilder<List<AuditRecord>>(
              stream: repository.watchRecentAudits(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator(minHeight: 3);
                }
                final records = snapshot.data ?? const <AuditRecord>[];
                if (records.isEmpty) {
                  return const EmptyState(message: 'No saved audits yet.');
                }
                return Column(
                  children: records.map((record) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SurfacePanel(
                        backgroundColor: AppColors.surfaceLow,
                        accentColor: _severityColor(record.severity),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    record.datasetName,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                _severityPill(record.severity),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                MetricTile(
                                  label: 'Model',
                                  value: record.modelName,
                                  detail: record.reportSource,
                                ),
                                MetricTile(
                                  label: 'Outcome',
                                  value: record.outcomeColumn,
                                  detail: record.protectedAttributes.join(', '),
                                ),
                                MetricTile(
                                  label: 'Trace records',
                                  value: record.traceRecordCount.toString(),
                                  detail: 'Stored decision rows',
                                ),
                                MetricTile(
                                  label: 'Created',
                                  value: DateFormat('MMM d').format(
                                    record.createdAt.toLocal(),
                                  ),
                                  detail: DateFormat('HH:mm').format(
                                    record.createdAt.toLocal(),
                                  ),
                                ),
                                if (record.reportId != null)
                                  OutlinedButton.icon(
                                    onPressed: () => launchUrl(
                                      backendClient
                                          .reportPdfUri(record.reportId!),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    icon: const Icon(
                                        Icons.picture_as_pdf_outlined),
                                    label: const Text('Download PDF'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

StatusPill _severityPill(String severity) {
  final normalized = severity.trim().isEmpty ? 'Pending' : severity;
  return StatusPill(
    label: normalized,
    color: _severityColor(normalized),
    backgroundColor: _severityColor(normalized).withValues(alpha: 0.12),
  );
}

Color _severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
    case 'high':
      return AppColors.error;
    case 'medium':
      return AppColors.warning;
    case 'low':
      return AppColors.success;
    default:
      return AppColors.primary;
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

List<String> _readStringList(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  return const [];
}

List<Map<String, dynamic>> _flattenRepresentation(List<Object?> rows) {
  final flattened = <Map<String, dynamic>>[];
  for (final row in rows) {
    final representation = _readMap(row);
    final attribute = representation['protected_attribute'];
    final groups = _readList(representation['groups']);
    for (final group in groups) {
      final groupMap = _readMap(group);
      if (groupMap.isEmpty) continue;
      flattened.add({
        'protected_attribute': attribute,
        ...groupMap,
      });
    }
  }
  return flattened;
}

String _readString(Object? value, {required String fallback}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _labelize(String key) {
  return key.replaceAll('_', ' ').toUpperCase();
}

String _formatCell(Object? value) {
  if (value == null) return '-';
  if (value is num) return value.toStringAsFixed(value.abs() >= 10 ? 1 : 3);
  if (value is List) {
    return value.map(_formatCell).join(', ');
  }
  if (value is Map) {
    return value.entries
        .take(3)
        .map((entry) => '${entry.key}: ${_formatCell(entry.value)}')
        .join(', ');
  }
  return value.toString();
}

String _percent(Object? value) {
  if (value is num) return '${(value * 100).toStringAsFixed(1)}%';
  final parsed = num.tryParse(value?.toString() ?? '');
  if (parsed == null) return '-';
  return '${(parsed * 100).toStringAsFixed(1)}%';
}
