import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/audit_record.dart';
import '../../services/audit_repository.dart';
import '../../services/backend_client.dart';
import '../../widgets/code_pill.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/navbar.dart';
import '../../widgets/severity_badge.dart';
import '../audit/widgets/audit_results.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String _severityFilter = 'All';
  String _sortOrder = 'Newest';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TheAppBar(
        showBack: false,
        actions: [
          GradientButton(
            text: 'New Audit',
            onPressed: () => Navigator.pushNamed(context, '/audit'),
          )
        ],
      ),
      body: StreamBuilder<List<AuditRecord>>(
        stream: AuditRepository.instance.watchRecentAudits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ShimmerList();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: AppTypography.bodyLarge.copyWith(color: AppColors.severityCritical)));
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const _EmptyState();
          }

          // Compute summaries
          final total = records.length;
          final criticalFindings = records.where((r) => r.overallSeverity == 'Critical').length;
          final uniqueDatasets = records.map((r) => r.datasetName).toSet().length;
          final lastAudit = records.isNotEmpty ? _timeAgo(records.first.createdAt) : 'Never';

           // Apply filters
          var filtered = records.where((r) {
            final matchesSearch = r.datasetName.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesSeverity = _severityFilter == 'All' || r.overallSeverity == _severityFilter;
            return matchesSearch && matchesSeverity;
          }).toList();

          // Apply sort
          if (_sortOrder == 'Newest') {
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          } else if (_sortOrder == 'Oldest') {
            filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          } else if (_sortOrder == 'Severity') {
            final severityMap = {'Critical': 4, 'High': 3, 'Medium': 2, 'Low': 1, 'Info': 0};
            filtered.sort((a, b) {
              final aSev = severityMap[a.overallSeverity] ?? 0;
              final bSev = severityMap[b.overallSeverity] ?? 0;
              if (aSev != bSev) return bSev.compareTo(aSev);
              return b.createdAt.compareTo(a.createdAt);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Audit History', style: AppTypography.displayMedium),
                    const SizedBox(height: 8),
                    Text('All audits are stored securely per your account', style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 32),
                    
                    // Summaries
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _MetricCard(title: 'Total Audits', value: '$total'),
                        _MetricCard(title: 'Critical Findings', value: '$criticalFindings', color: AppColors.severityCritical),
                        _MetricCard(title: 'Datasets Audited', value: '$uniqueDatasets'),
                        _MetricCard(title: 'Last Audit', value: lastAudit),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Filter Bar
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Search
                          SizedBox(
                            width: 250,
                            child: TextField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              style: AppTypography.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'Search datasets...',
                                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                                filled: true,
                                fillColor: AppColors.surfaceElevated,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          // Severity Pills
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: ['All', 'Low', 'Medium', 'High', 'Critical'].map((s) {
                              final active = _severityFilter == s;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => setState(() => _severityFilter = s),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: active ? AppColors.accentPrimary.withOpacity(0.2) : AppColors.surfaceElevated,
                                      border: Border.all(color: active ? AppColors.accentPrimary : AppColors.border),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(s, style: AppTypography.bodySmall.copyWith(color: active ? AppColors.textPrimary : AppColors.textMuted)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          // Sort
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortOrder,
                              dropdownColor: AppColors.surfaceElevated,
                              items: ['Newest', 'Oldest', 'Severity'].map((v) => DropdownMenuItem(value: v, child: Text("Sort by: $v", style: AppTypography.bodyMedium))).toList(),
                              onChanged: (v) => setState(() => _sortOrder = v ?? 'Newest'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // List
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 64),
                          child: Text('No audits match your filters.', style: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          return GlassCard(
                            accentBorder: true,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: const TheAppBar(showBack: true),
                                  body: AuditResults(
                                    result: r.rawResults,
                                    reportPdfUrl: AuditBackendClient().reportPdfUri(r.runId).toString(),
                                    storageUrl: r.traceStorageUrl,
                                  ),
                                )
                              ));
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _SeverityDot(severity: r.overallSeverity),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(r.datasetName, style: AppTypography.titleLarge),
                                          const SizedBox(width: 8),
                                          CodePill(text: r.datasetSource),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: r.protectedAttributes.map((a) => Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: CodePill(text: a),
                                          )).toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (r.modelUsed != null) ...[
                                            Icon(Icons.memory, size: 14, color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(r.modelUsed!, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                                            const SizedBox(width: 16),
                                          ],
                                          Text('#${r.runId} • ${_timeAgo(r.createdAt)}', style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SeverityBadge(severity: r.overallSeverity),
                                const SizedBox(width: 16),
                                const Icon(Icons.chevron_right, color: AppColors.textMuted),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? color;

  const _MetricCard({required this.title, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.displayLarge.copyWith(color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(size: const Size(100, 120), painter: _ShieldPainter()),
          const SizedBox(height: 32),
          Text('No audits yet', style: AppTypography.headlineMedium),
          const SizedBox(height: 16),
          GradientButton(
            text: 'Run Your First Audit',
            onPressed: () => Navigator.pushNamed(context, '/audit'),
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentPrimary.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    final border = Paint()
      ..color = AppColors.accentPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.6);
    path.quadraticBezierTo(size.width / 2, size.height, size.width / 2, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height * 0.6);
    path.lineTo(0, size.height * 0.2);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color c = AppColors.severityLow;
    if (severity == 'Medium') c = AppColors.severityMedium;
    if (severity == 'High') c = AppColors.severityHigh;
    if (severity == 'Critical') c = AppColors.severityCritical;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }
}

class _ShimmerList extends StatefulWidget {
  const _ShimmerList();
  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return ListView.separated(
          padding: const EdgeInsets.all(32),
          itemCount: 3,
          separatorBuilder: (c, i) => const SizedBox(height: 16),
          itemBuilder: (c, i) {
            return Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [AppColors.surfaceElevated, AppColors.borderSubtle, AppColors.surfaceElevated],
                  stops: [0.0, _anim.value, 1.0],
                  begin: const Alignment(-1.0, -0.3),
                  end: const Alignment(1.0, 0.3),
                )
              ),
            );
          },
        );
      }
    );
  }
}

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}
