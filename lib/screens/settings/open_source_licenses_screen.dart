import 'package:flutter/material.dart';

import '../../utils/app_style.dart';
import '../../widgets/app_background.dart';

class OpenSourceLicensesScreen extends StatelessWidget {
  const OpenSourceLicensesScreen({super.key});

  static const List<_LicenseItem> _flutterDependencies = [
    _LicenseItem('flutter', 'BSD-3-Clause', 'https://github.com/flutter/flutter'),
    _LicenseItem('cupertino_icons', 'MIT', 'https://github.com/flutter/cupertino_icons'),
    _LicenseItem('flutter_markdown_plus', 'BSD-3-Clause', 'https://github.com/fzyzcjy/flutter_markdown'),
    _LicenseItem('flutter_inappwebview', 'Apache-2.0', 'https://github.com/pichillilorenzo/flutter_inappwebview'),
    _LicenseItem('flutter_highlight', 'MIT', 'https://github.com/git-touch/highlight.dart'),
    _LicenseItem('http', 'BSD-3-Clause', 'https://github.com/dart-lang/http'),
    _LicenseItem('file_picker', 'Apache-2.0', 'https://github.com/miguelpruivo/flutter_file_picker'),
    _LicenseItem('permission_handler', 'MIT', 'https://github.com/Baseflow/flutter-permission-handler'),
    _LicenseItem('path_provider', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/path_provider/path_provider'),
    _LicenseItem('provider', 'MIT', 'https://github.com/rrousselGit/provider'),
    _LicenseItem('shared_preferences', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/shared_preferences/shared_preferences'),
    _LicenseItem('flutter_secure_storage', 'BSD-3-Clause', 'https://github.com/juliansteenbakker/flutter_secure_storage'),
    _LicenseItem('url_launcher', 'BSD-3-Clause', 'https://github.com/flutter/packages/tree/main/packages/url_launcher/url_launcher'),
    _LicenseItem('markdown', 'BSD-3-Clause', 'https://github.com/dart-lang/tools/tree/main/pkgs/markdown'),
    _LicenseItem('webdav_client', 'MIT', 'https://github.com/xpwu/webdav_client'),
    _LicenseItem('ftpconnect', 'MIT', 'https://github.com/robertoszek/ftpconnect'),
    _LicenseItem('share_plus', 'BSD-3-Clause', 'https://github.com/fluttercommunity/plus_plugins/tree/main/packages/share_plus/share_plus'),
    _LicenseItem('receive_sharing_intent', 'MIT', 'https://github.com/KasemJaffer/receive_sharing_intent'),
    _LicenseItem('google_fonts', 'Apache-2.0', 'https://github.com/material-foundation/flutter-packages/tree/main/packages/google_fonts/google_fonts'),
    _LicenseItem('archive', 'BSD-3-Clause', 'https://github.com/brendan-duncan/archive'),
    _LicenseItem('pdf', 'Apache-2.0', 'https://github.com/DavBfr/dart_pdf'),
    _LicenseItem('printing', 'Apache-2.0', 'https://github.com/DavBfr/dart_pdf/tree/master/printing'),
    _LicenseItem('screenshot', 'MIT', 'https://github.com/SachinGanesh/screenshot'),
    _LicenseItem('package_info_plus', 'BSD-3-Clause', 'https://github.com/fluttercommunity/plus_plugins/tree/main/packages/package_info_plus/package_info_plus'),
    _LicenseItem('mime', 'BSD-3-Clause', 'https://github.com/dart-lang/tools/tree/main/pkgs/mime'),
  ];

  static const List<_LicenseItem> _webDependencies = [
    _LicenseItem('@milkdown/core', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/crepe', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-automd', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-clipboard', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-cursor', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-emoji', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-highlight', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-history', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-indent', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-listener', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-math', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-trailing', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/plugin-upload', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/preset-commonmark', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/preset-gfm', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/theme-nord', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('@milkdown/utils', 'MIT', 'https://github.com/Milkdown/milkdown'),
    _LicenseItem('katex', 'MIT', 'https://github.com/KaTeX/KaTeX'),
    _LicenseItem('prismjs', 'MIT', 'https://github.com/PrismJS/prism'),
    _LicenseItem('refractor', 'MIT', 'https://github.com/wooorm/refractor'),
    _LicenseItem('vite', 'MIT', 'https://github.com/vitejs/vite'),
    _LicenseItem('vite-plugin-singlefile', 'MIT', 'https://github.com/richardtallent/vite-plugin-singlefile'),
  ];

  static const List<_LicenseItem> _fontAssets = [
    _LicenseItem('Noto Sans SC', 'SIL Open Font License 1.1', 'https://fonts.google.com/noto/specimen/Noto+Sans+SC'),
    _LicenseItem('JetBrains Mono', 'SIL Open Font License 1.1', 'https://www.jetbrains.com/lp/mono/'),
  ];

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('开放源代码许可'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '本应用使用了多个开源项目。以下列表根据仓库依赖配置整理（pubspec.yaml、web/milkdown/package.json）。详细条款请以各项目仓库内 LICENSE 文件为准。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildSection(context, appStyle, 'Flutter / Dart 依赖', _flutterDependencies),
            const SizedBox(height: 16),
            _buildSection(context, appStyle, 'Web 编辑器依赖（Milkdown）', _webDependencies),
            const SizedBox(height: 16),
            _buildSection(context, appStyle, '字体资源', _fontAssets),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    AppStyleTheme appStyle,
    String title,
    List<_LicenseItem> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.scaledSurfaceColor(Theme.of(context).colorScheme, alpha: 0.7),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableText('${item.name} · ${item.license}\n${item.url}'),
            ),
        ],
      ),
    );
  }
}

class _LicenseItem {
  final String name;
  final String license;
  final String url;

  const _LicenseItem(this.name, this.license, this.url);
}
