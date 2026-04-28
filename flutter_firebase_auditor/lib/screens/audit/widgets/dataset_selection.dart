import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/animated_fade_slide.dart';
import '../../../widgets/severity_badge.dart' as import_severity;

class DatasetSelection extends StatefulWidget {
  final Future<void> Function(PlatformFile file) onFileUploaded;
  final Future<void> Function(String demoId) onDemoSelected;
  final bool isLoading;

  const DatasetSelection({
    super.key,
    required this.onFileUploaded,
    required this.onDemoSelected,
    required this.isLoading,
  });

  @override
  State<DatasetSelection> createState() => _DatasetSelectionState();
}

class _DatasetSelectionState extends State<DatasetSelection> {
  PlatformFile? _selectedFile;
  String? _selectedDemo;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _selectedDemo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 768;
            
            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUploadCard(),
                  const SizedBox(height: 24),
                  _buildDemoCard(),
                ],
              );
            } else {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildUploadCard()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDemoCard()),
                  ],
                ),
              );
            }
          }
        ),
        _buildTipsRow(),
        const SizedBox(height: 128), // Spacing XXL for the bottom
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 48.0, bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [AppColors.accentPrimary, AppColors.accentSecondary]),
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Text('Audit Workspace', style: AppTypography.headlineLarge.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Upload a CSV dataset or select a benchmark to begin your fairness audit.',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.borderSubtle, height: 1),
        ],
      ),
    );
  }

  Widget _buildTipsRow() {
    return AnimatedFadeSlide(
      delay: 400,
      child: Padding(
        padding: const EdgeInsets.only(top: 32.0),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: const [
            _TipPill(icon: Icons.lock, text: 'Data stays in memory only'),
            _TipPill(icon: Icons.bolt, text: 'Results in under 60 seconds'),
            _TipPill(icon: Icons.description, text: 'CSV format required'),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return AnimatedFadeSlide(
      delay: 100,
      child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Your Dataset', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text('Drop in a CSV file to begin your fairness audit.', style: AppTypography.bodyMedium),
          const SizedBox(height: 24),
          _UploadDropZone(
            isLoading: widget.isLoading,
            selectedFile: _selectedFile,
            onPickFile: _pickFile,
          ),

          if (_selectedFile != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_selectedFile!.name, style: AppTypography.bodyMedium.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedFile = null),
                    child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: 'Upload Dataset',
              isLoading: widget.isLoading && _selectedFile != null,
              onPressed: _selectedFile == null ? null : () => widget.onFileUploaded(_selectedFile!),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDemoCard() {
    final demos = [
      {'id': 'compas', 'name': 'COMPAS Criminal Justice', 'desc': '7,214 defendants · Race & gender bias analysis', 'color': const Color(0xFFF87171)},
      {'id': 'adult', 'name': 'UCI Adult Income', 'desc': '48,842 records · Sex & race income prediction', 'color': const Color(0xFACC15)},
      {'id': 'german', 'name': 'German Credit Risk', 'desc': '1,000 applicants · Age-based credit risk', 'color': const Color(0xFF4ADE80)},
    ];

    return AnimatedFadeSlide(
      delay: 200,
      child: GlassCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Try a Demo Dataset', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text('Experiment with predefined benchmark datasets.', style: AppTypography.bodyMedium),
          const SizedBox(height: 24),
          ...demos.map((d) {
            final isSelected = _selectedDemo == d['id'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _DemoCardItem(
                data: d,
                isSelected: isSelected,
                isLoading: widget.isLoading,
                onTap: () {
                  setState(() {
                    _selectedDemo = d['id'] as String;
                    _selectedFile = null;
                  });
                  widget.onDemoSelected(d['id'] as String);
                },
              ),
            );
          }),
        ],
      ),
      ),
    );
  }
}

class _UploadDropZone extends StatefulWidget {
  final bool isLoading;
  final PlatformFile? selectedFile;
  final VoidCallback onPickFile;

  const _UploadDropZone({required this.isLoading, required this.selectedFile, required this.onPickFile});

  @override
  State<_UploadDropZone> createState() => _UploadDropZoneState();
}

class _UploadDropZoneState extends State<_UploadDropZone> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onPickFile,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered ? const Color.fromRGBO(124, 58, 237, 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: DottedBorder(
            color: _isHovered ? const Color.fromRGBO(124, 58, 237, 1.0) : const Color.fromRGBO(124, 58, 237, 0.4),
            strokeWidth: 1.5,
            dashPattern: const [8, 4],
            borderType: BorderType.RRect,
            radius: const Radius.circular(AppDimensions.radiusLg),
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.accentPrimary),
                  const SizedBox(height: 16),
                  Text('Drop CSV file here', style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text('or click to browse', style: AppTypography.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoCardItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _DemoCardItem({
    required this.data,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_DemoCardItem> createState() => _DemoCardItemState();
}

class _DemoCardItemState extends State<_DemoCardItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: _isHovered 
            ? [BoxShadow(color: const Color.fromRGBO(124, 58, 237, 0.2), blurRadius: 24, spreadRadius: 0, offset: const Offset(0, 8))]
            : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Container(
            color: _isHovered ? const Color.fromRGBO(124, 58, 237, 0.08) : Colors.transparent,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    color: widget.data['color'] as Color,
                  ),
                  Expanded(
                    child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    elevated: true,
                    accentBorder: widget.isSelected,
                    onTap: widget.isLoading ? null : widget.onTap,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Text(widget.data['name'] as String, style: AppTypography.titleMedium),
                                  import_severity.SeverityBadge(severity: 'Low', label: 'Preloaded & Ready'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(widget.data['desc'] as String, style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.translationValues(_isHovered ? 3 : 0, 0, 0),
                          child: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        border: Border.all(color: const Color(0xFF3F3F46)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentPrimary),
          const SizedBox(width: 8),
          Text(text, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
