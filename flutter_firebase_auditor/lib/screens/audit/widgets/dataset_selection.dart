import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/gradient_button.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 768;
        final children = [
          Expanded(flex: isCompact ? 0 : 1, child: _buildUploadCard()),
          if (isCompact) const SizedBox(height: 24) else const SizedBox(width: 24),
          Expanded(flex: isCompact ? 0 : 1, child: _buildDemoCard()),
        ];
        
        if (isCompact) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
        } else {
          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          );
        }
      }
    );
  }

  Widget _buildUploadCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload Your Dataset', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          Text('Drop in a CSV file to begin your fairness audit.', style: AppTypography.bodyMedium),
          const SizedBox(height: 24),
          InkWell(
            onTap: widget.isLoading ? null : _pickFile,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: DottedBorder(
              color: AppColors.accentPrimary,
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
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.severityLow, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_selectedFile!.name, style: AppTypography.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedFile = null),
                    child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
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
    );
  }

  Widget _buildDemoCard() {
    final demos = [
      {'id': 'compas', 'name': 'COMPAS Criminal Justice'},
      {'id': 'adult', 'name': 'UCI Adult Income'},
      {'id': 'german', 'name': 'German Credit Risk'},
    ];

    return GlassCard(
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
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                elevated: true,
                accentBorder: isSelected,
                onTap: widget.isLoading ? null : () {
                  setState(() {
                    _selectedDemo = d['id']!;
                    _selectedFile = null;
                  });
                  widget.onDemoSelected(d['id']!);
                },
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(d['name']!, style: AppTypography.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.severityLow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.severityLow, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Preloaded & Ready', style: AppTypography.labelMedium.copyWith(color: AppColors.severityLow)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
