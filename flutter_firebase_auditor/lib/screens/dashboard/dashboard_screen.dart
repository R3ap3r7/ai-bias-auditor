import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_theme.dart';
import '../../core/routing/auth_guard.dart';
import '../../models/audit_record.dart';
import '../../services/audit_repository.dart';
import '../../services/backend_client.dart';
import '../../widgets/animated_fade_slide.dart';
import '../../widgets/code_pill.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/severity_badge.dart';
import '../audit/widgets/audit_results.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  Timer? _debounce;
  String _severityFilter = 'All';
  String _sortOrder = 'Newest';

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const _DashboardNavBar(),
      extendBodyBehindAppBar: true,
      body: GridBackground(
        child: StreamBuilder<List<AuditRecord>>(
          stream: AuditRepository.instance.watchRecentAudits(),
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
            final records = snapshot.data ?? [];
            
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 100)), // Appbar spacing
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DashboardHeader(),
                            const SizedBox(height: 32),
                            _DashboardMetrics(records: records, loading: loading),
                            const SizedBox(height: 32),
                            _FilterBar(
                              searchQuery: _searchQuery,
                              onSearchChanged: _onSearchChanged,
                              severityFilter: _severityFilter,
                              onSeverityChanged: (v) => setState(() => _severityFilter = v),
                              sortOrder: _sortOrder,
                              onSortChanged: (v) => setState(() => _sortOrder = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: _AuditList(
                          records: records, 
                          loading: loading, 
                          searchQuery: _searchQuery,
                          severityFilter: _severityFilter,
                          sortOrder: _sortOrder,
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 64)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardNavBar extends StatelessWidget implements PreferredSizeWidget {
  const _DashboardNavBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 24,
      flexibleSpace: ClipRect(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.7),
            border: const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
          ),
        ),
      ),
      leadingWidth: 120,
      leading: Padding(
        padding: const EdgeInsets.only(left: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back, color: AppColors.textMuted, size: 18),
            label: Text('Home', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
            onPressed: () => Navigator.pushNamed(context, '/'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hexagon, color: AppColors.textWhite, size: 24),
          const SizedBox(width: 8),
          Text('Themis', style: AppTypography.titleLarge.copyWith(color: AppColors.textWhite)),
        ],
      ),
      centerTitle: true,
      actions: [
        const Padding(
          padding: EdgeInsets.only(right: 24.0),
          child: UserAvatarMenu(),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class UserAvatarMenu extends StatelessWidget {
  const UserAvatarMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();
    
    final char = user.displayName?.isNotEmpty == true ? user.displayName![0].toUpperCase() : (user.email?.isNotEmpty == true ? user.email![0].toUpperCase() : '?');

    return PopupMenuButton(
      offset: const Offset(0, 48),
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.borderSubtle)),
      itemBuilder: (context) => <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          enabled: false,
          child: Text('My Account\n${user.email}', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/');
          },
          child: Text('Sign Out', style: AppTypography.bodyMedium.copyWith(color: AppColors.severityCritical)),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.accentPrimary, AppColors.accentSecondary]),
        ),
        alignment: Alignment.center,
        child: Text(char, style: AppTypography.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first ?? 'Auditor';
    
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back, $name', style: AppTypography.headlineMedium),
                const SizedBox(height: 8),
                Text('Here\'s your audit activity at a glance.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          GradientButton(
            text: 'New Audit →',
            onPressed: () => Navigator.pushNamed(context, '/audit'),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  final List<AuditRecord> records;
  final bool loading;

  const _DashboardMetrics({required this.records, required this.loading});

  @override
  Widget build(BuildContext context) {
    final total = records.length;
    final critical = records.where((r) => r.overallSeverity == 'Critical').length;
    final datasets = records.map((r) => r.datasetName).toSet().length;
    final lastAudit = records.isNotEmpty ? _timeAgo(records.first.createdAt) : '--';

    final compact = MediaQuery.of(context).size.width < 900;
    
    final cards = [
      _MetricCard(title: 'Total Audits', value: '$total', accentColor: Colors.blue),
      _MetricCard(title: 'Critical Findings', value: '$critical', accentColor: AppColors.severityCritical),
      _MetricCard(title: 'Datasets Audited', value: '$datasets', accentColor: Colors.yellow),
      _MetricCard(title: 'Last Audit', value: lastAudit, accentColor: Colors.green),
    ];

    if (loading) {
      return GridView.count(
        crossAxisCount: compact ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
        children: List.generate(4, (i) => const _SkeletonCard()),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 2 : 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: compact ? 2.0 : 2.5,
      ),
      itemBuilder: (context, i) => AnimatedFadeSlide(delay: i * 100, child: cards[i]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accentColor;

  const _MetricCard({required this.title, required this.value, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accentColor, width: 4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: AppTypography.labelMedium.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              Text(value, style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String severityFilter;
  final ValueChanged<String> onSeverityChanged;
  final String sortOrder;
  final ValueChanged<String> onSortChanged;

  const _FilterBar({required this.searchQuery, required this.onSearchChanged, required this.severityFilter, required this.onSeverityChanged, required this.sortOrder, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 900;
    
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: compact ? double.infinity : 280,
            child: TextField(
              onChanged: onSearchChanged, // already debounced locally
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search audits...',
                hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted, size: 16), onPressed: () => onSearchChanged('')) : null,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderSubtle)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accentPrimary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['All', 'Low', 'Medium', 'High', 'Critical'].map((s) {
                final active = severityFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSeverityChanged(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: active ? const LinearGradient(colors: [AppColors.accentPrimary, AppColors.accentSecondary]) : null,
                        color: active ? null : Colors.transparent,
                        border: Border.all(color: active ? Colors.transparent : AppColors.borderSubtle),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(s, style: AppTypography.bodySmall.copyWith(color: active ? Colors.white : AppColors.textMuted)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortOrder,
              dropdownColor: AppColors.surface,
              icon: const Icon(Icons.sort, color: AppColors.textMuted, size: 18),
              style: AppTypography.bodyMedium,
              items: ['Newest', 'Oldest', 'Highest Severity'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: AppTypography.bodyMedium))).toList(),
              onChanged: (v) { if (v != null) onSortChanged(v); },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditList extends StatelessWidget {
  final List<AuditRecord> records;
  final bool loading;
  final String searchQuery;
  final String severityFilter;
  final String sortOrder;

  const _AuditList({required this.records, required this.loading, required this.searchQuery, required this.severityFilter, required this.sortOrder});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(3, (i) => Padding(padding: const EdgeInsets.only(bottom: 16), child: const _SkeletonCard(height: 120))),
      );
    }
    
    if (records.isEmpty) return const _EmptyState();

    var filtered = records.where((r) {
      final matchesSearch = r.datasetName.toLowerCase().contains(searchQuery.toLowerCase()) || 
                            r.runId.toLowerCase().contains(searchQuery.toLowerCase()) ||
                            r.protectedAttributes.any((a) => a.toLowerCase().contains(searchQuery.toLowerCase()));
      final matchesSev = severityFilter == 'All' || r.overallSeverity == severityFilter;
      return matchesSearch && matchesSev;
    }).toList();

    if (sortOrder == 'Newest') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (sortOrder == 'Oldest') {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      Map<String, int> w = {'Critical': 4, 'High': 3, 'Medium': 2, 'Low': 1, 'Info': 0};
      filtered.sort((a, b) {
        final cmp = (w[b.overallSeverity] ?? 0).compareTo(w[a.overallSeverity] ?? 0);
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });
    }

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Center(child: Text('No audits match your filters.', style: AppTypography.bodyLarge.copyWith(color: AppColors.textMuted))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) => _AuditItemCard(record: filtered[i]),
    );
  }
}

class _AuditItemCard extends StatefulWidget {
  final AuditRecord record;
  const _AuditItemCard({required this.record});

  @override
  State<_AuditItemCard> createState() => _AuditItemCardState();
}

class _AuditItemCardState extends State<_AuditItemCard> {
  bool _hover = false;

  void _tap() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: const _ResultAppBar(showBack: true),
        extendBody: true,
        body: AuditResults(
          result: widget.record.rawResults,
          reportPdfUrl: AuditBackendClient().reportPdfUri(widget.record.runId).toString(),
          storageUrl: widget.record.traceStorageUrl,
        ),
        bottomNavigationBar: _StaticDashboardBottomActions(record: widget.record),
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    Color sevColor = AppColors.severityLow;
    if (widget.record.overallSeverity == 'Medium') sevColor = AppColors.severityMedium;
    if (widget.record.overallSeverity == 'High') sevColor = AppColors.severityHigh;
    if (widget.record.overallSeverity == 'Critical') sevColor = AppColors.severityCritical;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..translate(0.0, _hover ? -3.0 : 0.0),
          decoration: BoxDecoration(
            color: _hover ? const Color.fromRGBO(124, 58, 237, 0.06) : AppColors.surfaceElevated.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hover ? AppColors.accentPrimary.withOpacity(0.5) : AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 8,
                height: 120, // fixed height for visual cue
                decoration: BoxDecoration(
                  color: _hover ? sevColor : sevColor.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(widget.record.datasetName, style: AppTypography.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          CodePill(text: widget.record.datasetSource == 'upload' ? 'Upload' : 'Demo'),
                          const SizedBox(width: 16),
                          SeverityBadge(severity: widget.record.overallSeverity),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...widget.record.protectedAttributes.take(3).map((a) => CodePill(text: a)),
                          if (widget.record.protectedAttributes.length > 3)
                            CodePill(text: '+${widget.record.protectedAttributes.length - 3} more'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (widget.record.modelUsed != null) ...[
                            Text(widget.record.modelUsed!, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('·', style: TextStyle(color: AppColors.textMuted))),
                          ],
                          Text(widget.record.runId, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontFamily: 'monospace')),
                          const Spacer(),
                          Text(_timeAgo(widget.record.createdAt), style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()..translate(_hover ? 3.0 : 0.0, 0.0),
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBack;
  const _ResultAppBar({this.showBack = false});
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Themis Results'),
        leading: showBack ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) : null,
      );
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _StaticDashboardBottomActions extends StatelessWidget {
  final AuditRecord record;
  const _StaticDashboardBottomActions({required this.record});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Color.fromRGBO(24, 24, 27, 0.5),
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               OutlinedAccentButton(
                text: '← Dashboard',
                onPressed: () => Navigator.pop(context),
              ),
              GradientButton(
                text: 'Re-run Audit',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                   if (record.datasetSource != 'upload') {
                     Navigator.pushNamed(context, '/audit', arguments: record.datasetSource);
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded CSV required to re-run. Switch to New Audit.'), backgroundColor: AppColors.surfaceElevated));
                   }
                },
              ),
              TextButton(
                onPressed: () async {
                  final cfm = await showDialog<bool>(
                    context: context, 
                    builder: (c) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: const Text('Delete Audit?', style: TextStyle(color: Colors.white)),
                      content: const Text('This result will be permanently deleted.', style: TextStyle(color: AppColors.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: Colors.white))),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: AppColors.severityCritical))),
                      ],
                    )
                  );
                  if (cfm == true && context.mounted) {
                    await AuditRepository.instance.firestore?.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).collection('audits').doc(record.auditId).delete();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: Text('Delete Record', style: AppTypography.labelMedium.copyWith(color: AppColors.severityCritical)),
              )
            ],
          ),
        ),
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
          CustomPaint(size: const Size(80, 100), painter: _ShieldPainter()),
          const SizedBox(height: 32),
          Text('No audits yet', style: AppTypography.headlineSmall),
          const SizedBox(height: 16),
          Text('Run your first fairness audit to see results here.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          GradientButton(
            text: 'Start Your First Audit',
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

    canvas.drawPath(path, border);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SkeletonCard extends StatefulWidget {
  final double height;
  const _SkeletonCard({this.height = 100});
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
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
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [const Color(0xFF27272A), const Color(0xFF3F3F46), const Color(0xFF27272A)],
              stops: [0.0, _anim.value, 1.0],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
            ).createShader(bounds);
          },
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    );
  }
}

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 0) return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
  if (diff.inHours > 0) return '${diff.inHours} hours ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
  return 'Just now';
}
