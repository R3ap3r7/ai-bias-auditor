import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/gradients.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/code_pill.dart';
import '../../../widgets/severity_badge.dart';
import '../../../widgets/metric_card.dart';
import '../../../widgets/custom_tab_bar.dart';
import '../../../widgets/animated_fade_slide.dart';

class AuditResults extends StatefulWidget {
  final Map<String, dynamic> result;
  final String reportPdfUrl;
  final String? storageUrl;

  const AuditResults({super.key, required this.result, required this.reportPdfUrl, this.storageUrl});

  @override
  State<AuditResults> createState() => _AuditResultsState();
}

class _AuditResultsState extends State<AuditResults> {
  int _currentTab = 0;
  late final List<String> _tabs;
  late final Map<String, dynamic> _preAudit;
  late final Map<String, dynamic>? _postAudit;
  late final Map<String, dynamic>? _governance;
  late final Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _preAudit = widget.result['pre_audit'] ?? {};
    _postAudit = widget.result['model'];
    _governance = widget.result['governance'];
    _report = widget.result['report'];

    final tabs = ['Overview', 'Data Pre-Audit'];
    if (_postAudit != null && _postAudit!['bias_metrics'] != null) {
      tabs.add('Bias Scorecard');
    }
    if (_postAudit != null && _postAudit!['model_comparison'] != null) {
      tabs.add('Model Comparison');
    }
    if (_postAudit != null && (_postAudit!['audit_trace'] != null || widget.storageUrl != null)) {
      tabs.add('Decision Traces');
    }
    if (_report != null && _report!['text'] != null) {
      tabs.add('Report');
    }
    _tabs = tabs;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTabBar(
          labels: _tabs,
          onTabChanged: (i) => setState(() => _currentTab = i),
        ),
        const SizedBox(height: 32),
        _buildCurrentTab(),
      ],
    );
  }

  Widget _buildCurrentTab() {
    final tabName = _tabs[_currentTab];
    switch (tabName) {
      case 'Overview':
        return AnimatedFadeSlide(key: const ValueKey('ov'), child: _OverviewTab(result: widget.result));
      case 'Data Pre-Audit':
        return AnimatedFadeSlide(key: const ValueKey('pre'), child: _PreAuditTab(preAudit: _preAudit));
      case 'Bias Scorecard':
        return AnimatedFadeSlide(key: const ValueKey('bias'), child: _BiasScorecardTab(model: _postAudit!));
      case 'Model Comparison':
        return AnimatedFadeSlide(key: const ValueKey('comp'), child: _ModelComparisonTab(model: _postAudit!));
      case 'Decision Traces':
        return AnimatedFadeSlide(key: const ValueKey('traces'), child: _DecisionTracesTab(model: _postAudit!, storageUrl: widget.storageUrl));
      case 'Report':
        return AnimatedFadeSlide(key: const ValueKey('rep'), child: _ReportTab(report: _report!, pdfUrl: widget.reportPdfUrl));
      default:
        return const SizedBox.shrink();
    }
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> result;
  const _OverviewTab({required this.result});

  @override
  Widget build(BuildContext context) {
    final dataset = result['dataset'] ?? {};
    final severity = result['severity'] ?? result['pre_audit_severity'] ?? 'Info';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Audit Overview'),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            final cards = [
              Expanded(
                flex: isCompact ? 0 : 1,
                child: MetricCard(
                  label: 'Dataset Profile',
                  value: '${dataset['rows'] ?? 0} rows',
                  description: '${dataset['columns'] ?? 0} columns',
                  accentColor: AppColors.accentBlue,
                ),
              ),
              if (isCompact) const SizedBox(height: 16) else const SizedBox(width: 16),
              Expanded(
                flex: isCompact ? 0 : 1,
                child: MetricCard(
                  label: 'Protected Attributes',
                  value: (dataset['protected_attributes'] as List?)?.length.toString() ?? '0',
                  description: 'Analyzed for bias',
                  accentColor: AppColors.accentSecondary,
                ),
              ),
              if (isCompact) const SizedBox(height: 16) else const SizedBox(width: 16),
              Expanded(
                flex: isCompact ? 0 : 1,
                child: GlassCard(
                  padding: const EdgeInsets.all(0),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OVERALL RISK', style: AppTypography.bodySmall),
                        const SizedBox(height: 12),
                        SeverityBadge(severity: severity),
                      ],
                    ),
                  ),
                ),
              ),
            ];
            if (isCompact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards);
            return Row(children: cards);
          }
        ),
      ],
    );
  }
}

