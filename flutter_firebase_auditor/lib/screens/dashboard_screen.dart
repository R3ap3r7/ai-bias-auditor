import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/audit_record.dart';
import '../services/audit_repository.dart';
import '../services/backend_client.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_shell.dart';

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
  final Set<String> _protectedAttributes = {};
  String? _outcomeColumn;
  String _auditMode = 'train';
  String _modelType = 'compare_all';
  bool _busy = false;
  String? _statusMessage;
  String? _errorMessage;
  Map<String, dynamic>? _preAuditResult;
  Map<String, dynamic>? _auditResult;

  static const _demoDatasets = {
    'compas': 'COMPAS',
    'adult': 'UCI Adult',
    'german_credit': 'German Credit',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final content = _buildWorkspace(compact);
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _AuditHistoryRail(repository: widget.auditRepository),
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
                child: _AuditHistoryRail(repository: widget.auditRepository),
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkspace(bool compact) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
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
              _buildConfiguration(compact),
              const SizedBox(height: 20),
              _buildPreAuditSection(),
              const SizedBox(height: 20),
              _buildPostAuditSection(),
              const SizedBox(height: 20),
              _buildTraceSection(),
              const SizedBox(height: 20),
              _buildGeminiSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
                'Audit datasets and models before decisions become operational.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (severity.isNotEmpty) _severityPill(severity),
      ],
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
                            value: 'uploaded_model',
                            child: Text('Use uploaded model'),
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
                        onChanged: _busy || _auditMode == 'uploaded_model'
                            ? null
                            : (value) => setState(
                                  () => _modelType = value ?? 'compare_all',
                                ),
                      ),
                    ),
                  ],
                ),
                if (_auditMode == 'uploaded_model') ...[
                  const SizedBox(height: 16),
                  _buildModelUpload(),
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

  Widget _buildModelUpload() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uploaded model',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _uploadedModel == null
                ? 'Accepted formats: .joblib, .pkl, .pickle from trusted sources only.'
                : '${_uploadedModel!.filename} loaded as ${_uploadedModel!.className}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickModel,
            icon: const Icon(Icons.model_training),
            label: const Text('Upload model file'),
          ),
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

  Future<void> _pickModel() async {
    final dataset = _dataset;
    if (dataset == null) {
      setState(
          () => _errorMessage = 'Load a dataset before uploading a model.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['joblib', 'pkl', 'pickle'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    await _guarded('Uploading model...', () async {
      final model = await widget.backendClient.uploadModel(
        sessionId: dataset.sessionId,
        file: result.files.single,
      );
      setState(() {
        _uploadedModel = model;
        _statusMessage = model.warning.isEmpty
            ? '${model.filename} loaded.'
            : '${model.filename} loaded. ${model.warning}';
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
        _statusMessage = widget.auditRepository.currentUser != null
            ? 'Full audit completed and saved to Firebase.'
            : 'Full audit completed. Firebase history is not enabled.';
      });
    });
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
    if (_auditMode == 'uploaded_model' && _uploadedModel == null) {
      setState(() => _errorMessage =
          'Upload a model before running uploaded-model audit.');
      return null;
    }

    setState(() => _errorMessage = null);
    return AuditPayload(
      sessionId: dataset.sessionId,
      protectedAttributes: _protectedAttributes.toList(),
      outcomeColumn: outcome,
      modelType:
          _auditMode == 'uploaded_model' ? 'logistic_regression' : _modelType,
      auditMode: _auditMode,
      modelId: _uploadedModel?.modelId,
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

    setState(() {
      _dataset = dataset;
      _protectedAttributes
        ..clear()
        ..addAll(defaultProtected);
      _outcomeColumn = defaultOutcome.isEmpty ? null : defaultOutcome;
      _modelType = _modelOptions.containsKey(defaultModel)
          ? defaultModel
          : 'compare_all';
      _auditMode = 'train';
      _uploadedModel = null;
      _preAuditResult = null;
      _auditResult = null;
      _statusMessage = '${dataset.name} loaded.';
      _errorMessage = null;
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

class _AuditHistoryRail extends StatelessWidget {
  const _AuditHistoryRail({required this.repository});

  final AuditRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit history',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              repository.enabled
                  ? 'Google sign-in controls saved audit history.'
                  : repository.disabledReason,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            StreamBuilder<User?>(
              stream: repository.authStateChanges(),
              builder: (context, authSnapshot) {
                final user = authSnapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (repository.enabled && user == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: repository.signInWithGoogle,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                        ),
                      )
                    else if (user != null)
                      SurfacePanel(
                        padding: const EdgeInsets.all(14),
                        backgroundColor: AppColors.surface,
                        accentColor: AppColors.success,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'Signed in user',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email ?? user.uid,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: repository.signOut,
                              icon: const Icon(Icons.logout),
                              label: const Text('Sign out'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    StreamBuilder<List<AuditRecord>>(
                      stream: repository.watchRecentAudits(),
                      builder: (context, snapshot) {
                        final records = snapshot.data ?? const <AuditRecord>[];
                        if (records.isEmpty) {
                          return EmptyState(
                            message: user == null
                                ? 'Sign in to save and view audit history.'
                                : 'No saved audits yet.',
                          );
                        }
                        return Column(
                          children: records
                              .map(
                                (record) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SurfacePanel(
                                    padding: const EdgeInsets.all(14),
                                    backgroundColor: AppColors.surface,
                                    accentColor:
                                        _severityColor(record.severity),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                record.datasetName,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                            _severityPill(record.severity),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${record.modelName} | ${record.outcomeColumn}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: AppColors.muted),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          DateFormat('MMM d, HH:mm').format(
                                              record.createdAt.toLocal()),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
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
