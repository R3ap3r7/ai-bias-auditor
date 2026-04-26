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

enum _ResultTab {
  overview,
  preAudit,
  bias,
  model,
  governance,
  features,
  report
}

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
  bool _guestMode = false;
  String? _statusMessage;
  String? _errorMessage;
  Map<String, dynamic>? _preAuditResult;
  Map<String, dynamic>? _auditResult;
  _AuditPage _selectedPage = _AuditPage.workspace;
  _ResultTab _selectedResultTab = _ResultTab.overview;
  final TextEditingController _predictionColumnController =
      TextEditingController();
  final TextEditingController _scoreColumnController = TextEditingController();
  final TextEditingController _datasetRowIdController = TextEditingController();
  final TextEditingController _predictionRowIdController =
      TextEditingController();

  List<DemoDatasetInfo> _demoDatasets = _defaultDemoDatasets;
  List<OptionItem> _policyOptions = _defaultPolicyOptions;
  List<OptionItem> _reportTemplateOptions = _defaultReportTemplateOptions;

  static const _defaultDemoDatasets = [
    DemoDatasetInfo(
      id: 'compas',
      name: 'COMPAS',
      available: true,
      protectedAttributes: ['race', 'gender', 'age_cat'],
      outcomeColumn: 'two_year_recid',
      modelType: 'compare_all',
    ),
    DemoDatasetInfo(
      id: 'adult',
      name: 'UCI Adult',
      available: true,
      protectedAttributes: ['sex', 'race'],
      outcomeColumn: 'income',
      modelType: 'compare_all',
    ),
    DemoDatasetInfo(
      id: 'german',
      name: 'German Credit',
      available: true,
      protectedAttributes: ['age'],
      outcomeColumn: 'credit_risk',
      modelType: 'compare_all',
    ),
  ];

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

  static const _defaultPolicyOptions = [
    OptionItem(id: 'default_governance_v1', label: 'Default Governance'),
    OptionItem(
        id: 'employment_screening_strict', label: 'Employment Screening'),
    OptionItem(id: 'credit_lending_strict', label: 'Credit Lending'),
    OptionItem(id: 'medical_triage_strict', label: 'Medical Triage'),
    OptionItem(id: 'low_risk_internal_tool', label: 'Low-Risk Internal Tool'),
  ];

  static const _defaultReportTemplateOptions = [
    OptionItem(id: 'full_report', label: 'Full Report'),
    OptionItem(id: 'executive_summary', label: 'Executive Summary'),
    OptionItem(id: 'technical_audit', label: 'Technical Audit'),
    OptionItem(id: 'compliance_review', label: 'Compliance Review'),
    OptionItem(id: 'model_card', label: 'Model Card'),
  ];

  @override
  void initState() {
    super.initState();
    _loadBackendCatalog();
  }

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
          if (user == null && !_guestMode) {
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
                        onSignIn: _signInWithGoogle,
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
                      onSignIn: _signInWithGoogle,
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
                    onPressed: widget.auditRepository.enabled
                        ? _signInWithGoogle
                        : null,
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _continueAsGuest,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continue as guest'),
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
                widget.auditRepository.enabled
                    ? 'CSV files are processed by the audit engine and are not stored in Firebase.'
                    : widget.auditRepository.disabledReason,
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
                _buildResultsWorkspace(),
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
        if (user != null)
          _UserBadge(user: user)
        else
          const StatusPill(
            label: 'Guest',
            color: AppColors.warning,
            backgroundColor: AppColors.warningContainer,
          ),
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
            trailing: _dataset == null
                ? null
                : OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _selectedPage = _AuditPage.workspace),
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('Audit setup'),
                  ),
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

  Widget _buildResultsWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultsOverview(),
        const SizedBox(height: 20),
        _buildResultTabBar(),
        const SizedBox(height: 20),
        switch (_selectedResultTab) {
          _ResultTab.overview => _buildRunOverviewSection(),
          _ResultTab.preAudit => _buildPreAuditSection(),
          _ResultTab.bias => _buildPostAuditSection(),
          _ResultTab.model => _buildModelComparisonSection(),
          _ResultTab.governance => _buildTraceSection(),
          _ResultTab.features => _buildFeatureAuditSection(),
          _ResultTab.report => _buildGeminiSection(),
        },
      ],
    );
  }

  Widget _buildResultTabBar() {
    final tabs = [
      (_ResultTab.overview, Icons.dashboard_outlined, 'Overview'),
      (_ResultTab.preAudit, Icons.fact_check_outlined, 'Data Pre-Audit'),
      (_ResultTab.bias, Icons.balance_outlined, 'Bias Scorecard'),
      (_ResultTab.model, Icons.tune_outlined, 'Model Comparison'),
      (_ResultTab.governance, Icons.account_tree_outlined, 'Decision Traces'),
      (_ResultTab.features, Icons.insights_outlined, 'Features'),
      (_ResultTab.report, Icons.description_outlined, 'Report'),
    ];

    return SurfacePanel(
      padding: const EdgeInsets.all(12),
      backgroundColor: AppColors.surfaceLow,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tabs.map((tab) {
          final selected = _selectedResultTab == tab.$1;
          return ChoiceChip(
            selected: selected,
            avatar: Icon(
              tab.$2,
              size: 18,
              color: selected ? Colors.white : AppColors.muted,
            ),
            label: Text(tab.$3),
            onSelected: (_) => setState(() => _selectedResultTab = tab.$1),
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected
                  ? AppColors.primary
                  : AppColors.outline.withValues(alpha: 0.24),
            ),
          );
        }).toList(),
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
              ..._demoDatasets.map(
                (demo) => OutlinedButton.icon(
                  onPressed: _busy || !demo.available
                      ? null
                      : () => _loadDemo(demo.id),
                  icon: Icon(
                    demo.available
                        ? Icons.dataset_outlined
                        : Icons.cloud_off_outlined,
                  ),
                  label: Text(demo.name),
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
                initialValue:
                    _hasOption(_policyOptions, _policyId) ? _policyId : null,
                decoration:
                    const InputDecoration(labelText: 'Governance policy'),
                items: _policyOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.id,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _policyId = value ?? _policyOptions.first.id,
                        ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 300,
              child: DropdownButtonFormField<String>(
                initialValue: _hasOption(
                  _reportTemplateOptions,
                  _reportTemplate,
                )
                    ? _reportTemplate
                    : null,
                decoration: const InputDecoration(labelText: 'Report template'),
                items: _reportTemplateOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.id,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(
                          () => _reportTemplate =
                              value ?? _reportTemplateOptions.first.id,
                        ),
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

  Widget _buildRunOverviewSection() {
    final result = _auditResult ?? _preAuditResult;
    final dataset = _readMap(result?['dataset']);
    final cleaning = _readMap(result?['cleaning']);
    final missingActions = _readList(cleaning['missing_value_actions'])
        .map(_readMap)
        .where((row) => row.isNotEmpty)
        .toList();
    final outcomeMapping = _readMap(cleaning['outcome_mapping']);

    return SurfacePanel(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Run overview',
            subtitle:
                'Dataset profile, cleaning decisions, policy context, and deployment status.',
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
                  label: 'Rows',
                  value: _readString(dataset['rows'], fallback: '-'),
                  detail: _readString(
                    dataset['source_name'],
                    fallback: _dataset?.name ?? 'Dataset',
                  ),
                ),
                MetricTile(
                  label: 'Columns',
                  value: _readString(dataset['columns'], fallback: '-'),
                  detail: 'After source profiling',
                ),
                MetricTile(
                  label: 'Dropped rows',
                  value: _readString(
                    cleaning['dropped_rows_missing_outcome'],
                    fallback: '0',
                  ),
                  detail: 'Missing outcome rows',
                ),
                MetricTile(
                  label: 'Decision',
                  value: _readString(
                    result['deployment_decision'],
                    fallback: 'Pre-audit only',
                  ),
                  color: _severityColor(
                    _readString(result['severity'], fallback: 'Pending'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Cleaning log',
              rows: [
                {
                  'field': 'Governance policy',
                  'value': _readString(
                    dataset['policy_name'],
                    fallback: _policyLabel(_policyId),
                  ),
                },
                {
                  'field': 'Dropped columns over 50% missing',
                  'value': _readList(
                    cleaning['dropped_columns_over_50_percent_missing'],
                  ).join(', '),
                },
                {
                  'field': 'Outcome mapping',
                  'value': outcomeMapping.isEmpty
                      ? '-'
                      : outcomeMapping.entries
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join(', '),
                },
                {
                  'field': 'Rows after cleaning',
                  'value': _readString(
                    cleaning['rows_after_cleaning'],
                    fallback: '-',
                  ),
                },
                ...missingActions.map((action) => {
                      'field': action['column'],
                      'value':
                          '${action['missing_count'] ?? 0} missing values, ${action['action'] ?? 'handled'}',
                    }),
              ],
              empty: 'No cleaning actions returned.',
              preferredColumns: const ['field', 'value'],
            ),
          ],
        ],
      ),
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
            _barList(
              title: 'Positive rate by group',
              data: representation.map((row) {
                return _BarDatum(
                  label:
                      '${_readString(row['protected_attribute'], fallback: 'Attribute')}: ${_readString(row['group'], fallback: 'Group')}',
                  value: _readDouble(row['positive_rate']),
                  color: _statusColor(_readString(row['status'], fallback: '')),
                  trailing: _percent(row['positive_rate']),
                );
              }).toList(),
              maxValue: 1,
              empty: 'No representation chart data returned.',
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
    final fairness = _readList(model['bias_metrics']);
    final accuracy = _readString(performance['accuracy'], fallback: '0');
    final precision = _readString(performance['precision'], fallback: '0');
    final recall = _readString(performance['recall'], fallback: '0');

    return SurfacePanel(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Bias scorecard',
            subtitle:
                'Model performance and fairness gaps across protected groups.',
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
            _barList(
              title: 'Fairness gaps per attribute',
              data: fairness.expand((entry) {
                final metric = _readMap(entry);
                final attribute =
                    _readString(metric['protected_attribute'], fallback: '');
                return [
                  _BarDatum(
                    label: '$attribute DP gap',
                    value: _readDouble(metric['demographic_parity_difference']),
                    color: AppColors.error,
                    trailing: _formatNumber(
                      metric['demographic_parity_difference'],
                    ),
                  ),
                  _BarDatum(
                    label: '$attribute EO gap',
                    value: _readDouble(metric['equalized_odds_difference']),
                    color: AppColors.warning,
                    trailing:
                        _formatNumber(metric['equalized_odds_difference']),
                  ),
                  _BarDatum(
                    label: '$attribute |1-DI|',
                    value: (1 - _readDouble(metric['disparate_impact_ratio']))
                        .abs(),
                    color: AppColors.primary,
                    trailing: _formatNumber(metric['disparate_impact_ratio']),
                  ),
                ];
              }).toList(),
              maxValue: 1,
              empty: 'No fairness chart data returned.',
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
          ],
        ],
      ),
    );
  }

  Widget _buildModelComparisonSection() {
    final model = _readMap(_auditResult?['model']);
    final tuning = _readMap(model['tuning']);
    final modelInput = _readMap(model['model_input']);
    final predictionValidation = _readMap(model['prediction_validation']);
    final comparison = _readList(model['model_comparison']);
    final validationRows = <Map<String, dynamic>>[
      {
        'check': 'Binary predictions',
        'status': _readString(predictionValidation['status'], fallback: 'Pass'),
        'details':
            'Unique values: ${_readList(predictionValidation['unique_values']).join(', ')}',
      },
      if (_readMap(predictionValidation['mapping']).isNotEmpty)
        {
          'check': 'Prediction mapping',
          'status': 'Info',
          'details': _formatCell(predictionValidation['mapping']),
        },
      ..._readList(predictionValidation['warnings']).map((warning) => {
            'check': 'Warning',
            'status': 'Warn',
            'details': warning,
          }),
      ..._readList(modelInput['warnings']).map((warning) => {
            'check': 'Model input warning',
            'status': 'Warn',
            'details': warning,
          }),
    ];

    return SurfacePanel(
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Model comparison',
            subtitle:
                'Tuned candidate ranking, selected model evidence, and prediction validation.',
          ),
          const SizedBox(height: 16),
          if (_auditResult == null)
            const EmptyState(message: 'Run a full audit.')
          else ...[
            Text(
              '${_readString(model['model_type'], fallback: 'Model')} using ${_readString(modelInput['strategy'], fallback: 'unknown input strategy')}. '
              '${_readString(tuning['status'], fallback: '')}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _barList(
              title: 'Audit selection scores',
              data: comparison.map((entry) {
                final row = _readMap(entry);
                return _BarDatum(
                  label: _readString(row['model'], fallback: 'Model'),
                  value: _readDouble(row['audit_selection_score']),
                  color: row['selected'] == true
                      ? AppColors.success
                      : AppColors.primary,
                  trailing: _formatNumber(row['audit_selection_score']),
                );
              }).toList(),
              empty: 'No model comparison chart data returned.',
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Tuned model comparison',
              rows: comparison,
              empty: 'Run compare-all to populate model comparison.',
              preferredColumns: const [
                'selected',
                'model',
                'status',
                'cv_score',
                'balanced_accuracy',
                'accuracy',
                'precision',
                'recall',
                'max_demographic_parity_difference',
                'max_equalized_odds_difference',
                'audit_selection_score',
                'fails_policy',
                'policy_failures',
                'best_params',
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Prediction validation',
              rows: validationRows,
              empty: 'No prediction validation returned.',
              preferredColumns: const ['check', 'status', 'details'],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTraceSection() {
    final result = _auditResult;
    final model = _readMap(_auditResult?['model']);
    final trace = _readMap(model['audit_trace']);
    final governance = _readMap(result?['governance']);
    final conditionalFairness = _readMap(model['conditional_fairness']);
    final intersectionalBias = _readMap(model['intersectional_bias']);
    final conditional = _readList(conditionalFairness['results']);
    final intersectional = _readList(intersectionalBias['groups']);
    final records = _readList(trace['records']);
    return SurfacePanel(
      accentColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Decision traces',
            subtitle: _readString(
              trace['method_description'],
              fallback:
                  'Governance assessment, same-background checks, intersectional groups, and row-level decision trace.',
            ),
          ),
          const SizedBox(height: 16),
          if (result == null)
            const EmptyState(message: 'Run a full audit.')
          else ...[
            _dynamicTable(
              title: 'Governance decision',
              rows: [
                {
                  'field': 'Risk score',
                  'value': _formatNumber(governance['risk_score']),
                },
                {
                  'field': 'Severity',
                  'value': _readString(governance['severity'], fallback: '-'),
                },
                {
                  'field': 'Deployment decision',
                  'value': _readString(
                    governance['deployment_decision'],
                    fallback: '-',
                  ),
                },
                {
                  'field': 'Policy',
                  'value':
                      '${_readString(governance['policy_name'], fallback: '')} ${_readString(governance['policy_version'], fallback: '')}',
                },
                ..._readList(governance['top_risk_drivers']).map((driver) => {
                      'field': 'Risk driver',
                      'value': driver,
                    }),
              ],
              empty: 'No governance decision returned.',
              preferredColumns: const ['field', 'value'],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Grouping preview',
              rows: _readList(
                result['grouping_preview'] ??
                    _readMap(result['pre_audit'])['grouping_preview'],
              ),
              empty: 'No grouping preview returned.',
              preferredColumns: const [
                'column',
                'detected_type',
                'grouping_method',
                'groups',
              ],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Run traceability',
              rows: _traceabilityRows(_readMap(result['traceability'])),
              empty: 'No traceability metadata returned.',
              preferredColumns: const ['field', 'value'],
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Same-background fairness',
              rows: conditional,
              empty: _readString(
                conditionalFairness['reason'],
                fallback: 'No matched-background disparities returned.',
              ),
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
              empty: _readString(
                intersectionalBias['reason'],
                fallback: 'No intersectional group results returned.',
              ),
              preferredColumns: const [
                'group',
                'count',
                'positive_predictions',
                'selection_rate',
                'accuracy',
                'ratio_to_highest',
                'status',
                'small_group_warning',
              ],
            ),
            const SizedBox(height: 16),
            _traceCards(records, trace),
            const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Widget _buildFeatureAuditSection() {
    final model = _readMap(_auditResult?['model']);
    final importances = _readList(model['feature_importance']);
    final biasSources = _readList(model['bias_sources']);
    final simulation = _readMap(model['improvement_simulation']);
    final available = simulation['available'] == true;

    return SurfacePanel(
      accentColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Features',
            subtitle:
                'Feature importance, proxy-linked bias sources, and mitigation simulation.',
          ),
          const SizedBox(height: 16),
          if (_auditResult == null)
            const EmptyState(message: 'Run a full audit.')
          else ...[
            _barList(
              title: 'Feature importance',
              data: importances.map((entry) {
                final row = _readMap(entry);
                return _BarDatum(
                  label:
                      '${_readString(row['rank'], fallback: '-')}. ${_readString(row['feature'], fallback: 'Feature')}',
                  value: _readDouble(row['normalized_importance']),
                  color: AppColors.primary,
                  trailing: _formatNumber(row['importance']),
                );
              }).toList(),
              empty: 'Feature importance is not available for this model.',
            ),
            const SizedBox(height: 16),
            _dynamicTable(
              title: 'Bias sources',
              rows: biasSources,
              empty: 'No top feature/proxy overlaps returned.',
              preferredColumns: const ['feature', 'rank', 'proxy_links'],
            ),
            const SizedBox(height: 16),
            Text('Mitigation simulation',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (simulation.isEmpty)
              const EmptyState(message: 'No simulation data returned.')
            else if (!available)
              EmptyState(
                message: _readString(
                  simulation['reason'] ?? simulation['recommended_next_step'],
                  fallback: 'Simulation is unavailable.',
                ),
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  MetricTile(
                    label: 'Accuracy',
                    value: _percent(simulation['accuracy']),
                  ),
                  MetricTile(
                    label: 'Max DP',
                    value: _formatNumber(
                      simulation['max_demographic_parity_difference'],
                    ),
                  ),
                  MetricTile(
                    label: 'Max EO',
                    value: _formatNumber(
                      simulation['max_equalized_odds_difference'],
                    ),
                  ),
                  MetricTile(
                    label: 'Dropped',
                    value: _readList(simulation['dropped_features'])
                        .length
                        .toString(),
                    detail:
                        _readList(simulation['dropped_features']).join(', '),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _readString(
                  simulation['note'],
                  fallback:
                      'Diagnostic simulation only; rerun governance before deployment.',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGeminiSection() {
    final report = _readMap(_auditResult?['report']);
    final reportId = _readString(_auditResult?['report_id'], fallback: '');
    final text = _readString(report['text'], fallback: '');
    final sections = _readList(report['sections']).map(_readMap).toList();
    final source = _readString(report['source'], fallback: 'Gemini analysis');
    return SurfacePanel(
      accentColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Analysis report',
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
          else if (sections.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections.map((section) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _readString(section['title'], fallback: 'Section'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _readString(section['content'], fallback: ''),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            SelectableText(
              text.isEmpty ? 'No report text returned.' : text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _barList({
    required String title,
    required List<_BarDatum> data,
    String empty = 'No chart data returned.',
    double? maxValue,
  }) {
    final rows = data.where((row) => row.label.trim().isNotEmpty).toList();
    if (rows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          EmptyState(message: empty),
        ],
      );
    }

    final max = maxValue ??
        rows.map((row) => row.value).fold<double>(
              0,
              (previous, value) => value > previous ? value : previous,
            );
    final effectiveMax = max <= 0 ? 1 : max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ...rows.take(14).map((row) {
          final widthFactor =
              (row.value / effectiveMax).clamp(0.02, 1.0).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      row.trailing,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.text),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: widthFactor,
                    minHeight: 10,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(row.color),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _traceCards(List<Object?> records, Map<String, dynamic> trace) {
    final mappedRecords =
        records.map(_readMap).where((row) => row.isNotEmpty).take(6).toList();
    if (mappedRecords.isEmpty) {
      return EmptyState(
        message: _readString(
          trace['reason'],
          fallback: 'No row-level audit trace records were generated.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Decision audit trace',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...mappedRecords.map((record) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfacePanel(
              padding: const EdgeInsets.all(14),
              backgroundColor: AppColors.surfaceLow,
              accentColor: AppColors.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Row ${_readString(record['row_id'], fallback: '-')}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      StatusPill(
                        label:
                            'Score ${_formatNumber(record['decision_score'])}',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prediction ${_formatCell(record['prediction'])}, actual ${_formatCell(record['actual'])}. ${_readString(record['risk_reason'], fallback: '')}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  _dynamicTable(
                    title: 'Top contributors',
                    rows: _readList(record['top_contributions']),
                    empty: 'No contributor details returned.',
                    preferredColumns: const [
                      'feature',
                      'value',
                      'baseline',
                      'contribution',
                      'direction',
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
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
    }.take(12).toList();

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

  List<Map<String, dynamic>> _traceabilityRows(
      Map<String, dynamic> traceability) {
    return [
      {'field': 'Run ID', 'value': traceability['run_id']},
      {'field': 'Created UTC', 'value': traceability['created_at_utc']},
      {
        'field': 'Dataset hash',
        'value': traceability['dataset_hash_sha256'],
      },
      {
        'field': 'Model fingerprint',
        'value': traceability['model_fingerprint_sha256'],
      },
      {'field': 'Policy', 'value': _formatCell(traceability['policy'])},
      {'field': 'User ID', 'value': traceability['user_id']},
      {'field': 'Persistence', 'value': traceability['persistence_mode']},
    ].where((row) {
      final value = row['value'];
      return value != null && value.toString().trim().isNotEmpty;
    }).toList();
  }

  String? _demoLabel(String demoId) {
    for (final demo in _demoDatasets) {
      if (demo.id == demoId) return demo.name;
    }
    return null;
  }

  String _policyLabel(String policyId) {
    for (final option in _policyOptions) {
      if (option.id == policyId) return option.label;
    }
    return policyId;
  }

  Future<void> _loadBackendCatalog() async {
    try {
      final demos = await widget.backendClient.listDemos();
      final config = await widget.backendClient.fetchGovernanceConfig();
      if (!mounted) return;
      setState(() {
        final loadedDemos = demos.where((demo) => demo.id.isNotEmpty).toList();
        if (loadedDemos.isNotEmpty) {
          _demoDatasets = loadedDemos;
        }
        final loadedPolicies =
            config.policies.where((option) => option.id.isNotEmpty).toList();
        if (loadedPolicies.isNotEmpty) {
          _policyOptions = loadedPolicies;
          if (!_hasOption(_policyOptions, _policyId)) {
            _policyId = _policyOptions.first.id;
          }
        }
        final loadedTemplates = config.reportTemplates
            .where((option) => option.id.isNotEmpty)
            .toList();
        if (loadedTemplates.isNotEmpty) {
          _reportTemplateOptions = loadedTemplates;
          if (!_hasOption(_reportTemplateOptions, _reportTemplate)) {
            _reportTemplate = _reportTemplateOptions.first.id;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusMessage =
            'Using bundled demo and policy metadata. Backend catalog request failed: $error';
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
      _statusMessage = 'Opening Google sign-in...';
    });
    try {
      await widget.auditRepository.signInWithGoogle();
      if (mounted) {
        setState(() {
          _guestMode = true;
          _statusMessage = 'Signed in. Future audits will save to Firestore.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _continueAsGuest() {
    setState(() {
      _guestMode = true;
      _errorMessage = null;
      _statusMessage =
          'Guest mode enabled. Sign in later to save audit history to Firestore.';
    });
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
    final demoName = _demoLabel(demoId);
    await _guarded('Loading ${demoName ?? 'demo dataset'}...', () async {
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
        _selectedResultTab = _ResultTab.preAudit;
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
        _selectedResultTab = _ResultTab.overview;
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
      _policyId = _hasOption(_policyOptions, defaultPolicy)
          ? defaultPolicy
          : _policyOptions.first.id;
      _reportTemplate = _hasOption(_reportTemplateOptions, 'full_report')
          ? 'full_report'
          : _reportTemplateOptions.first.id;
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
      _selectedResultTab = _ResultTab.overview;
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
      _policyId = _hasOption(_policyOptions, 'default_governance_v1')
          ? 'default_governance_v1'
          : _policyOptions.first.id;
      _reportTemplate = _hasOption(_reportTemplateOptions, 'full_report')
          ? 'full_report'
          : _reportTemplateOptions.first.id;
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
      _selectedResultTab = _ResultTab.overview;
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
    required this.onSignIn,
  });

  final AuditRepository repository;
  final User? user;
  final _AuditPage selectedPage;
  final ValueChanged<_AuditPage> onSelect;
  final VoidCallback onNewAudit;
  final VoidCallback onSignIn;

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
      accentColor: repository.enabled ? AppColors.warning : AppColors.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: 'Guest session',
            color: repository.enabled ? AppColors.warning : AppColors.error,
          ),
          const SizedBox(height: 10),
          Text(
            repository.enabled
                ? 'Sign in to save audit history.'
                : repository.disabledReason,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          if (repository.enabled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
          ],
        ],
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

class _BarDatum {
  const _BarDatum({
    required this.label,
    required this.value,
    required this.color,
    required this.trailing,
  });

  final String label;
  final double value;
  final Color color;
  final String trailing;
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

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'red':
    case 'critical':
    case 'high':
    case 'fail':
      return AppColors.error;
    case 'yellow':
    case 'medium':
    case 'warn':
      return AppColors.warning;
    case 'green':
    case 'low':
    case 'pass':
      return AppColors.success;
    default:
      return AppColors.primary;
  }
}

bool _hasOption(List<OptionItem> options, String id) {
  return options.any((option) => option.id == id);
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

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatNumber(Object? value) {
  if (value is num) return value.toStringAsFixed(value.abs() >= 10 ? 1 : 3);
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null) return '-';
  return parsed.toStringAsFixed(parsed.abs() >= 10 ? 1 : 3);
}

String _percent(Object? value) {
  if (value is num) return '${(value * 100).toStringAsFixed(1)}%';
  final parsed = num.tryParse(value?.toString() ?? '');
  if (parsed == null) return '-';
  return '${(parsed * 100).toStringAsFixed(1)}%';
}