class _PreAuditTab extends StatelessWidget {
  final Map<String, dynamic> preAudit;
  const _PreAuditTab({required this.preAudit});

  @override
  Widget build(BuildContext context) {
    final reps = (preAudit['representation'] as List?) ?? [];
    final proxies = (preAudit['proxy_flags'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Representation Balance', subtitle: 'Analyzing group distributions across protected attributes.'),
        const SizedBox(height: 24),
        ...reps.map((r) => _buildRepresentationChart(r)),
        const SizedBox(height: 48),
        const SectionHeader(title: 'Proxy Variable Detection', subtitle: 'Features strongly correlated with protected attributes.'),
        const SizedBox(height: 24),
        if (proxies.isEmpty)
          Text('No major proxy risks detected.', style: AppTypography.bodyMedium)
        else
          Wrap(
            spacing: 16, runSpacing: 16,
            children: proxies.map((p) => _buildProxyCard(p)).toList(),
          ),
      ],
    );
  }

  Widget _buildRepresentationChart(Map<String, dynamic> rep) {
    final attr = rep['protected_attribute'] ?? 'Unknown';
    final groups = (rep['groups'] as List?) ?? [];
    final Map<String, double> data = {};
    for (var g in groups) {
      data[g['group'].toString()] = (g['count'] as num).toDouble();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attribute: $attr', style: AppTypography.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: data.length * 40.0,
              child: _HorizontalBarChart(data: data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyCard(dynamic p) {
    return GlassCard(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CodePill(text: p['feature'].toString()),
              SeverityBadge(severity: p['risk'] ?? 'High'),
            ],
          ),
          const SizedBox(height: 16),
          Text('Correlated with:', style: AppTypography.bodySmall),
          const SizedBox(height: 4),
          Text(p['protected_attribute'].toString(), style: AppTypography.bodyLarge),
          const SizedBox(height: 8),
          Text('Strength: ${p['strength']}', style: AppTypography.bodyMedium.copyWith(color: AppColors.accentPrimary)),
        ],
      ),
    );
  }
}

class _BiasScorecardTab extends StatelessWidget {
  final Map<String, dynamic> model;
  const _BiasScorecardTab({required this.model});

