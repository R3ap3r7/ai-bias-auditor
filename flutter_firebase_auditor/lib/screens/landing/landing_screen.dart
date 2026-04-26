import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/gradients.dart';
import '../../core/theme/shadows.dart';
import '../../widgets/animated_fade_slide.dart';
import '../../widgets/code_pill.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/navbar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/terminal_block.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _datasetsKey = GlobalKey();

  double _heroOffset = 0;
  double _aboutOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() {
      _heroOffset = _scrollController.offset * 0.3;
      _aboutOffset = _scrollController.offset * 0.15;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDatasets() {
    final context = _datasetsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: TheAppBar(
        showBack: false,
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final isLoggedIn = snapshot.hasData;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoggedIn)
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/dashboard'),
                      child: Text('Dashboard', style: AppTypography.bodyMedium),
                    ),
                  const SizedBox(width: 16),
                  GradientButton(
                    text: isLoggedIn ? 'Go to Dashboard' : 'Start Audit',
                    onPressed: () => Navigator.pushNamed(context, isLoggedIn ? '/dashboard' : '/audit'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: _HeroSection(
                offset: _heroOffset,
                onDemoTap: _scrollToDatasets,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: _MarqueeTicker(),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXxl * 1.5),
            sliver: SliverToBoxAdapter(child: _FeaturesSection()),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXxl * 1.5),
            sliver: SliverToBoxAdapter(child: _HowItWorksSection()),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingXxl * 1.5),
            sliver: SliverToBoxAdapter(
              key: _datasetsKey,
              child: const _DemoDatasetsSection(),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spacingXxl * 1.5),
            sliver: SliverToBoxAdapter(child: _BentoGridSection()),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingXxl * 1.5),
            sliver: SliverToBoxAdapter(
              child: RepaintBoundary(
                child: _AboutSection(offset: _aboutOffset),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: _FooterSection(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// SECTION 1: HERO
// ---------------------------------------------------------
class _HeroSection extends StatefulWidget {
  final double offset;
  final VoidCallback onDemoTap;

  const _HeroSection({required this.offset, required this.onDemoTap});

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> with SingleTickerProviderStateMixin {
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.width < 768;

    return Container(
      height: size.height,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppGradients.heroGradient),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Blob Background
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, child) {
              return Positioned(
                top: size.height * 0.15 + (sin(_blobController.value * pi) * 40),
                right: size.width * 0.1 + (cos(_blobController.value * pi) * 20),
                child: Transform.translate(
                  offset: Offset(0, -widget.offset),
                  child: Container(
                    width: compact ? 300 : 500,
                    height: compact ? 300 : 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentPrimary.withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentSecondary.withOpacity(0.1),
                          blurRadius: 100,
                          spreadRadius: 100,
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accentPrimary, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Open Source · Privacy First', style: AppTypography.labelMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Detect Bias Before\nIt Causes Harm',
                  textAlign: TextAlign.center,
                  style: compact ? AppTypography.displayMedium : AppTypography.displayLarge,
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Text(
                    'AI Bias Auditor is a local, privacy-first fairness auditing tool for machine learning models. Analyze representation imbalance, proxy variables, demographic parity, and more — all on your machine, with zero data leaving it.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 48),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    GradientButton(
                      text: FirebaseAuth.instance.currentUser != null ? 'Go to Dashboard' : 'Start Your Audit',
                      onPressed: () => Navigator.pushNamed(context, FirebaseAuth.instance.currentUser != null ? '/dashboard' : '/audit'),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    OutlinedAccentButton(
                      text: 'View Demo Datasets',
                      onPressed: widget.onDemoTap,
                    ),
                  ],
                ),
                const SizedBox(height: 64),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    const AnimatedFadeSlide(delay: 100, child: _HeroStatChip(icon: Icons.grid_view_rounded, text: '9 ML Algorithms')),
                    const AnimatedFadeSlide(delay: 200, child: _HeroStatChip(icon: Icons.balance, text: '6 Fairness Metrics')),
                    const AnimatedFadeSlide(delay: 300, child: _HeroStatChip(icon: Icons.lock_outline, text: '100% Local Processing')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroStatChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 18),
          const SizedBox(width: 8),
          Text(text, style: AppTypography.titleMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// SECTION 2: MARQUEE TICKER
// ---------------------------------------------------------
class _MarqueeTicker extends StatefulWidget {
  const _MarqueeTicker();

  @override
  State<_MarqueeTicker> createState() => _MarqueeTickerState();
}

class _MarqueeTickerState extends State<_MarqueeTicker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final String _text = 'Demographic Parity · Equalized Odds · Disparate Impact · Proxy Variables · Intersectional Bias · COMPAS Dataset · UCI Adult · German Credit · Fairlearn · Decision Traces · PDF Reports · Local & Private · ';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FractionalTranslation(
            translation: Offset(-_controller.value, 0),
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(_text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted, fontSize: 16)),
            Text(_text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted, fontSize: 16)),
            Text(_text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SECTION 3: FEATURES
// ---------------------------------------------------------
class _FeaturesSection extends StatefulWidget {
  const _FeaturesSection();

  @override
  State<_FeaturesSection> createState() => _FeaturesSectionState();
}

class _FeaturesSectionState extends State<_FeaturesSection> {
  bool _isVisible = false;

  final features = [
    {
      'icon': Icons.search,
      'title': 'Data Pre-Audit',
      'desc': 'Before training a single model, understand your data. Analyze representation balance across protected groups, surface proxy variables that silently encode sensitive attributes, and receive a severity rating from Low to Critical.'
    },
    {
      'icon': Icons.balance,
      'title': 'Fairness Metrics',
      'desc': 'Six industry-standard fairness metrics computed per protected attribute: Demographic Parity, Equalized Odds, Disparate Impact, and more. Results broken down by group with human-readable explanations.'
    },
    {
      'icon': Icons.memory,
      'title': 'Model Comparison Engine',
      'desc': 'Run GridSearchCV across 9 ML algorithms simultaneously. Models ranked by balanced accuracy minus fairness gaps — find models that are both accurate AND fair, not just one or the other.'
    },
    {
      'icon': Icons.link,
      'title': 'Proxy Variable Detection',
      'desc': 'Correlation-based analysis identifies features acting as stand-ins for protected attributes. Priors count, zip code, charge degree — flagged before your model learns them.'
    },
    {
      'icon': Icons.rule,
      'title': 'Decision Audit Traces',
      'desc': 'Every prediction is explainable. Row-level audit trails show which features drove each decision using a local perturbation-based explainer. No cloud calls, no SHAP dependency.'
    },
    {
      'icon': Icons.lock,
      'title': '100% Local & Private',
      'desc': 'Your data never leaves your machine. No external API calls during auditing. All computation on your hardware. Optional Gemini integration for summaries is entirely opt-in.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('features-section'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1 && !_isVisible) {
          setState(() => _isVisible = true);
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SectionHeader(
                  title: 'Powerful Fairness Analysis',
                  subtitle: 'A complete fairness toolkit that works end-to-end — from raw data exploration to model comparison to exportable governance reports.',
                ),
                const SizedBox(height: 48),
                if (_isVisible)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 768;
                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: compact ? 1 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: compact ? 2.0 : 2.5,
                        ),
                        itemCount: features.length,
                        itemBuilder: (context, index) {
                          final f = features[index];
                          return AnimatedFadeSlide(
                            delay: index * 100,
                            child: GlassCard(
                              accentBorder: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPrimary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(f['icon'] as IconData, color: AppColors.accentPrimary),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(f['title'] as String, style: AppTypography.titleLarge),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Text(
                                      f['desc'] as String,
                                      style: AppTypography.bodyMedium,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SECTION 4: HOW IT WORKS
// ---------------------------------------------------------
class _HowItWorksSection extends StatefulWidget {
  const _HowItWorksSection();

  @override
  State<_HowItWorksSection> createState() => _HowItWorksSectionState();
}

class _HowItWorksSectionState extends State<_HowItWorksSection> {
  bool _isVisible = false;

  final steps = [
    {
      'title': 'Upload Your Data',
      'desc': 'Drop in any CSV dataset or pick from our included benchmarks.'
    },
    {
      'title': 'Configure Attributes',
      'desc': 'Select your protected attributes and your outcome column.'
    },
    {
      'title': 'Run the Audit',
      'desc': 'Analyze representation, train models, and create decision traces.'
    },
    {
      'title': 'Review & Export',
      'desc': 'Explore interactive results and download a comprehensive PDF report.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('how-it-works'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.3 && !_isVisible) {
          setState(() => _isVisible = true);
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SectionHeader(
                  title: 'From Data to Decision in 4 Steps',
                  subtitle: 'The entire audit workflow runs locally in your browser session. No accounts, no servers, no waiting.',
                ),
                const SizedBox(height: 48),
                if (_isVisible)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 768;
                      if (compact) {
                        return Column(
                          children: List.generate(steps.length, (i) {
                            return AnimatedFadeSlide(
                              delay: i * 150,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24.0),
                                child: Row(
                                  children: [
                                    _StepCircle(number: i + 1),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(steps[i]['title']!, style: AppTypography.titleLarge),
                                          const SizedBox(height: 4),
                                          Text(steps[i]['desc']!, style: AppTypography.bodyMedium),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(steps.length, (i) {
                          return Expanded(
                            child: AnimatedFadeSlide(
                              delay: i * 150,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _StepCircle(number: i + 1),
                                      if (i < steps.length - 1)
                                        Expanded(
                                          child: Container(
                                            height: 2,
                                            margin: const EdgeInsets.symmetric(horizontal: 16),
                                            color: AppColors.border,
                                          ),
                                        ),
                                      if (i == steps.length - 1)
                                        const Spacer(),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(steps[i]['title']!, style: AppTypography.titleLarge),
                                  const SizedBox(height: 8),
                                  Text(steps[i]['desc']!, style: AppTypography.bodyMedium),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    }
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  const _StepCircle({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text('$number', style: AppTypography.titleLarge.copyWith(color: AppColors.accentPrimary)),
    );
  }
}

// ---------------------------------------------------------
// SECTION 5: DEMO DATASETS
// ---------------------------------------------------------
class _DemoDatasetsSection extends StatelessWidget {
  const _DemoDatasetsSection();

  final demos = const [
    {
      'tag': 'Criminal Justice',
      'title': 'COMPAS Criminal Justice',
      'desc': 'The COMPAS recidivism dataset used in the landmark ProPublica investigation. 7,214 defendants.',
      'stats': '7,214 rows · 10 columns · Race, Gender, Age',
      'id': 'compas'
    },
    {
      'tag': 'Economic Fairness',
      'title': 'UCI Adult Income',
      'desc': 'Census income data used to predict whether a person earns >\$50K/year. A classic benchmark.',
      'stats': '48,842 rows · 14 columns · Sex, Race',
      'id': 'adult'
    },
    {
      'tag': 'Financial Risk',
      'title': 'German Credit Risk',
      'desc': 'Credit risk classification dataset from the UCI repository. Used to identify age-based discrimination.',
      'stats': '1,000 rows · 20 columns · Age',
      'id': 'german'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Start with a Real-World Dataset',
                subtitle: 'Three landmark fairness datasets pre-loaded and ready. No downloads required.',
              ),
              const SizedBox(height: 48),
              SizedBox(
                height: 280,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: demos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final d = demos[i];
                    return SizedBox(
                      width: 350,
                      child: GlassCard(
                        accentBorder: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                              child: Text(d['tag']!, style: AppTypography.labelMedium.copyWith(color: AppColors.accentPrimary)),
                            ),
                            const SizedBox(height: 16),
                            Text(d['title']!, style: AppTypography.titleLarge),
                            const SizedBox(height: 8),
                            Text(d['desc']!, style: AppTypography.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Text(d['stats']!, style: AppTypography.bodySmall),
                            const SizedBox(height: 16),
                            GradientButton(
                              text: 'Load Dataset →',
                              onPressed: () => Navigator.pushNamed(context, '/audit', arguments: d['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SECTION 6: BENTO GRID
// ---------------------------------------------------------
class _BentoGridSection extends StatefulWidget {
  const _BentoGridSection();

  @override
  State<_BentoGridSection> createState() => _BentoGridSectionState();
}

class _BentoGridSectionState extends State<_BentoGridSection> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('bento-grid'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.2 && !_isVisible) {
          setState(() => _isVisible = true);
        }
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Built for Serious Auditing',
                  subtitle: 'By the numbers',
                ),
                const SizedBox(height: 48),
                if (_isVisible)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 768;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          // Stats Card (Wide)
                          SizedBox(
                            width: compact ? double.infinity : (constraints.maxWidth - 16) * 0.65,
                            child: AnimatedFadeSlide(
                              delay: 0,
                              child: GlassCard(
                                padding: const EdgeInsets.all(32),
                                child: Wrap(
                                  spacing: 32,
                                  runSpacing: 32,
                                  alignment: WrapAlignment.spaceAround,
                                  children: [
                                    _CounterStat(target: 9, label: 'ML Algorithms Compared'),
                                    _CounterStat(target: 6, label: 'Fairness Metrics'),
                                    _CounterStat(target: 3, label: 'Demo Datasets'),
                                    _CounterStat(target: 0, label: 'Data Leaves Your Machine', suffix: ' Bytes'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // GitHub Card
                          SizedBox(
                            width: compact ? double.infinity : (constraints.maxWidth - 16) * 0.35 - 1,
                            child: AnimatedFadeSlide(
                              delay: 100,
                              child: GlassCard(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.code, color: AppColors.accentPrimary),
                                        const SizedBox(width: 8),
                                        Text('Open Source', style: AppTypography.labelMedium),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Apache 2.0 Licensed', style: AppTypography.headlineSmall),
                                    const SizedBox(height: 8),
                                    Text('Free to use, fork, and deploy. No SaaS subscriptions.', style: AppTypography.bodyMedium),
                                    const SizedBox(height: 24),
                                    OutlinedAccentButton(
                                      text: 'View on GitHub',
                                      icon: const Icon(Icons.link),
                                      onPressed: () => launchUrl(Uri.parse('https://github.com/TheVijayVignesh/Themis')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Chart Card
                          SizedBox(
                            width: compact ? double.infinity : (constraints.maxWidth - 16) * 0.5,
                            child: AnimatedFadeSlide(
                              delay: 200,
                              child: GlassCard(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Demographic Parity Gap', style: AppTypography.titleLarge),
                                    const SizedBox(height: 24),
                                    _AnimatedBar(label: 'Race (COMPAS)', value: 0.414, max: 0.5, color: AppColors.severityCritical),
                                    const SizedBox(height: 16),
                                    _AnimatedBar(label: 'Sex (UCI Adult)', value: 0.328, max: 0.5, color: AppColors.severityHigh),
                                    const SizedBox(height: 16),
                                    _AnimatedBar(label: 'Gender (COMPAS)', value: 0.142, max: 0.5, color: AppColors.severityMedium),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Tech Stack Card
                          SizedBox(
                            width: compact ? double.infinity : (constraints.maxWidth - 16) * 0.5 - 1,
                            child: AnimatedFadeSlide(
                              delay: 300,
                              child: GlassCard(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Built on solid foundations', style: AppTypography.titleLarge),
                                    const SizedBox(height: 8),
                                    Text('Peer-reviewed algorithms. Battle-tested libraries.', style: AppTypography.bodyMedium),
                                    const SizedBox(height: 24),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: const [
                                        CodePill(text: 'Python 3.12'),
                                        CodePill(text: 'FastAPI'),
                                        CodePill(text: 'scikit-learn'),
                                        CodePill(text: 'Fairlearn'),
                                        CodePill(text: 'Flutter'),
                                        CodePill(text: 'Firebase'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterStat extends StatelessWidget {
  final int target;
  final String label;
  final String suffix;

  const _CounterStat({required this.target, required this.label, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target.toDouble()),
          duration: const Duration(seconds: 2),
          builder: (context, value, child) {
            return Text(
              '${value.toInt()}$suffix',
              style: AppTypography.displayMedium.copyWith(color: AppColors.textWhite),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTypography.labelMedium, textAlign: TextAlign.center),
      ],
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _AnimatedBar({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textWhite)),
            Text(value.toString(), style: AppTypography.codeMedium),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value / max),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return FractionallySizedBox(
                  widthFactor: val,
                  child: Container(
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------
// SECTION 7: ABOUT
// ---------------------------------------------------------
class _AboutSection extends StatelessWidget {
  final double offset;
  const _AboutSection({required this.offset});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
      ),
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 800;
                final content = [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Why We Built This', subtitle: 'Our Mission'),
                        const SizedBox(height: 24),
                        Text(
                          'Bias in machine learning isn\'t hypothetical — it\'s documented in hiring algorithms, credit scoring, medical diagnosis, and the criminal justice system. Most auditing tools require cloud access, meaning sensitive data leaves your organization.',
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI Bias Auditor was built on a single principle: fairness analysis should be accessible, local, and transparent. No SaaS subscription. No data upload to a third-party server. Just a tool you run, on your terms.',
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Built on top of scikit-learn and Microsoft\'s Fairlearn library, every metric we compute is grounded in peer-reviewed fairness research.',
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: 32),
                        GradientButton(
                          text: 'Run Your First Audit',
                          onPressed: () => Navigator.pushNamed(context, '/audit'),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) const SizedBox(width: 64),
                  if (compact) const SizedBox(height: 48),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(0, -offset * 0.1),
                      child: TerminalBlock(
                        lines: [
                          [TerminalSpan('\$ ', color: AppColors.textMuted), TerminalSpan('uvicorn app.main:app --reload')],
                          [TerminalSpan('✓ ', color: AppColors.severityLow), TerminalSpan('AI Bias Auditor running on http://localhost:8000')],
                          [TerminalSpan('✓ ', color: AppColors.severityLow), TerminalSpan('Demo datasets loaded')],
                          [TerminalSpan('✓ ', color: AppColors.severityLow), TerminalSpan('Fairlearn engine ready')],
                          [TerminalSpan('')],
                          [TerminalSpan('> ', color: AppColors.accentPrimary), TerminalSpan('Audit session started: run_0424', color: AppColors.textMuted)],
                          [TerminalSpan('> ', color: AppColors.accentPrimary), TerminalSpan('Protected attributes: [\'race\', \'gender\']', color: AppColors.textMuted)],
                          [TerminalSpan('')],
                          [TerminalSpan('> ', color: AppColors.accentPrimary), TerminalSpan('Demographic Parity Gap (race): '), TerminalSpan('0.414 ⚠ CRITICAL', color: AppColors.severityCritical)],
                          [TerminalSpan('> ', color: AppColors.accentPrimary), TerminalSpan('Proxy detected: '), TerminalSpan('c_charge_degree → corr 0.67', color: AppColors.severityMedium)],
                          [TerminalSpan('')],
                          [TerminalSpan('✓ ', color: AppColors.severityLow), TerminalSpan('Report saved: audit_report.pdf')],
                        ],
                      ),
                    ),
                  ),
                ];

                if (compact) {
                  return Column(children: content);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: content);
              }
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SECTION 8: FOOTER
// ---------------------------------------------------------
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(48.0),
            child: Wrap(
              spacing: 64,
              runSpacing: 32,
              alignment: WrapAlignment.spaceAround,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.security, color: AppColors.textWhite, size: 24),
                        const SizedBox(width: 8),
                        Text('AI Bias Auditor', style: AppTypography.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Local. Private. Fair.', style: AppTypography.bodyMedium),
                  ],
                ),
                Wrap(
                  spacing: 32,
                  children: [
                    TextButton(onPressed: () {}, child: Text('Features', style: AppTypography.bodyMedium)),
                    TextButton(onPressed: () {}, child: Text('How It Works', style: AppTypography.bodyMedium)),
                    TextButton(onPressed: () {}, child: Text('Datasets', style: AppTypography.bodyMedium)),
                  ],
                ),
                GradientButton(
                  text: 'Start Audit →',
                  onPressed: () => Navigator.pushNamed(context, '/audit'),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Built with FastAPI & Fairlearn · All processing is local · ', style: AppTypography.bodySmall),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('https://github.com/TheVijayVignesh/Themis')),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code, size: 16, color: AppColors.textWhite),
                      const SizedBox(width: 8),
                      Text('Open Source on GitHub', style: AppTypography.bodySmall.copyWith(decoration: TextDecoration.underline, color: AppColors.textWhite)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
