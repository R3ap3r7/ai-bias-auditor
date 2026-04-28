import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/toggle_switch.dart';
import '../../../widgets/code_pill.dart';
import '../../../services/backend_client.dart';

class ColumnConfig extends StatefulWidget {
  final DatasetSession session;
  final VoidCallback onStartOver;
  final Future<void> Function(AuditPayload payload) onRunPreAudit;
  final Future<void> Function(AuditPayload payload) onRunPostAudit;
  final bool isLoading;
  final bool highlightPostAudit;

  const ColumnConfig({
    super.key,
    required this.session,
    required this.onStartOver,
    required this.onRunPreAudit,
    required this.onRunPostAudit,
    required this.isLoading,
    this.highlightPostAudit = false,
  });

  @override
  State<ColumnConfig> createState() => _ColumnConfigState();
}

class _ColumnConfigState extends State<ColumnConfig> {
  final Set<String> _protectedAttributes = {};
  String? _outcomeColumn;
  String _modelType = 'compare_all';
  String _auditMode = 'train';
  bool _showHighlight = false;

  @override
  void initState() {
    super.initState();
    final defaults = widget.session.defaults;
    if (defaults['protected_attributes'] != null) {
      _protectedAttributes.addAll(List<String>.from(defaults['protected_attributes']));
    }
    if (defaults['outcome_column'] != null) {
      _outcomeColumn = defaults['outcome_column'];
    }
    if (defaults['model_type'] != null) {
      _modelType = defaults['model_type'];
    }
    
    if (_outcomeColumn == null && widget.session.columns.isNotEmpty) {
      _outcomeColumn = widget.session.columns.last;
    }
    
    if (widget.highlightPostAudit) {
      _showHighlight = true;
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showHighlight = false);
      });
    }
  }

  AuditPayload _buildPayload() {
    return AuditPayload(
      sessionId: widget.session.sessionId,
      protectedAttributes: _protectedAttributes.toList(),
      outcomeColumn: _outcomeColumn ?? widget.session.columns.last,
      modelType: _modelType,
      auditMode: _auditMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SectionHeader(
                  title: 'Column Configuration',
                  subtitle: '${widget.session.rowCount} rows, ${widget.session.columnCount} columns loaded from ${widget.session.name}',
                ),
              ),
              OutlinedButton(
                onPressed: widget.isLoading ? null : widget.onStartOver,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Start Over'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Select Protected Attributes', style: AppTypography.titleLarge),
          const SizedBox(height: 8),
          Text('Select at least one attribute to audit for bias (e.g., race, gender, age).', style: AppTypography.bodyMedium),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.session.columns.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final col = widget.session.columns[index];
                final isProtected = _protectedAttributes.contains(col);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isProtected) {
                        _protectedAttributes.remove(col);
                      } else {
                        _protectedAttributes.add(col);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: isProtected ? AppColors.accentPrimary.withOpacity(0.05) : Colors.transparent,
                    child: Row(
                      children: [
                        CodePill(text: col),
                        const Spacer(),
                        Text('Protected Attribute', style: AppTypography.bodySmall.copyWith(color: isProtected ? AppColors.accentPrimary : AppColors.textMuted)),
                        const SizedBox(width: 12),
                        CustomToggle(value: isProtected),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              
              Widget dd1() => _buildDropdown('Outcome Column', _outcomeColumn, widget.session.columns, (v) => setState(() => _outcomeColumn = v));
              Widget dd2() => _buildDropdown('Model Type', _modelType, ['compare_all', 'logistic_regression', 'random_forest', 'gradient_boosting', 'xgboost', 'lightgbm'], (v) => setState(() => _modelType = v!));
              Widget dd3() => _buildDropdown('Post-Audit Model Source', _auditMode, ['train', 'uploaded_model', 'prediction_csv'], (v) => setState(() => _auditMode = v!));

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dd1(),
                    const SizedBox(height: 16),
                    dd2(),
                    const SizedBox(height: 16),
                    dd3(),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(child: dd1()),
                    const SizedBox(width: 16),
                    Expanded(child: dd2()),
                    const SizedBox(width: 16),
                    Expanded(child: dd3()),
                  ],
                );
              }
            }
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              OutlinedAccentButton(
                text: 'Run Data Pre-Audit',
                icon: const Icon(Icons.search),
                onPressed: widget.isLoading || _protectedAttributes.isEmpty ? null : () => widget.onRunPreAudit(_buildPayload()),
              ),
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GradientButton(
                    text: 'Run Post-Model Audit',
                    icon: const Icon(Icons.bolt),
                    isLoading: widget.isLoading,
                    onPressed: widget.isLoading || _protectedAttributes.isEmpty ? null : () => widget.onRunPostAudit(_buildPayload()),
                  ),
                  if (_showHighlight)
                    Positioned(
                      top: -36,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, val, child) => Transform.translate(
                          offset: Offset(0, (1 - val) * 10),
                          child: Opacity(opacity: val, child: child),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentPrimary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_downward, size: 14, color: AppColors.textWhite),
                              const SizedBox(width: 4),
                              Text('Tap to run full audit', style: AppTypography.labelMedium.copyWith(color: AppColors.textWhite)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTypography.labelMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : (options.isNotEmpty ? options.first : null),
              isExpanded: true,
              dropdownColor: AppColors.surfaceElevated,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textWhite),
              onChanged: onChanged,
              items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: AppTypography.bodyMedium.copyWith(color: AppColors.textWhite)))).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