  @override
  Widget build(BuildContext context) {
    final metrics = (model['bias_metrics'] as List?) ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Bias Scorecard', subtitle: 'Fairness metrics evaluated post-model training.'),
        const SizedBox(height: 24),
        ...metrics.map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: GlassCard(
              accentBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 24, color: AppColors.accentPrimary),
                      const SizedBox(width: 12),
                      Text(m['protected_attribute'].toString(), style: AppTypography.titleLarge),
                      const Spacer(),
                      SeverityBadge(severity: m['status'] ?? 'Info'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MetricCard(
                    label: m['metric'].toString(),
                    value: m['value'].toString(),
                    description: m['explanation']?.toString(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ModelComparisonTab extends StatelessWidget {
  final Map<String, dynamic> model;
  const _ModelComparisonTab({required this.model});

  @override
  Widget build(BuildContext context) {
    final comp = (model['model_comparison'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Model Comparison', subtitle: 'Ranking classifiers by balanced accuracy minus fairness gaps.'),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
            dataTextStyle: AppTypography.bodyMedium,
            border: TableBorder(horizontalInside: BorderSide(color: AppColors.border, width: 1)),
            columns: const [
              DataColumn(label: Text('MODEL KEY')),
              DataColumn(label: Text('ACCURACY')),
              DataColumn(label: Text('FAIRNESS SCORE')),
              DataColumn(label: Text('STATUS')),
            ],
            rows: comp.map((c) {
              final isSelected = c['selected'] == true;
              return DataRow(
                color: MaterialStateProperty.resolveWith((states) => isSelected ? AppColors.accentPrimary.withOpacity(0.1) : Colors.transparent),
                cells: [
                  DataCell(Row(
                    children: [
                      Text(c['model_key'].toString()),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(gradient: AppGradients.accentGradient, borderRadius: BorderRadius.circular(4)),
                          child: Text('WINNER', style: AppTypography.bodySmall.copyWith(color: AppColors.textWhite)),
                        )
                      ]
                    ],
                  )),
                  DataCell(Text(c['accuracy']?.toString() ?? '-')),
                  DataCell(Text(c['audit_selection_score']?.toString() ?? '-')),
                  DataCell(SeverityBadge(severity: c['status']?.toString() ?? 'Info')),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DecisionTracesTab extends StatefulWidget {
  final Map<String, dynamic> model;
  final String? storageUrl;
  const _DecisionTracesTab({required this.model, this.storageUrl});

  @override
  State<_DecisionTracesTab> createState() => _DecisionTracesTabState();
}

class _DecisionTracesTabState extends State<_DecisionTracesTab> {
  int _rowsPerPage = 10;
  bool _loading = false;
  List<dynamic> _records = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final trace = widget.model['audit_trace'];
    if (trace != null && trace['records'] != null) {
      setState(() => _records = trace['records'] as List);
      return;
    }
    
    if (widget.storageUrl != null) {
      setState(() => _loading = true);
      try {
        final res = await http.get(Uri.parse(widget.storageUrl!));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() => _records = data['records'] ?? []);
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Decision Audit Traces', subtitle: 'Row-level explainability for individual predictions.'),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary))
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                cardColor: AppColors.surface,
                dataTableTheme: DataTableThemeData(
                  headingTextStyle: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              child: PaginatedDataTable(
                rowsPerPage: _rowsPerPage,
                availableRowsPerPage: const [10, 20, 50],
                onRowsPerPageChanged: (v) => setState(() => _rowsPerPage = v!),
                columns: const [
                  DataColumn(label: Text('ROW ID')),
                  DataColumn(label: Text('PREDICTION')),
                  DataColumn(label: Text('PROTECTED ATTRS')),
                  DataColumn(label: Text('REASONING')),
                ],
                source: _TraceDataSource(_records),
              ),
            ),
          ),
      ],
    );
  }
}

class _TraceDataSource extends DataTableSource {
  final List<dynamic> records;
  _TraceDataSource(this.records);

  @override
  DataRow? getRow(int index) {
    if (index >= records.length) return null;
    final r = records[index];
    return DataRow(cells: [
      DataCell(CodePill(text: r['row_id'].toString())),
      DataCell(Text(r['prediction'].toString(), style: AppTypography.bodyMedium)),
      DataCell(Text(r['protected_attributes']?.toString() ?? '-', style: AppTypography.bodySmall)),
      DataCell(Text(r['risk_reason']?.toString() ?? '-', style: AppTypography.bodySmall)),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => records.length;
  @override
  int get selectedRowCount => 0;
}

class _ReportTab extends StatelessWidget {
  final Map<String, dynamic> report;
  final String pdfUrl;
  const _ReportTab({required this.report, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    final text = report['text']?.toString() ?? 'Report generation failed.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Governance Report'),
            GradientButton(
              text: 'Download PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => launchUrl(Uri.parse(pdfUrl)),
            )
          ],
        ),
        const SizedBox(height: 24),
        GlassCard(
          child: SelectableText(
            text,
            style: AppTypography.bodyMedium.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }
}


// --- Charts ---

class _HorizontalBarChart extends StatefulWidget {
  final Map<String, double> data;
  const _HorizontalBarChart({required this.data});

  @override
  State<_HorizontalBarChart> createState() => _HorizontalBarChartState();
}

class _HorizontalBarChartState extends State<_HorizontalBarChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _controller.forward();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size(double.infinity, widget.data.length * 40.0),
        painter: _HorizontalBarPainter(widget.data, CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic).value),
      ),
    );
  }
}

class _HorizontalBarPainter extends CustomPainter {
  final Map<String, double> data;
  final double animation;

  _HorizontalBarPainter(this.data, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxVal = data.values.reduce((a, b) => a > b ? a : b);
    final textStyle = AppTypography.bodySmall.copyWith(color: AppColors.textMuted);
    
    double y = 0;
    const barHeight = 24.0;
    const maxLabelWidth = 100.0;
    
    for (final entry in data.entries) {
      final textPainter = TextPainter(
        text: TextSpan(text: entry.key, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxLabelWidth);
      
      textPainter.paint(canvas, Offset(0, y + (barHeight - textPainter.height) / 2));
      
      final barMaxWidth = size.width - maxLabelWidth - 50;
      final valueWidth = (maxVal == 0 ? 0 : entry.value / maxVal) * barMaxWidth * animation;
      
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(maxLabelWidth + 8, y, valueWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, Paint()..color = AppColors.accentPrimary);
      
      final valPainter = TextPainter(
        text: TextSpan(text: entry.value.toStringAsFixed(0), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      valPainter.paint(canvas, Offset(maxLabelWidth + 8 + valueWidth + 8, y + (barHeight - valPainter.height) / 2));
      
      y += 40.0;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalBarPainter old) => old.animation != animation;
}
