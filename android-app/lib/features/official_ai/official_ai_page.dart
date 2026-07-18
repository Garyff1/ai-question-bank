import 'dart:async';

import 'package:flutter/material.dart';

import 'legal_draft_page.dart';
import 'official_ai_client.dart';
import 'official_ai_models.dart';

class OfficialAiPage extends StatefulWidget {
  const OfficialAiPage({super.key});

  @override
  State<OfficialAiPage> createState() => _OfficialAiPageState();
}

class _OfficialAiPageState extends State<OfficialAiPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _server = TextEditingController();
  OfficialAiClient? _client;
  OfficialFeatureFlags? _features;
  List<OfficialOrder> _orders = const [];
  List<OfficialUsage> _usage = const [];
  int _questionCount = 5;
  bool _loading = true;
  bool _working = false;
  String? _error;

  bool get _english => Localizations.localeOf(context).languageCode == 'en';
  String t(String zh, String en) => _english ? en : zh;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = await OfficialAiClient.create();
      _server.text = client.baseUrl;
      final features = await client.features();
      if (!mounted) return;
      setState(() {
        _client = client;
        _features = features;
        _loading = false;
        _error = null;
      });
      if (client.signedIn) await _refreshAccountData();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _updateServer() async {
    final client = _client ?? await OfficialAiClient.create();
    await client.updateBaseUrl(_server.text);
    if (!mounted) return;
    setState(() {
      _client = client;
      _loading = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _authenticate({required bool register}) async {
    final client = _client;
    if (client == null ||
        _email.text.trim().isEmpty ||
        _password.text.length < 6) {
      _snack(
        t(
          '请填写邮箱和至少 6 位密码',
          'Enter an email and a password of at least 6 characters',
        ),
      );
      return;
    }
    setState(() => _working = true);
    try {
      await client.login(_email.text, _password.text, register: register);
      await _refreshAccountData();
      _snack(
        t(
          register ? '测试账号已创建' : '登录成功',
          register ? 'Test account created' : 'Signed in',
        ),
      );
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _refreshAccountData() async {
    final client = _client;
    if (client == null || !client.signedIn) return;
    try {
      final results = await Future.wait([client.orders(), client.usage()]);
      if (!mounted) return;
      setState(() {
        _orders = results[0] as List<OfficialOrder>;
        _usage = results[1] as List<OfficialUsage>;
      });
    } catch (error) {
      if (mounted) _snack(error.toString());
    }
  }

  Future<void> _requestQuote() async {
    final client = _client;
    if (client == null || !client.signedIn) return;
    if (_features?.officialAiEnabled != true) {
      _snack(
        t(
          '官方 AI 测试服务尚未由服务器开启',
          'Official AI test service is not enabled by the server',
        ),
      );
      return;
    }
    setState(() => _working = true);
    try {
      final quote = await client.quote(_questionCount);
      if (!mounted) return;
      await _showQuote(quote);
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showQuote(OfficialQuote quote) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('本次生成', 'This generation'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  '报价由服务器计算，创建订单时会再次校验。',
                  'The server calculates and revalidates this quote when creating the order.',
                ),
              ),
              const SizedBox(height: 18),
              ...quote.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_english ? item.labelEn : item.labelZh),
                      ),
                      Text(
                        item.free ? t('免费', 'Free') : formatFen(item.amountFen),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('应付金额', 'Amount due'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    formatFen(quote.amountFen),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  t(
                    '测试环境 · 模拟支付不会真实扣款',
                    'Test environment · Mock payment never creates a real charge',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _features?.paymentMockEnabled == true
                      ? () {
                          Navigator.pop(sheetContext);
                          _startMockOrder(quote);
                        }
                      : null,
                  icon: const Icon(Icons.science_outlined),
                  label: Text(t('使用模拟支付', 'Use mock payment')),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      child: Text(t('微信支付 · 尚未配置', 'WeChat Pay · unavailable')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      child: Text(t('支付宝 · 尚未配置', 'Alipay · unavailable')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startMockOrder(OfficialQuote quote) async {
    final client = _client!;
    setState(() => _working = true);
    try {
      final order = await client.createMockOrder(quote);
      await client.mockPay(order.id);
      _snack(
        t('模拟支付已确认，正在生成题目', 'Mock payment confirmed. Generating questions…'),
      );
      var latest = order;
      for (var i = 0; i < 24; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        latest = await client.order(order.id);
        if (latest.terminal || latest.status == 'refunding') break;
      }
      await _refreshAccountData();
      if (!mounted) return;
      _snack(_statusLabel(latest.status));
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _logout() async {
    await _client?.logout();
    if (!mounted) return;
    setState(() {
      _orders = const [];
      _usage = const [];
    });
  }

  Future<void> _deleteCloudData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('删除官方服务数据？', 'Delete official-service data?')),
        content: Text(
          t(
            '将删除测试订单、生成任务和影子计费记录，不影响手机内资料及自带 API Key。',
            'This removes test orders, tasks and shadow-billing records. Local materials and your own API Key are not affected.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t('确认删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client?.deleteCloudData();
      await _refreshAccountData();
      _snack(t('官方服务数据已删除', 'Official-service data deleted'));
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _deleteAccount() async {
    final password = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('注销官方服务账户？', 'Delete official-service account?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(
                '需要重新输入密码。手机内资料和自带 API Key 不会被删除。',
                'Re-enter your password. Local materials and your own API Key are preserved.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: t('密码', 'Password')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, password.text),
            child: Text(t('确认注销', 'Delete account')),
          ),
        ],
      ),
    );
    password.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await _client?.deleteAccount(value);
      if (!mounted) return;
      setState(() {
        _orders = const [];
        _usage = const [];
      });
      _snack(t('官方服务账户已注销', 'Official-service account deleted'));
    } catch (error) {
      _snack(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('官方 AI 服务', 'Official AI service')),
        actions: [
          if (_client?.signedIn == true)
            IconButton(
              onPressed: _logout,
              tooltip: t('退出官方账号', 'Sign out'),
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  _environmentBanner(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorCard(),
                  ],
                  const SizedBox(height: 12),
                  _serverCard(),
                  const SizedBox(height: 12),
                  _featureCard(),
                  const SizedBox(height: 12),
                  if (_client?.signedIn != true)
                    _loginCard()
                  else ...[
                    _generationCard(),
                    const SizedBox(height: 12),
                    _ordersCard(),
                    const SizedBox(height: 12),
                    _usageCard(),
                    const SizedBox(height: 12),
                    _dataCard(),
                  ],
                  const SizedBox(height: 12),
                  _legalCard(),
                ],
              ),
            ),
    );
  }

  Widget _environmentBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_rounded, color: Colors.white, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('第三阶段测试环境', 'Phase 3 test environment'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                t(
                  '模拟订单不会真实扣款，正式支付保持关闭',
                  'Mock orders never charge money; real payments remain disabled',
                ),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _errorCard() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.cloud_off_rounded),
      title: Text(_error!),
      subtitle: Text(
        t('可修改下方测试服务器地址后重试', 'Update the test server address below and retry'),
      ),
      trailing: IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
  );

  Widget _serverCard() => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.dns_outlined),
      title: Text(t('开发服务器', 'Development server')),
      subtitle: Text(_client?.baseUrl ?? OfficialAiClient.defaultBaseUrl),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        TextField(
          controller: _server,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: t('官方服务 Base URL', 'Official service Base URL'),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _updateServer,
            child: Text(t('保存并重连', 'Save and reconnect')),
          ),
        ),
      ],
    ),
  );

  Widget _featureCard() {
    final flags = _features;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('服务器能力', 'Server capabilities'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _flag(t('官方 AI', 'Official AI'), flags?.officialAiEnabled == true),
            _flag(
              t('影子计费', 'Shadow billing'),
              flags?.shadowBillingEnabled == true,
            ),
            _flag(t('模拟支付', 'Mock payment'), flags?.paymentMockEnabled == true),
            _flag(t('微信支付', 'WeChat Pay'), flags?.wechatPayEnabled == true),
            _flag(t('支付宝', 'Alipay'), flags?.alipayPayEnabled == true),
            _flag(t('真实扣款', 'Real charge'), flags?.realChargeEnabled == true),
          ],
        ),
      ),
    );
  }

  Widget _flag(String label, bool active) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.block_rounded,
          size: 18,
          color: active ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(active ? t('已开启', 'On') : t('未开放', 'Off')),
      ],
    ),
  );

  Widget _loginCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('测试账号', 'Test account'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            t(
              '仅官方 AI 服务需要登录；自带 API Key 模式仍可无账号使用。',
              'Only official AI requires an account. Bring-your-own-key mode remains account-free.',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: t('邮箱', 'Email')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: t('密码', 'Password')),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _working
                      ? null
                      : () => _authenticate(register: true),
                  child: Text(t('创建测试账号', 'Create test account')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _working
                      ? null
                      : () => _authenticate(register: false),
                  child: Text(t('登录', 'Sign in')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _generationCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('官方 AI 模拟生成', 'Official AI mock generation'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            t(
              '先获取服务端报价，再创建测试订单。当前使用 FakeAIProvider，不消耗真实模型额度。',
              'Get a server quote before creating a test order. FakeAIProvider uses no real model quota.',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _questionCount > 1
                    ? () => setState(() => _questionCount--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  t('$_questionCount 道题', '$_questionCount questions'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.filledTonal(
                onPressed: _questionCount < 20
                    ? () => setState(() => _questionCount++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working ? null : _requestQuote,
              icon: _working
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.receipt_long_rounded),
              label: Text(t('获取透明报价', 'Get transparent quote')),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _ordersCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('测试订单', 'Test orders'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _refreshAccountData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text(t('暂无测试订单', 'No test orders'))),
            )
          else
            ..._orders
                .take(8)
                .map(
                  (order) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(_statusIcon(order.status), size: 20),
                    ),
                    title: Text(
                      '${order.questionCount} ${t('题', 'questions')} · ${formatFen(order.amountFen)}',
                    ),
                    subtitle: Text(
                      '${_statusLabel(order.status)} · ${order.id.substring(0, order.id.length.clamp(0, 8))}',
                    ),
                    trailing: order.isTest
                        ? Chip(label: Text(t('测试', 'Test')))
                        : null,
                  ),
                ),
        ],
      ),
    ),
  );

  Widget _usageCard() => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.query_stats_rounded),
      title: Text(t('影子计费记录', 'Shadow billing records')),
      subtitle: Text(
        t(
          '${_usage.length} 条 · 不产生真实扣款',
          '${_usage.length} records · no real charge',
        ),
      ),
      children: _usage.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(t('暂无用量记录', 'No usage records')),
              ),
            ]
          : _usage
                .take(10)
                .map(
                  (item) => ListTile(
                    title: Text(
                      '${item.model} · ${item.inputTokens + item.outputTokens} tokens',
                    ),
                    subtitle: Text(
                      '${t('估算成本', 'Estimated cost')} ${formatFen(item.estimatedCostFen)} · ${t('影子报价', 'Shadow quote')} ${formatFen(item.quotedAmountFen)}',
                    ),
                    trailing: Icon(
                      item.success ? Icons.check_circle : Icons.error_outline,
                      color: item.success ? Colors.green : Colors.orange,
                    ),
                  ),
                )
                .toList(),
    ),
  );

  Widget _dataCard() => Card(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: Text(t('删除官方服务测试数据', 'Delete official-service test data')),
          subtitle: Text(
            t(
              '不影响手机资料和自带 API Key',
              'Local materials and personal API Key are preserved',
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _deleteCloudData,
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
            Icons.person_remove_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(t('注销官方服务账户', 'Delete official-service account')),
          subtitle: Text(t('需要重新验证密码', 'Password confirmation required')),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _deleteAccount,
        ),
      ],
    ),
  );

  Widget _legalCard() => Card(
    child: Column(
      children: [
        _legalTile(
          'service',
          t('官方 AI 与付费服务说明', 'Official AI and paid service'),
        ),
        _legalTile('privacy', t('隐私政策', 'Privacy policy')),
        _legalTile('refund', t('退款说明', 'Refund rules')),
        _legalTile('data', t('数据删除说明', 'Data deletion')),
      ],
    ),
  );

  Widget _legalTile(String kind, String title) => ListTile(
    leading: const Icon(Icons.description_outlined),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => LegalDraftPage(kind: kind))),
  );

  IconData _statusIcon(String status) => switch (status) {
    'success' => Icons.check_circle_rounded,
    'refunded' => Icons.currency_exchange_rounded,
    'refunding' => Icons.hourglass_top_rounded,
    'failed' => Icons.error_rounded,
    'generating' => Icons.auto_awesome_rounded,
    'paid' => Icons.paid_rounded,
    _ => Icons.receipt_long_rounded,
  };

  String _statusLabel(String status) {
    final zh = {
      'pending': '待确认',
      'awaiting_payment': '待支付',
      'paid': '已支付，等待生成',
      'generating': '生成中',
      'success': '生成成功',
      'failed': '生成失败',
      'refunding': '退款处理中',
      'refunded': '已模拟退款',
      'closed': '已关闭',
    };
    final en = {
      'pending': 'Pending',
      'awaiting_payment': 'Awaiting payment',
      'paid': 'Paid, awaiting generation',
      'generating': 'Generating',
      'success': 'Generation complete',
      'failed': 'Generation failed',
      'refunding': 'Refund processing',
      'refunded': 'Mock refund complete',
      'closed': 'Closed',
    };
    return (_english ? en : zh)[status] ?? status;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
