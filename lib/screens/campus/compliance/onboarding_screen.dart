import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// 首次使用引导页
///
/// 使用 PageView 展示四页引导内容，带页面指示器和跳过按钮。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = <_OnboardingPage>[
    _OnboardingPage(
      icon: Icons.school_rounded,
      title: '欢迎来到相思同行',
      description: '你的智慧校园一站式服务平台',
    ),
    _OnboardingPage(
      icon: Icons.apps_rounded,
      title: '校园服务触手可及',
      description: '请假、报修、缴费、场馆预约一键搞定',
    ),
    _OnboardingPage(
      icon: Icons.smart_toy_rounded,
      title: 'AI 智能助理',
      description: '相思 AI 随时为你答疑解惑',
    ),
    _OnboardingPage(
      icon: Icons.public_rounded,
      title: '多元文化交融',
      description: '东盟六国语言，民族文化空间',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onFinish() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Page content
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) =>
                  _buildPage(context, _pages[index]),
            ),

            // Skip button
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _onFinish,
                child: Text('跳过',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            ),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Column(
                children: [
                  // Page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: AppConstants.animationDuration,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppConstants.primaryColor
                              : AppConstants.primaryColor
                                  .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Action button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          if (_currentPage == _pages.length - 1) {
                            _onFinish();
                          } else {
                            _pageController.nextPage(
                              duration: AppConstants.animationDuration,
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? '开始使用'
                              : '下一步',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _OnboardingPage page) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.primaryColor.withValues(alpha: 0.15),
                  AppConstants.accentColor.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 72, color: AppConstants.primaryColor),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style:
                theme.textTheme.bodyLarge?.copyWith(color: cs.outline),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
