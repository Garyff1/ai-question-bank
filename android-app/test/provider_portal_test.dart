import 'package:ai_question_bank_android/core/ai/provider_catalog.dart';
import 'package:ai_question_bank_android/features/provider_portal/provider_portal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider catalog contains BYOK providers and no official service', () {
    final ids = AiProviderCatalog.presets.map((item) => item.id).toSet();
    expect(
      ids,
      containsAll([
        'deepseek',
        'qwen',
        'zhipu',
        'siliconflow',
        'mimo',
        'kimi',
        'custom',
      ]),
    );
    expect(ids, isNot(contains('official')));
    expect(AiProviderCatalog.byId('deepseek').model, 'deepseek-v4-flash');
    expect(AiProviderCatalog.byId('qwen').model, 'qwen-plus');
    expect(AiProviderCatalog.byId('zhipu').model, 'glm-5.2');
    expect(AiProviderCatalog.byId('mimo').model, 'mimo-v2.5-pro');
    expect(AiProviderCatalog.byId('kimi').model, 'kimi-k3');
  });

  testWidgets('current provider card shows provider and local key status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CurrentProviderCard(
            providerId: 'deepseek',
            model: 'deepseek-v4-flash',
            keyConfigured: true,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('DeepSeek'), findsOneWidget);
    expect(
      find.textContaining('stored securely on this device'),
      findsOneWidget,
    );
    expect(find.textContaining('官方 AI'), findsNothing);
  });
}
