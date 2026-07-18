import 'package:flutter/material.dart';

class LegalDraftPage extends StatelessWidget {
  const LegalDraftPage({super.key, required this.kind});

  final String kind;

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  @override
  Widget build(BuildContext context) {
    final english = _isEnglish(context);
    final data = _content(kind, english);
    return Scaffold(
      appBar: AppBar(title: Text(data.$1)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              english
                  ? 'Development draft only. It has not completed legal review and cannot be treated as a final commercial agreement.'
                  : '当前仅为开发草案，尚未经过正式法律审核，不可视为最终商业协议。',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 20),
          ...data.$2.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.$2,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, List<(String, String)>) _content(String kind, bool en) {
    if (kind == 'privacy') {
      return en
          ? (
              'Privacy Policy (Draft)',
              [
                (
                  'Two service modes',
                  'Your own API Key stays in Android Keystore and is not synced to the official server. Official AI may send confirmed material to the official backend and a configured third-party model provider.',
                ),
                (
                  'Data minimization',
                  'Billing logs store token counts, hashes and anonymous statistics by default, not full materials or full prompts.',
                ),
                (
                  'Your controls',
                  'You can remove official-service tasks and request account deletion. Local study data remains separate from official-service cloud data.',
                ),
                (
                  'Minors',
                  'Minors should use the service with guardian guidance and should not upload sensitive personal information.',
                ),
              ],
            )
          : (
              '隐私政策（草案）',
              [
                (
                  '两种服务模式',
                  '自带 API Key 保存在 Android Keystore，不同步到官方服务器。官方 AI 模式会在用户确认后，将必要资料发送到官方后端及配置的第三方模型服务商。',
                ),
                ('数据最小化', '计费日志默认只保存 Token 数、内容哈希和匿名统计，不保存完整资料或完整 Prompt。'),
                ('用户控制', '用户可以删除官方服务任务并申请注销账户。本地学习数据与官方服务云端数据相互独立。'),
                ('未成年人', '未成年人应在监护人指导下使用，请勿上传敏感个人信息。'),
              ],
            );
    }
    if (kind == 'refund') {
      return en
          ? (
              'Refund Rules (Draft)',
              [
                (
                  'Generation failure',
                  'A paid official-service task retries once. If it still fails, the order enters refunding and is returned through the original payment channel after server confirmation.',
                ),
                (
                  'No local promises',
                  'Client messages do not replace the server refund status. Duplicate callbacks and refunds are handled idempotently.',
                ),
              ],
            )
          : (
              '退款说明（草案）',
              [
                ('生成失败', '官方服务订单支付后生成失败会自动重试一次；仍失败则进入退款流程，经服务器确认后原路退回。'),
                ('以服务端状态为准', '客户端提示不能代替服务端退款状态；重复回调和重复退款会通过幂等机制拦截。'),
              ],
            );
    }
    if (kind == 'data') {
      return en
          ? (
              'Data Deletion (Draft)',
              [
                (
                  'Local data',
                  'Materials, exercises and your own API configuration are stored on this device and can be deleted from the relevant pages.',
                ),
                (
                  'Cloud data',
                  'Official-service orders, usage records and tasks can be deleted after sign-in. Account deletion requires a second confirmation.',
                ),
              ],
            )
          : (
              '数据删除说明（草案）',
              [
                ('本地数据', '资料、练习和自带 API 配置保存在当前设备，可在对应页面删除。'),
                ('云端数据', '登录后可删除官方服务订单、用量记录和任务；注销账户需要二次确认。'),
              ],
            );
    }
    return en
        ? (
            'Official AI Paid Service (Draft)',
            [
              (
                'Test phase',
                'Mock payment is clearly marked and never creates a real charge. WeChat Pay and Alipay remain disabled until merchant configuration and formal verification are complete.',
              ),
              (
                'Pricing',
                'The server calculates integer-fen prices and validates each quote again when creating an order.',
              ),
              (
                'Third parties',
                'Official AI may rely on configured model providers. Provider availability and final commercial pricing are not guaranteed in this development build.',
              ),
            ],
          )
        : (
            '官方 AI 与付费服务说明（草案）',
            [
              ('测试阶段', '模拟支付会明显标注且不会真实扣款。微信支付和支付宝在商户配置及正式验收完成前保持关闭。'),
              ('价格', '金额由服务端按整数“分”计算，并在创建订单时重新校验报价。'),
              ('第三方服务', '官方 AI 可能调用配置的模型服务商；当前开发版不承诺服务商持续可用或最终商业价格。'),
            ],
          );
  }
}
