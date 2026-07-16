import 'package:flutter/material.dart';

class ThirdPartyNoticesPage extends StatelessWidget {
  const ThirdPartyNoticesPage({super.key});

  bool _english(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  @override
  Widget build(BuildContext context) {
    final english = _english(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(english ? 'Open-source licenses' : '开源许可')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    english ? 'Third-party software' : '第三方软件说明',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    english
                        ? 'AI Question Bank is built with Flutter and open-source packages. Full notices are included in THIRD_PARTY_NOTICES.md in the source repository.'
                        : 'AI题库基于 Flutter 与多个第三方软件包构建。完整清单与用途说明见源码仓库中的 THIRD_PARTY_NOTICES.md。',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _NoticeTile(
            title: 'OCR / Image',
            packages:
                'image_picker · image_cropper · google_mlkit_text_recognition',
            license: 'BSD-3-Clause / MIT',
          ),
          const _NoticeTile(
            title: 'Charts / Rich content',
            packages: 'fl_chart · flutter_svg · smart_content_viewer',
            license: 'MIT',
          ),
          const _NoticeTile(
            title: 'Audio',
            packages: 'flutter_tts · audioplayers · flutter_edge_tts (legacy)',
            license: 'MIT',
          ),
          const _NoticeTile(
            title: 'PDF',
            packages: 'syncfusion_flutter_pdf',
            license: 'Syncfusion Community or Commercial License',
            warning: true,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: english ? 'AI Question Bank' : 'AI题库',
              applicationVersion: '3.0.0 Phase 2 Test001',
            ),
            icon: const Icon(Icons.description_outlined),
            label: Text(
              english ? 'View bundled license texts' : '查看随应用打包的许可证原文',
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.title,
    required this.packages,
    required this.license,
    this.warning = false,
  });

  final String title;
  final String packages;
  final String license;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          warning ? Icons.verified_user_outlined : Icons.code_rounded,
          color: warning ? colors.tertiary : colors.primary,
        ),
        title: Text(title),
        subtitle: Text('$packages\n$license'),
        isThreeLine: true,
      ),
    );
  }
}
