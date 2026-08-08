import 'package:flutter/material.dart';

class ByokDataFlowPage extends StatelessWidget {
  const ByokDataFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final items = english ? _englishItems : _chineseItems;
    return Scaffold(
      appBar: AppBar(title: Text(english ? 'BYOK & data flow' : 'BYOK 与数据流说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.key_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      english
                          ? 'AI Question Bank does not host your API key or sell model credits. Your key is stored on this device and requests go directly to the provider you choose.'
                          : 'AI题库不托管你的 API Key，也不出售模型额度。Key 保存在本机，请求直接发送给你选择的模型服务商。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Card(
              child: ExpansionTile(
                leading: Icon(item.icon),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(item.body)],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            english
                ? 'These texts are product drafts, not legal advice. Review provider terms and applicable requirements before public distribution.'
                : '以上为产品说明草案，不构成法律意见。正式公开分发前仍需核验服务商条款与适用的合规要求。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const _chineseItems = <_InfoItem>[
  _InfoItem(
    Icons.route_outlined,
    '数据如何流动',
    '资料、Prompt 和本次生成设置会直接发送给你选择的第三方模型服务商。AI题库默认不把资料、试卷、错题或本机调用记录上传到作者服务器。',
  ),
  _InfoItem(
    Icons.savings_outlined,
    '额度与费用',
    '模型 API 的价格、额度和最终账单由服务商确定。生成、重新生成、AI优化等操作可能产生新的调用；请以服务商控制台为准。',
  ),
  _InfoItem(
    Icons.shield_outlined,
    '异常调用保护',
    '应用会拦截快速重复点击、限制自动重试和单任务请求链，并在异常高频时暂停新任务。设置中的 API 使用记录只保存脱敏任务凭证。',
  ),
  _InfoItem(
    Icons.auto_fix_high_outlined,
    'AI 生成内容',
    '生成内容具有随机性，可能存在事实、答案或表达错误。正式教学、考试和重要用途前，请人工检查题目、答案、解析与图表。',
  ),
  _InfoItem(
    Icons.report_outlined,
    '问题与争议处理',
    '若疑似由应用缺陷造成异常重复调用，可提交脱敏 Task 记录进行技术核查。第三方服务商自身的价格或计费争议，应向服务商申诉，AI题库可提供本机调用证据。',
  ),
];

const _englishItems = <_InfoItem>[
  _InfoItem(
    Icons.route_outlined,
    'Data flow',
    'Materials, prompts and generation settings are sent directly to the third-party model provider you select. By default, the app does not upload materials, papers, mistakes or local usage records to the developer.',
  ),
  _InfoItem(
    Icons.savings_outlined,
    'Quota and cost',
    'API prices, quota and the final bill are determined by your provider. Generate, regenerate and AI-enhance actions can create new calls; use the provider console as the final record.',
  ),
  _InfoItem(
    Icons.shield_outlined,
    'Abnormal-call protection',
    'The app blocks rapid duplicate actions, limits automatic retries and request chains, and pauses new tasks after abnormal bursts. Local usage records contain redacted task receipts only.',
  ),
  _InfoItem(
    Icons.auto_fix_high_outlined,
    'AI-generated content',
    'Generated content is probabilistic and can contain factual, answer or wording errors. Review questions, answers, explanations and charts before formal teaching or assessment.',
  ),
  _InfoItem(
    Icons.report_outlined,
    'Incidents and disputes',
    'If an app defect may have caused repeated calls, submit a redacted task record for technical review. Provider pricing or billing disputes must be handled by the provider; the app can supply local call evidence.',
  ),
];
